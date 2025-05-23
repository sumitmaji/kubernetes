import os
import json

def get_vault_secrets():
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, "web-controller")
    with open(secrets_file, "r") as f:
        data = json.load(f)
    return data