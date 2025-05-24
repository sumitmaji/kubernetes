import os
import pika
import subprocess
import logging
import json
from jose import jwt
import requests
import sys

logger = logging.getLogger()
logger.setLevel(logging.INFO)

console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
logger.handlers = [console_handler]

# --- RBAC CONFIG ---
# Example RBAC config, replace with your actual config or import from a file
TOKEN_GROUP_MAP = {
    "supersecrettoken": "administrators",
    "usertoken": "developers"
}
GROUP_COMMANDS = {
    "administrators": ["*"],
    "developers": ["ls", "whoami", "uptime"]
}

# --- OAUTH/JWT CONFIG ---
OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER", "https://accounts.google.com")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID", "your-client-id")
REQUIRED_GROUP = os.environ.get("REQUIRED_GROUP", "administrators")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "localhost")
RESULTS_QUEUE = 'results'
RABBITMQ_USER = os.environ.get("RABBITMQ_USER", "rabbitmq")
RABBITMQ_PASSWORD = os.environ.get("RABBITMQ_PASSWORD", "rabbitmq")

def get_jwks():
    try:
        oidc_conf = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration", verify=False).json()
        jwks_uri = oidc_conf["jwks_uri"]
        return requests.get(jwks_uri, verify=False).json()
    except Exception as e:
        logging.error(f"Failed to fetch JWKS: {e}")
        return {"keys": []}

JWKS = get_jwks()

def verify_id_token(token):
    try:
        unverified_header = jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        try:
            payload = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=OAUTH_CLIENT_ID,
                issuer=OAUTH_ISSUER,
            )
            return payload
        except jwt.JWTError as e:
            if "at_hash" in str(e):
                # Ignore at_hash error if you don't have access_token
                payload = jwt.get_unverified_claims(token)
                logging.warning("Ignoring at_hash error in id_token: using unverified claims.")
                return payload
            else:
                raise
    except Exception as e:
        logging.error(f"JWT verification failed: {e}")
        return None

def get_group_from_token(token):
    # Try RBAC config first
    if token in TOKEN_GROUP_MAP:
        return TOKEN_GROUP_MAP[token]
    # Try JWT validation
    payload = verify_id_token(token)
    if payload:
        groups = payload.get("groups", [])
        if isinstance(groups, str):
            groups = [groups]
        # Return the first matching group in GROUP_COMMANDS
        for group in groups:
            if group in GROUP_COMMANDS:
                return group
    return None

def is_command_allowed(group, command):
    cmd = command.split()[0]
    # Administrators can run any command
    if group == "administrators":
        return True
    return group in GROUP_COMMANDS and cmd in GROUP_COMMANDS[group]


def stream_result(channel, batch_id, command_id, output):
    result_msg = {
        'batch_id': batch_id,
        'command_id': command_id,
        'output': output
    }
    channel.basic_publish(exchange='', routing_key=RESULTS_QUEUE, body=json.dumps(result_msg))

def process_command(channel, batch_id, command, command_id, group):
    if not is_command_allowed(group, command):
        out = f"Group '{group}' not allowed to run '{command}'"
        logging.warning(f"{out} (batch_id={batch_id}, command_id={command_id})")
        stream_result(channel, batch_id, command_id, out)
        return
    try:
        # Use nsenter to run the command in the host's namespaces
        nsenter_prefix = "nsenter --mount=/host/proc/1/ns/mnt --uts=/host/proc/1/ns/uts --ipc=/host/proc/1/ns/ipc --net=/host/proc/1/ns/net --pid=/host/proc/1/ns/pid --"
        command_to_run = f"{nsenter_prefix} bash -c '{command}'"
        proc = subprocess.Popen(command_to_run, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            if line:
                stream_result(channel, batch_id, command_id, line)
        proc.wait()
        if proc.returncode == 0:
            logging.info(f"Command '{command_to_run}' succeeded (batch_id={batch_id}, command_id={command_id})")
        else:
            logging.error(f"Command '{command_to_run}' failed (batch_id={batch_id}, command_id={command_id})")
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
        group = get_group_from_token(token)
        if not group:
            logging.warning(f"Unauthorized or unknown token/group (batch_id={batch_id})")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return
        for cmd in commands:
            command = cmd['command']
            command_id = cmd.get('command_id', 'single')
            process_command(ch, batch_id, command, command_id, group)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        logging.error(f"Malformed message or processing error: {str(e)}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

def ensure_results_queue():
    """Ensure the 'results' queue exists in RabbitMQ, create if not present."""
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    try:
        channel.queue_declare(queue=RESULTS_QUEUE, passive=True)
        logging.info(f"Queue '{RESULTS_QUEUE}' already exists.")
    except pika.exceptions.ChannelClosedByBroker:
        channel = connection.channel()  # Reopen channel after exception
        channel.queue_declare(queue=RESULTS_QUEUE, durable=True)
        logging.info(f"Queue '{RESULTS_QUEUE}' created.")
    finally:
        connection.close()

def ensure_commands_queue():
    """Ensure the 'commands' queue exists in RabbitMQ, create if not present."""
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    try:
        channel.queue_declare(queue='commands', passive=True)
        logging.info("Queue 'commands' already exists.")
    except pika.exceptions.ChannelClosedByBroker:
        channel = connection.channel()  # Reopen channel after exception
        channel.queue_declare(queue='commands', durable=True)
        logging.info("Queue 'commands' created.")
    finally:
        connection.close()

def main():
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    channel.queue_declare(queue='commands')
    channel.queue_declare(queue=RESULTS_QUEUE)
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue='commands', on_message_callback=on_message)
    logging.info("Unified agent started, waiting for commands/batches...")
    channel.start_consuming()

if __name__ == '__main__':
    ensure_results_queue()
    ensure_commands_queue()
    main()