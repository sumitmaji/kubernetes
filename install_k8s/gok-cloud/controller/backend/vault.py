import os
import json
import yaml
import logging
from typing import Dict, Optional, List
from pathlib import Path

logger = logging.getLogger(__name__)

def get_vault_secrets_csi(mount_path: str = "/mnt/secrets-store") -> Optional[Dict]:
    """
    Get secrets from Vault CSI Driver mount
    
    Args:
        mount_path: Path where CSI driver mounts secrets
        
    Returns:
        Dictionary containing all mounted secrets or None if failed
    """
    try:
        mount_dir = Path(mount_path)
        if not mount_dir.exists():
            logger.warning(f"CSI mount path does not exist: {mount_path}")
            return None
            
        secrets = {}
        for secret_file in mount_dir.iterdir():
            if secret_file.is_file() and not secret_file.name.startswith('.'):
                try:
                    content = secret_file.read_text().strip()
                    # Try to parse as JSON first, fallback to string
                    try:
                        secrets[secret_file.name] = json.loads(content)
                    except json.JSONDecodeError:
                        secrets[secret_file.name] = content
                    logger.debug(f"Loaded secret from CSI: {secret_file.name}")
                except Exception as e:
                    logger.error(f"Error reading CSI secret file {secret_file.name}: {e}")
                    
        if secrets:
            logger.info(f"Successfully loaded {len(secrets)} secrets from Vault CSI Driver")
            return secrets
        else:
            logger.warning("No secrets found in CSI mount")
            return None
            
    except Exception as e:
        logger.error(f"Error accessing CSI mount {mount_path}: {e}")
        return None

def get_vault_secrets():
    """
    Legacy function to get vault secrets from agent injector files
    Maintained for backward compatibility
    """
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, "gok-controller")
    
    try:
        with open(secrets_file, "r") as f:
            data = json.load(f)
        logger.info("Successfully loaded secrets from Vault Agent Injector")
        return data
    except FileNotFoundError:
        logger.warning(f"Vault agent injector secret file not found: {secrets_file}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing Vault agent injector secret file: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error reading Vault agent injector secrets: {e}")
        return None

def get_vault_secrets_from_files(secret_name="config"):
    """
    Get secrets from Vault Agent Injector files
    Supports both JSON and YAML formats with intelligent parsing
    
    Args:
        secret_name: Name of the secret file (config, rabbitmq, etc.)
    
    Returns:
        Dictionary containing secret data or None if failed
    """
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, secret_name)
    
    try:
        with open(secrets_file, "r") as f:
            content = f.read().strip()
            
        if not content:
            logger.warning(f"Empty secret file: {secrets_file}")
            return None
            
        # Try to determine format and parse accordingly
        data = None
        format_used = None
        
        # First, try JSON parsing
        try:
            data = json.loads(content)
            format_used = "JSON"
        except json.JSONDecodeError:
            # If JSON fails, try YAML parsing
            try:
                data = yaml.safe_load(content)
                format_used = "YAML"
            except yaml.YAMLError as yaml_err:
                # If both fail, try simple key=value parsing (for raw Vault output)
                try:
                    data = {}
                    for line in content.split('\n'):
                        line = line.strip()
                        if line and ':' in line:
                            key, value = line.split(':', 1)
                            data[key.strip()] = value.strip()
                    if data:
                        format_used = "Key-Value"
                    else:
                        raise ValueError("No valid key-value pairs found")
                except Exception as kv_err:
                    logger.error(f"Failed to parse {secret_name} as JSON, YAML, or key-value format")
                    logger.error(f"JSON error: {str(json.JSONDecodeError('Invalid JSON', content, 0))}")
                    logger.error(f"YAML error: {yaml_err}")
                    logger.error(f"Key-Value error: {kv_err}")
                    logger.error(f"Raw content preview: {content[:200]}...")
                    return None
        
        if data:
            logger.info(f"Successfully loaded {secret_name} secrets from Vault Agent Injector ({format_used} format)")
            logger.debug(f"Loaded keys: {list(data.keys()) if isinstance(data, dict) else 'Non-dict data'}")
            return data
        else:
            logger.warning(f"No data extracted from {secret_name}")
            return None
            
    except FileNotFoundError:
        logger.warning(f"Vault agent injector secret file not found: {secrets_file}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error reading Vault agent injector secrets {secret_name}: {e}")
        return None

