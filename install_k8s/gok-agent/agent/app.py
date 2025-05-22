import os
import pika
import subprocess
import logging
import json
from jose import jwt
import requests

# --- RBAC CONFIG ---
# Example RBAC config, replace with your actual config or import from a file
TOKEN_ROLE_MAP = {
    "supersecrettoken": "admin",
    "usertoken": "user"
}
ROLE_COMMANDS = {
    "admin": ["ls", "whoami", "uptime", "cat", "echo"],
    "user": ["ls", "whoami", "uptime"]
}

# --- OAUTH/JWT CONFIG ---
OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER", "https://accounts.google.com")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID", "your-client-id")
REQUIRED_ROLE = os.environ.get("REQUIRED_ROLE", "administrators")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "localhost")
RESULTS_QUEUE = 'results'

logging.basicConfig(filename='agent.log', level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def get_jwks():
    try:
        jwks_uri = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration").json()["jwks_uri"]
        return requests.get(jwks_uri).json()
    except Exception as e:
        logging.error(f"Failed to fetch JWKS: {e}")
        return {"keys": []}

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
        logging.error(f"JWT verification failed: {e}")
        return None

def get_role_from_token(token):
    # Try RBAC config first
    if token in TOKEN_ROLE_MAP:
        return TOKEN_ROLE_MAP[token]
    # Try JWT validation
    payload = verify_id_token(token)
    if payload:
        roles = payload.get("roles", [])
        if isinstance(roles, str):
            roles = [roles]
        # Return the first matching role in ROLE_COMMANDS
        for role in roles:
            if role in ROLE_COMMANDS:
                return role
    return None

def is_command_allowed(role, command):
    cmd = command.split()[0]
    return role in ROLE_COMMANDS and cmd in ROLE_COMMANDS[role]

def stream_result(channel, batch_id, command_id, output):
    result_msg = {
        'batch_id': batch_id,
        'command_id': command_id,
        'output': output
    }
    channel.basic_publish(exchange='', routing_key=RESULTS_QUEUE, body=json.dumps(result_msg))

def process_command(channel, batch_id, command, command_id, role):
    if not is_command_allowed(role, command):
        out = f"Role '{role}' not allowed to run '{command}'"
        logging.warning(f"{out} (batch_id={batch_id}, command_id={command_id})")
        stream_result(channel, batch_id, command_id, out)
        return
    try:
        proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
                stream_result(channel, batch_id, command_id, line)
        proc.wait()
        if proc.returncode == 0:
            logging.info(f"Command '{command}' succeeded (batch_id={batch_id}, command_id={command_id})")
        else:
            logging.error(f"Command '{command}' failed (batch_id={batch_id}, command_id={command_id})")
    except Exception as e:
        out = str(e)
        logging.error(f"Exception running '{command}' (batch_id={batch_id}, command_id={command_id}): {out}")
        stream_result(channel, batch_id, command_id, out)

def on_message(ch, method, properties, body):
    try:
        msg = json.loads(body)
        token = msg.get('token') or msg.get('user_info', {}).get('id_token')
        batch_id = msg.get('batch_id', 'single')
        commands = msg.get('commands', [])
        # Support single command as well
        if not commands and 'command' in msg:
            commands = [{'command': msg['command'], 'command_id': msg.get('command_id', 'single')}]
        role = get_role_from_token(token)
        if not role:
            logging.warning(f"Unauthorized or unknown token (batch_id={batch_id})")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return
        for cmd in commands:
            command = cmd['command']
            command_id = cmd.get('command_id', 'single')
            process_command(ch, batch_id, command, command_id, role)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        logging.error(f"Malformed message or processing error: {str(e)}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

def main():
    connection = pika.BlockingConnection(pika.ConnectionParameters(RABBITMQ_HOST))
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    channel.queue_declare(queue=RESULTS_QUEUE)
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='commands', on_message_callback=on_message)
    logging.info("Unified agent started, waiting for commands/batches...")
    channel.start_consuming()

if __name__ == '__main__':
    main()