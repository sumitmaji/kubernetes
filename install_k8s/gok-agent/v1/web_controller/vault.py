import os
import hvac

def get_vault_secrets():
    vault_addr = os.environ.get("VAULT_ADDR")
    role = os.environ.get("VAULT_ROLE")
    kubernetes_token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"

    with open(kubernetes_token_path, 'r') as f:
        jwt = f.read()

    client = hvac.Client(url=vault_addr)
    # Authenticate with Kubernetes Auth
    client.auth_kubernetes(role=role, jwt=jwt)
    # Read secrets from the desired path
    secret_path = os.environ.get("VAULT_SECRET_PATH", "secret/data/web-controller")
    secret = client.secrets.kv.v2.read_secret_version(path=secret_path.replace("secret/data/", ""))
    data = secret["data"]["data"]
    return data