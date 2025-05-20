import os
from jose import jwt
import requests

OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER", "https://accounts.google.com")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID")
REQUIRED_ROLE = os.environ.get("REQUIRED_ROLE", "user")

def get_jwks():
    jwks_uri = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration").json()["jwks_uri"]
    return requests.get(jwks_uri).json()

JWKS = get_jwks()

def verify_id_token(token):
    try:
        unverified_header = jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=OAUTH_CLIENT_ID,
            issuer=OAUTH_ISSUER,
        )
        return payload
    except Exception as e:
        print("JWT verification failed:", e)
        return None

def process_command_batch(mq_message):
    id_token = mq_message.get("user_info", {}).get("id_token")
    payload = verify_id_token(id_token)
    if not payload:
        # reject unauthorized
        print("Unauthorized: invalid token")
        return
    roles = payload.get("roles", [])
    if isinstance(roles, str):
        roles = [roles]
    if REQUIRED_ROLE not in roles:
        print(f"Unauthorized: missing required role ({REQUIRED_ROLE})")
        return
    # Authorized: proceed to run commands
    # Access user info: payload["sub"], payload["name"], etc.
    print(f"Authorized user {payload['sub']} ({payload.get('name')}) running commands")
    # ...command execution logic...