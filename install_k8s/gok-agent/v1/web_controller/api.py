import os
# ... other imports ...
from vault import get_vault_secrets

# On startup, fetch secrets once (or re-fetch/refresh as needed)
vault_secrets = get_vault_secrets()

app.config["JWT_SECRET_KEY"] = vault_secrets["jwt-secret"]
API_TOKEN = vault_secrets["api-token"]