import os
import json
import logging

logger = logging.getLogger(__name__)

def get_vault_secrets():
    """
    Legacy function to get vault secrets from agent injector files
    Maintained for backward compatibility
    """
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, "web-controller")
    
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
    
    Args:
        secret_name: Name of the secret file (config, rabbitmq, etc.)
    
    Returns:
        Dictionary containing secret data or None if failed
    """
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, secret_name)
    
    try:
        with open(secrets_file, "r") as f:
            data = json.load(f)
        logger.info(f"Successfully loaded {secret_name} secrets from Vault Agent Injector")
        return data
    except FileNotFoundError:
        logger.warning(f"Vault agent injector secret file not found: {secrets_file}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing Vault agent injector secret file {secret_name}: {e}")
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

def get_rabbitmq_secrets_from_files():
    """
    Get RabbitMQ credentials from Vault Agent Injector files
    
    Returns:
        Dictionary containing RabbitMQ credentials or None if failed
    """
    return get_vault_secrets_from_files("rabbitmq")