def get_config_secrets():
    """
    Get application configuration secrets from Vault Agent Injector
    
    Returns:
        Dictionary containing config secrets or None if failed
    """
    return get_vault_secrets_from_files("config")

def get_vault_secrets_multi_method(secret_name: str = "config", 
                                   methods: List[str] = None) -> Optional[Dict]:
    """
    Get secrets using multiple Vault integration methods with fallback
    
    Args:
        secret_name: Name of the secret to retrieve
        methods: List of methods to try ['csi', 'agent', 'k8s-secret']
        
    Returns:
        Dictionary containing secret data from first successful method
    """
    if methods is None:
        methods = ['csi', 'agent', 'k8s-secret']
        
    logger.info(f"Attempting to load {secret_name} using methods: {methods}")
    
    for method in methods:
        try:
            if method == 'csi':
                # Try CSI Driver mount
                csi_secrets = get_vault_secrets_csi()
                if csi_secrets and secret_name in csi_secrets:
                    logger.info(f"Successfully loaded {secret_name} from CSI Driver")
                    return {secret_name: csi_secrets[secret_name]}
                    
            elif method == 'agent':
                # Try Agent Injector files
                agent_secrets = get_vault_secrets_from_files(secret_name)
                if agent_secrets:
                    logger.info(f"Successfully loaded {secret_name} from Agent Injector")
                    return agent_secrets
                    
            elif method == 'k8s-secret':
                # Try Kubernetes secret (from CSI sync)
                k8s_secrets = get_kubernetes_secret(secret_name)
                if k8s_secrets:
                    logger.info(f"Successfully loaded {secret_name} from Kubernetes Secret")
                    return k8s_secrets
                    
        except Exception as e:
            logger.warning(f"Method {method} failed for {secret_name}: {e}")
            continue
            
    logger.error(f"All methods failed to load {secret_name}")
    return None

def get_kubernetes_secret(secret_name: str, namespace: str = None) -> Optional[Dict]:
    """
    Get secrets from Kubernetes Secret (typically synced by CSI Driver)
    
    Args:
        secret_name: Name of the Kubernetes secret
        namespace: Kubernetes namespace (defaults to current pod namespace)
        
    Returns:
        Dictionary containing secret data or None if failed
    """
    try:
        # Get current namespace if not provided
        if namespace is None:
            namespace_file = '/var/run/secrets/kubernetes.io/serviceaccount/namespace'
            if os.path.exists(namespace_file):
                with open(namespace_file, 'r') as f:
                    namespace = f.read().strip()
            else:
                namespace = 'default'
                
        # Check if secret is mounted as volume
        secret_path = f"/var/run/secrets/kubernetes.io/secret/{secret_name}"
        if os.path.exists(secret_path):
            secrets = {}
            for file_path in os.listdir(secret_path):
                full_path = os.path.join(secret_path, file_path)
                if os.path.isfile(full_path):
                    with open(full_path, 'r') as f:
                        content = f.read().strip()
                        try:
                            secrets[file_path] = json.loads(content)
                        except json.JSONDecodeError:
                            secrets[file_path] = content
            return secrets if secrets else None
            
    except Exception as e:
        logger.error(f"Error reading Kubernetes secret {secret_name}: {e}")
        
    return None

def get_rabbitmq_secrets_from_files():
    """
    Get RabbitMQ credentials from Vault using multi-method approach
    
    Returns:
        Dictionary containing RabbitMQ credentials or None if failed
    """
    return get_vault_secrets_multi_method("rabbitmq", methods=['csi', 'agent', 'k8s-secret'])