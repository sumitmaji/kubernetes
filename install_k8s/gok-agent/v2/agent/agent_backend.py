import os
import json
import pika
import requests
from jose import jwt

OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID")
REQUIRED_ROLE = os.environ.get("REQUIRED_ROLE", "user")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "mq")

def get_jwks():
    jwks_uri = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration").json()["jwks_uri"]
    return requests.get(jwks_uri).json()
JWKS = get_jwks()
def verify_id_token(token):
    try:
        unverified_header = jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        payload = jwt.decode(
            token, key, algorithms=["RS256"], audience=OAUTH_CLIENT_ID, issuer=OAUTH_ISSUER,
        )
        return payload
    except Exception as e:
        print("Agent JWT verification failed:", e)
        return None

def process_command_batch(mq_message):
    id_token = mq_message.get("user_info", {}).get("id_token")
    payload = verify_id_token(id_token)
    if not payload:
        print("Unauthorized: invalid token")
        return
    roles = payload.get("roles", [])
    if isinstance(roles, str): roles = [roles]
    if REQUIRED_ROLE not in roles:
        print(f"Unauthorized: missing required role ({REQUIRED_ROLE})")
        return
    print(f"Authorized user {payload['sub']} running commands: {mq_message['commands']}")
    # Place your command execution logic here

def main():
    connection = pika.BlockingConnection(pika.ConnectionParameters(RABBITMQ_HOST))
    channel = connection.channel()
    channel.queue_declare(queue="commands")
    for method_frame, properties, body in channel.consume("commands", inactivity_timeout=1):
        if body:
            mq_message = json.loads(body)
            process_command_batch(mq_message)
            channel.basic_ack(method_frame.delivery_tag)

if __name__ == "__main__":
    main()