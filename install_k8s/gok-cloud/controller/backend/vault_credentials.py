"""
HashiCorp Vault integration for RabbitMQ credentials
This module provides functions to securely retrieve RabbitMQ credentials from Vault
"""

import os
import subprocess
import json
import logging
import requests
import time
from dataclasses import dataclass
from typing import Optional, Tuple, Dict

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class RabbitMQCredentials:
    """Data class for RabbitMQ credentials"""
    username: str
    password: str
    host: str = "rabbitmq.rabbitmq"
    port: int = 5672
    virtual_host: str = "/"
    
class VaultCredentialManager:
    """Manager class for Vault credential operations"""
    
    def __init__(self, 
                 vault_addr: str = None, 
                 vault_token: str = None,
                 vault_path: str = "secret/rabbitmq",
                 vault_role: str = None, 
                 k8s_auth_path: str = None, 
                 service_account_token_path: str = None):
        """
        Initialize Vault credential manager
        
        Args:
            vault_addr: Vault server address
            vault_token: Vault authentication token  
            vault_path: Path to RabbitMQ credentials in Vault
            vault_role: Vault role for K8s auth (default: from env VAULT_K8S_ROLE)
            k8s_auth_path: K8s auth path in Vault (default: from env VAULT_K8S_AUTH_PATH)
            service_account_token_path: Path to service account token (default: /var/run/secrets/kubernetes.io/serviceaccount/token)
        """
        self.vault_addr = vault_addr or os.getenv('VAULT_ADDR', 'http://localhost:8200')
        self.vault_token = vault_token or os.getenv('VAULT_TOKEN')
        self.vault_path = vault_path or os.getenv('VAULT_PATH', 'secret/rabbitmq')
        
        # Kubernetes Service Account authentication parameters
        self.vault_role = vault_role or os.getenv('VAULT_K8S_ROLE')
        self.k8s_auth_path = k8s_auth_path or os.getenv('VAULT_K8S_AUTH_PATH', 'kubernetes')
        self.service_account_token_path = service_account_token_path or '/var/run/secrets/kubernetes.io/serviceaccount/token'
        
        # Token management
        self.token_expire_time = None
        self.token_ttl = None
        
        # Try to authenticate using Kubernetes Service Account if no token provided but role is available
        if not self.vault_token and self.vault_role:
            logger.info("No VAULT_TOKEN provided, attempting Kubernetes Service Account authentication")
            if not self._authenticate_with_k8s_service_account():
                raise ValueError("Failed to authenticate with Kubernetes Service Account")
        elif not self.vault_token:
            logger.warning("VAULT_TOKEN not provided. Some operations may fail.")
    
    def _authenticate_with_k8s_service_account(self) -> bool:
        """
        Authenticate with Vault using Kubernetes Service Account token.
        
        Returns:
            bool: True if authentication successful, False otherwise
        """
        try:
            # Read the service account JWT token
            if not os.path.exists(self.service_account_token_path):
                logger.error(f"Service account token file not found: {self.service_account_token_path}")
                return False
            
            with open(self.service_account_token_path, 'r') as f:
                jwt_token = f.read().strip()
            
            if not jwt_token:
                logger.error("Service account token is empty")
                return False
            
            # Authenticate with Vault using the JWT token
            auth_url = f"{self.vault_addr}/v1/auth/{self.k8s_auth_path}/login"
            auth_payload = {
                "role": self.vault_role,
                "jwt": jwt_token
            }
            
            logger.info(f"Attempting Kubernetes authentication with Vault at {auth_url}")
            response = requests.post(auth_url, json=auth_payload, timeout=30)
            
            if response.status_code == 200:
                auth_data = response.json()
                client_token = auth_data.get('auth', {}).get('client_token')
                lease_duration = auth_data.get('auth', {}).get('lease_duration', 3600)
                
                if client_token:
                    self.vault_token = client_token
                    self.token_ttl = lease_duration
                    self.token_expire_time = time.time() + lease_duration - 300  # Refresh 5 minutes before expiry
                    
                    logger.info(f"Successfully authenticated with Vault using Kubernetes Service Account (TTL: {lease_duration}s)")
                    return True
                else:
                    logger.error("No client token received from Vault authentication")
                    return False
            else:
                logger.error(f"Vault authentication failed: {response.status_code} - {response.text}")
                return False
                
        except FileNotFoundError:
            logger.error(f"Service account token file not found: {self.service_account_token_path}")
            return False
        except requests.exceptions.RequestException as e:
            logger.error(f"Network error during Vault authentication: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error during Vault authentication: {e}")
            return False

    def _refresh_token_if_needed(self) -> bool:
        """
        Check if token needs refresh and refresh it if necessary.
        
        Returns:
            bool: True if token is valid/refreshed, False if refresh failed
        """
        if not self.token_expire_time:
            # Token doesn't have expiration tracking, assume it's valid
            return True
        
        current_time = time.time()
        if current_time >= self.token_expire_time:
            logger.info("Vault token expired or expiring soon, refreshing...")
            return self._authenticate_with_k8s_service_account()
        
        return True

    def _run_vault_command(self, command: list) -> Tuple[bool, str]:
        """
        Execute vault CLI command
        
        Args:
            command: List of command arguments
            
        Returns:
            Tuple of (success, output)
        """
        try:
            # Set environment variables for vault command
            env = os.environ.copy()
            env['VAULT_ADDR'] = self.vault_addr
            if self.vault_token:
                env['VAULT_TOKEN'] = self.vault_token
            
            result = subprocess.run(
                ['vault'] + command,
                env=env,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                return True, result.stdout.strip()
            else:
                logger.error(f"Vault command failed: {result.stderr}")
                return False, result.stderr.strip()
                
        except subprocess.TimeoutExpired:
            logger.error("Vault command timed out")
            return False, "Command timeout"
        except Exception as e:
            logger.error(f"Error running vault command: {e}")
            return False, str(e)
    
    def check_vault_status(self) -> bool:
        """
        Check if Vault is accessible
        
        Returns:
            True if Vault is accessible, False otherwise
        """
        success, output = self._run_vault_command(['status'])
        if success or 'Sealed: false' in output:
            logger.info("Vault is accessible and unsealed")
            return True
        else:
            logger.error(f"Vault is not accessible: {output}")
            return False
    
    def get_rabbitmq_credentials(self) -> Optional[RabbitMQCredentials]:
        """
        Retrieve RabbitMQ credentials from Vault
        
        Returns:
            RabbitMQCredentials object or None if failed
        """
        # Refresh token if needed (for K8s Service Account authentication)
        if not self._refresh_token_if_needed():
            logger.error("Failed to refresh Vault token")
            return None
        
        if not self.vault_token:
            logger.error("Vault token not available")
            return None
        
        logger.info(f"Retrieving RabbitMQ credentials from Vault path: {self.vault_path}")
        
        try:
            # Use REST API to get credentials from Vault
            headers = {"X-Vault-Token": self.vault_token}
            url = f"{self.vault_addr}/v1/{self.vault_path}"
            
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                secret_data = response.json()
                data = secret_data.get('data', {}).get('data', {})
                
                username = data.get('username')
                password = data.get('password')
                
                if not username or not password:
                    logger.error("Username or password not found in Vault secret")
                    return None
                
                logger.info("Successfully retrieved RabbitMQ credentials from Vault")
                return RabbitMQCredentials(
                    username=username,
                    password=password,
                    host=os.getenv('RABBITMQ_HOST', 'rabbitmq.rabbitmq'),
                    port=int(os.getenv('RABBITMQ_PORT', '5672')),
                    virtual_host=os.getenv('RABBITMQ_VHOST', '/')
                )
            else:
                logger.error(f"Failed to retrieve credentials from Vault: {response.status_code} - {response.text}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Network error retrieving credentials: {e}")
            return None
        except Exception as e:
            logger.error(f"Error processing Vault credentials: {e}")
            return None
    
    def store_credentials(self, username: str, password: str, metadata: Dict = None) -> bool:
        """
        Store RabbitMQ credentials in Vault
        
        Args:
            username: RabbitMQ username
            password: RabbitMQ password
            metadata: Additional metadata to store
            
        Returns:
            True if successful, False otherwise
        """
        if not self.vault_token:
            logger.error("Vault token not available")
            return False
        
        # Prepare data to store
        data = {
            'username': username,
            'password': password,
        }
        
        if metadata:
            data.update(metadata)
        
        # Build vault command
        command = ['kv', 'put', self.vault_path]
        for key, value in data.items():
            command.extend([f'{key}={value}'])
        
        success, output = self._run_vault_command(command)
        
        if success:
            logger.info("Successfully stored RabbitMQ credentials in Vault")
            return True
        else:
            logger.error(f"Failed to store credentials: {output}")
            return False

# Fallback functions for backward compatibility
def get_rabbitmq_credentials_from_vault() -> Optional[RabbitMQCredentials]:
    """
    Fallback function to get RabbitMQ credentials from Vault
    Uses environment variables for configuration
    
    Returns:
        RabbitMQCredentials object or None if failed
    """
    manager = VaultCredentialManager()
    return manager.get_rabbitmq_credentials()

def get_rabbitmq_credentials_from_k8s() -> Optional[RabbitMQCredentials]:
    """
    Fallback function to get RabbitMQ credentials from Kubernetes secret
    
    Returns:
        RabbitMQCredentials object or None if failed
    """
    try:
        # Extract credentials using kubectl
        namespace = os.getenv('RABBITMQ_NAMESPACE', 'rabbitmq')
        secret_name = os.getenv('RABBITMQ_SECRET_NAME', 'rabbitmq-default-user')
        
        # Get username
        result = subprocess.run([
            'kubectl', 'get', 'secret', secret_name, 
            '-n', namespace, '-o', 'jsonpath={.data.username}'
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            logger.error("Failed to get username from Kubernetes secret")
            return None
        
        username = subprocess.run([
            'base64', '-d'
        ], input=result.stdout, capture_output=True, text=True).stdout.strip()
        
        # Get password
        result = subprocess.run([
            'kubectl', 'get', 'secret', secret_name,
            '-n', namespace, '-o', 'jsonpath={.data.password}'
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            logger.error("Failed to get password from Kubernetes secret")
            return None
        
        password = subprocess.run([
            'base64', '-d'
        ], input=result.stdout, capture_output=True, text=True).stdout.strip()
        
        if not username or not password:
            logger.error("Empty username or password from Kubernetes secret")
            return None
        
        logger.info("Successfully retrieved RabbitMQ credentials from Kubernetes")
        return RabbitMQCredentials(
            username=username,
            password=password,
            host=os.getenv('RABBITMQ_HOST', 'rabbitmq.rabbitmq'),
            port=int(os.getenv('RABBITMQ_PORT', '5672')),
            virtual_host=os.getenv('RABBITMQ_VHOST', '/')
        )
        
    except subprocess.TimeoutExpired:
        logger.error("Kubernetes credential retrieval timed out")
        return None
    except Exception as e:
        logger.error(f"Error retrieving credentials from Kubernetes: {e}")
        return None

def get_rabbitmq_credentials(prefer_vault: bool = True) -> Optional[RabbitMQCredentials]:
    """
    Get RabbitMQ credentials with fallback mechanism
    
    Args:
        prefer_vault: If True, try Vault first, then Kubernetes. If False, reverse order.
        
    Returns:
        RabbitMQCredentials object or None if both methods fail
    """
    if prefer_vault:
        # Try Vault first
        credentials = get_rabbitmq_credentials_from_vault()
        if credentials:
            return credentials
        
        logger.warning("Vault credential retrieval failed, trying Kubernetes fallback")
        return get_rabbitmq_credentials_from_k8s()
    else:
        # Try Kubernetes first
        credentials = get_rabbitmq_credentials_from_k8s()
        if credentials:
            return credentials
        
        logger.warning("Kubernetes credential retrieval failed, trying Vault fallback")
        return get_rabbitmq_credentials_from_vault()

# Example usage and testing functions
def test_vault_connectivity():
    """Test Vault connectivity and configuration"""
    manager = VaultCredentialManager()
    
    print("Testing Vault connectivity...")
    print(f"Vault Address: {manager.vault_addr}")
    print(f"Vault Path: {manager.vault_path}")
    print(f"Token Available: {'Yes' if manager.vault_token else 'No'}")
    
    if manager.check_vault_status():
        print("✓ Vault is accessible")
        return True
    else:
        print("✗ Vault is not accessible")
        return False

def test_credential_retrieval():
    """Test credential retrieval from both Vault and Kubernetes"""
    print("\n=== Testing Credential Retrieval ===")
    
    # Test Vault
    print("Testing Vault credential retrieval...")
    vault_creds = get_rabbitmq_credentials_from_vault()
    if vault_creds:
        print(f"✓ Vault: Username={vault_creds.username}, Host={vault_creds.host}")
    else:
        print("✗ Vault credential retrieval failed")
    
    # Test Kubernetes
    print("Testing Kubernetes credential retrieval...")
    k8s_creds = get_rabbitmq_credentials_from_k8s()
    if k8s_creds:
        print(f"✓ Kubernetes: Username={k8s_creds.username}, Host={k8s_creds.host}")
    else:
        print("✗ Kubernetes credential retrieval failed")
    
    # Test fallback mechanism
    print("Testing fallback mechanism...")
    fallback_creds = get_rabbitmq_credentials(prefer_vault=True)
    if fallback_creds:
        print(f"✓ Fallback: Username={fallback_creds.username}, Host={fallback_creds.host}")
    else:
        print("✗ Both credential sources failed")

if __name__ == "__main__":
    # Run tests when script is executed directly
    test_vault_connectivity()
    test_credential_retrieval()