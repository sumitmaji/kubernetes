"""
HashiCorp Vault integration for RabbitMQ credentials
This module provides functions to securely retrieve RabbitMQ credentials from Vault
"""

import os
import json
import subprocess
import logging
import requests
import time
from typing import Dict, Optional, Tuple
from dataclasses import dataclass

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
    """Manager class for Vault credential operations with Kubernetes Service Account support"""
    
    def __init__(self, 
                 vault_addr: str = None, 
                 vault_token: str = None,
                 vault_path: str = "secret/rabbitmq",
                 vault_role: str = None,
                 k8s_auth_path: str = "auth/kubernetes",
                 service_account_token_path: str = "/var/run/secrets/kubernetes.io/serviceaccount/token"):
        """
        Initialize Vault credential manager
        
        Args:
            vault_addr: Vault server address
            vault_token: Vault authentication token (optional if using K8s auth)
            vault_path: Path to RabbitMQ credentials in Vault
            vault_role: Kubernetes auth role for service account
            k8s_auth_path: Vault Kubernetes auth path
            service_account_token_path: Path to Kubernetes service account token
        """
        self.vault_addr = vault_addr or os.getenv('VAULT_ADDR', 'http://vault.vault:8200')
        self.vault_token = vault_token or os.getenv('VAULT_TOKEN')
        self.vault_path = vault_path or os.getenv('VAULT_PATH', 'secret/rabbitmq')
        self.vault_role = vault_role or os.getenv('VAULT_K8S_ROLE', 'gok-agent-role')
        self.k8s_auth_path = k8s_auth_path
        self.service_account_token_path = service_account_token_path
        
        # Token management
        self.token_expires = None
        self.token_renewable = False
        
        # Try to authenticate with Kubernetes service account if no token provided
        if not self.vault_token:
            logger.info("No VAULT_TOKEN provided, attempting Kubernetes service account authentication")
            self._authenticate_with_k8s_service_account()
        
        if not self.vault_token:
            logger.warning("No Vault token available. Some operations may fail.")
    
    def is_token_valid(self) -> bool:
        """
        Check if current token is still valid
        
        Returns:
            True if token is valid, False otherwise
        """
        if not self.vault_token or not self.token_expires:
            return False
        return time.time() < (self.token_expires - 60)  # 60 second buffer
    
    def test_token_info(self) -> Optional[Dict]:
        """
        Test token info endpoint to validate token
        
        Returns:
            Token info dict if successful, None otherwise
        """
        if not self.is_token_valid():
            logger.info("Token expired or invalid, re-authenticating...")
            if not self._authenticate_with_k8s_service_account():
                return None
        
        try:
            token_url = f"{self.vault_addr}/v1/auth/token/lookup-self"
            headers = {
                'X-Vault-Token': self.vault_token,
                'Content-Type': 'application/json'
            }
            
            response = requests.get(token_url, headers=headers, timeout=30)
            response.raise_for_status()
            
            token_info = response.json()
            logger.debug("Token info retrieved successfully")
            return token_info
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get token info: {e}")
            return None
    
    def _authenticate_with_k8s_service_account(self) -> bool:
        """
        Authenticate with Vault using Kubernetes service account token
        
        Returns:
            Vault token if successful, None otherwise
        """
        try:
            # Check if service account token exists
            if not os.path.exists(self.service_account_token_path):
                logger.warning(f"Service account token not found at {self.service_account_token_path}")
                return None
            
            # Read the service account token
            with open(self.service_account_token_path, 'r') as f:
                jwt_token = f.read().strip()
            
            if not jwt_token:
                logger.warning("Service account token is empty")
                return None
            
            logger.info(f"Authenticating with Vault using Kubernetes service account (role: {self.vault_role})")
            
            # Authenticate with Vault using the service account token
            auth_url = f"{self.vault_addr}/v1/{self.k8s_auth_path}/login"
            
            auth_data = {
                "role": self.vault_role,
                "jwt": jwt_token
            }
            
            headers = {
                "Content-Type": "application/json"
            }
            
            response = requests.post(auth_url, json=auth_data, headers=headers, timeout=30)
            response.raise_for_status()
            
            auth_response = response.json()
            self.vault_token = auth_response['auth']['client_token']
            
            # Calculate token expiration
            lease_duration = auth_response['auth'].get('lease_duration', 3600)
            self.token_expires = time.time() + lease_duration
            self.token_renewable = auth_response['auth'].get('renewable', False)
            
            logger.info(f"Authentication successful, token expires in {lease_duration} seconds")
            return True
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Network error during Vault authentication: {e}")
            return False
        except FileNotFoundError:
            logger.warning("Service account token file not found - not running in Kubernetes?")
            return False
        except Exception as e:
            logger.error(f"Unexpected error during Vault authentication: {e}")
            return False
    
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
    
    def _refresh_token_if_needed(self) -> bool:
        """
        Refresh Vault token if it's expired or about to expire
        
        Returns:
            True if token is valid or successfully refreshed, False otherwise
        """
        if not self.vault_token:
            # Try to get a new token using service account
            self.vault_token = self._authenticate_with_k8s_service_account()
            return self.vault_token is not None
        
        # Check if current token is valid
        try:
            headers = {"X-Vault-Token": self.vault_token}
            response = requests.get(f"{self.vault_addr}/v1/auth/token/lookup-self", 
                                  headers=headers, timeout=10)
            
            if response.status_code == 200:
                token_info = response.json()
                ttl = token_info.get('data', {}).get('ttl', 0)
                
                # If token expires in less than 5 minutes, refresh it
                if ttl < 300:
                    logger.info("Token expires soon, refreshing...")
                    new_token = self._authenticate_with_k8s_service_account()
                    if new_token:
                        self.vault_token = new_token
                        return True
                    else:
                        logger.warning("Failed to refresh token")
                        return False
                
                return True  # Token is still valid
            else:
                # Token is invalid, try to get a new one
                logger.warning("Current token is invalid, attempting to refresh")
                new_token = self._authenticate_with_k8s_service_account()
                if new_token:
                    self.vault_token = new_token
                    return True
                else:
                    return False
                    
        except requests.exceptions.RequestException as e:
            logger.error(f"Error checking token validity: {e}")
            # Try to refresh anyway
            new_token = self._authenticate_with_k8s_service_account()
            if new_token:
                self.vault_token = new_token
                return True
            return False
    
    def get_rabbitmq_credentials(self) -> Optional[RabbitMQCredentials]:
        """
        Retrieve RabbitMQ credentials from Vault
        
        Returns:
            RabbitMQCredentials object or None if failed
        """
        # Ensure we have a valid token
        if not self._refresh_token_if_needed():
            logger.error("Cannot obtain valid Vault token")
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