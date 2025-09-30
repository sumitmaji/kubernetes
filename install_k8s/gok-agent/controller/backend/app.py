import os
import uuid
import json
import pika
import logging
import requests
import base64
import subprocess
from functools import wraps
from flask import Flask, request, jsonify, send_from_directory
from flask_socketio import SocketIO, emit, join_room
from werkzeug.security import check_password_hash, generate_password_hash
from vault import get_vault_secrets
from threading import Thread
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from jose import jwt as jose_jwt
import sys

logger = logging.getLogger()
logger.setLevel(logging.INFO)

console_handler = logging.StreamHandler(sys.stdout)
console_handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
logger.handlers = [console_handler]

# --- Config ---
OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID")
REQUIRED_GROUP = os.environ.get("REQUIRED_GROUP", "user")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "rabbitmq.rabbitmq.svc.cluster.local")

def get_rabbitmq_credentials():
    """
    Try to get RabbitMQ credentials from Kubernetes secret
    """
    try:
        # Get username
        result = subprocess.run([
            'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
            '-n', 'rabbitmq', '-o', 'jsonpath={.data.username}'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            logging.warning("Could not retrieve RabbitMQ username from Kubernetes secret")
            return None, None
            
        username = base64.b64decode(result.stdout).decode()
        
        # Get password
        result = subprocess.run([
            'kubectl', 'get', 'secret', 'rabbitmq-default-user', 
            '-n', 'rabbitmq', '-o', 'jsonpath={.data.password}'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            logging.warning("Could not retrieve RabbitMQ password from Kubernetes secret")
            return username, None
            
        password = base64.b64decode(result.stdout).decode()
        logging.info("Successfully retrieved RabbitMQ credentials from Kubernetes")
        return username, password
        
    except Exception as e:
        logging.error(f"Failed to retrieve RabbitMQ credentials from Kubernetes: {e}")
        return None, None

# Get RabbitMQ credentials from Kubernetes or use environment variables as fallback
RABBITMQ_USER_K8S, RABBITMQ_PASSWORD_K8S = get_rabbitmq_credentials()
RABBITMQ_USER = RABBITMQ_USER_K8S or os.environ.get("RABBITMQ_USER", "guest")
RABBITMQ_PASSWORD = RABBITMQ_PASSWORD_K8S or os.environ.get("RABBITMQ_PASSWORD", "guest")

# --- Vault secret reload logic ---
class SecretReloadHandler(FileSystemEventHandler):
    def __init__(self, app):
        self.app = app

    def on_modified(self, event):
        if event.src_path.endswith("web-controller"):
            secrets = get_vault_secrets()
            self.app.config["API_TOKEN"] = secrets.get("api-token", self.app.config.get("API_TOKEN"))
            global API_TOKEN
            API_TOKEN = secrets.get("api-token", self.app.config.get("API_TOKEN"))
            print("Secrets reloaded from Vault!")

def start_secrets_watcher(app):
    path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    event_handler = SecretReloadHandler(app)
    observer = Observer()
    observer.schedule(event_handler, path=path, recursive=False)
    observer.start()

# --- OIDC/JWT helpers ---
def get_jwks():
    try:
        oidc_conf = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration", verify=True).json()
        jwks_uri = oidc_conf["jwks_uri"]
        return requests.get(jwks_uri, verify=True).json()
    except Exception as e:
        logging.error(f"Failed to fetch JWKS: {e}")
        return {"keys": []}

JWKS = get_jwks()

def verify_id_token(token):
    try:
        unverified_header = jose_jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        try:
            payload = jose_jwt.decode(
                token, key, algorithms=["RS256"], audience=OAUTH_CLIENT_ID, issuer=OAUTH_ISSUER,
            )
            return payload
        except jose_jwt.JWTError as e:
            if "at_hash" in str(e):
                # Ignore at_hash error if you don't have access_token
                payload = jose_jwt.get_unverified_claims(token)
                return payload
            else:
                raise
    except Exception as e:
        print("JWT verification failed:", e)
        return None

def require_oauth(required_group=None):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            auth = request.headers.get("Authorization", "")
            if not auth.startswith("Bearer "):
                return jsonify({"msg": "Missing token"}), 401
            token = auth.split(" ", 1)[1]
            payload = verify_id_token(token)
            if not payload:
                return jsonify({"msg": "Invalid token"}), 401
            request.user = payload
            if required_group:
                groups = payload.get("groups", [])
                if isinstance(groups, str):
                    groups = [groups]
                if required_group not in groups:
                    print(f"User groups: {groups}")
                    print(f"Required group: {required_group}")

                    return jsonify({"msg": "Insufficient group"}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator

# --- Flask app ---
app = Flask(
    __name__,
    static_folder="static",  # This is where your React build is copied
    static_url_path=""       # Serve static files at root
)
socketio = SocketIO(app, cors_allowed_origins="*")

# Initial load
vault_secrets = get_vault_secrets()
app.config["API_TOKEN"] = vault_secrets.get("api-token", "changeme")
API_TOKEN = app.config["API_TOKEN"]

def log_access(event, username=None, ip=None, details=None, status="success"):
    log_entry = {
        "event": event,
        "username": username,
        "ip": ip or request.remote_addr,
        "details": details,
        "status": status
    }
    logging.info(json.dumps(log_entry))

@app.route("/logininfo")
@require_oauth()
def logininfo():
    return jsonify({
        "user": request.user.get("preferred_username"),
        "name": request.user.get("name"),
        "userid": request.user.get("sub"),
        "groups": request.user.get("groups", []),
        "email": request.user.get("email"),
    })

@app.route("/send-command-batch", methods=["POST"])
@require_oauth(REQUIRED_GROUP)
def send_command_batch():
    username = request.user.get("name") or request.user.get("sub")
    groups = request.user.get("groups", [])
    ip = request.remote_addr
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        log_access("send-command-batch", username, ip, details="Invalid commands format", status="failed")
        return jsonify({"error": "Invalid commands format"}), 400
    user_info = {
        "sub": request.user.get("sub"),
        "name": request.user.get("name"),
        "groups": request.user.get("groups", []),
        "id_token": request.headers.get("Authorization").split(" ", 1)[1]
    }
    batch_id = publish_batch(commands, user_info)
    log_access("send-command-batch", username, ip, details={"batch_id": batch_id, "groups": groups})
    return jsonify({"msg": "Command batch accepted", "batch_id": batch_id, "issued_by": user_info["sub"], "groups": groups}), 200

def publish_batch(commands, user_info):
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    batch_id = user_info["sub"] + "-" + str(abs(hash(json.dumps(commands))))
    msg = {
        "commands": [{"command": c, "command_id": i} for i, c in enumerate(commands)],
        "user_info": user_info,
        "batch_id": batch_id
    }
    channel.queue_declare(queue="commands", durable=True)
    channel.basic_publish(exchange='', routing_key="commands", body=json.dumps(msg))
    connection.close()
    return batch_id

@socketio.on("join")
def on_join(data):
    batch_id = data.get("batch_id")
    if batch_id:
        join_room(batch_id)
        emit("joined", {"batch_id": batch_id})

def rabbitmq_result_worker():
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(RABBITMQ_HOST, credentials=credentials)
    )
    channel = connection.channel()
    channel.queue_declare(queue="results", durable=True)
    for method_frame, properties, body in channel.consume("results", inactivity_timeout=1):
        if body is not None:
            msg = json.loads(body)
            batch_id = msg.get("batch_id")
            socketio.emit("result", msg, room=batch_id)
            channel.basic_ack(method_frame.delivery_tag)
        socketio.sleep(0.01)

@socketio.on("connect")
def start_worker():
    if not hasattr(socketio, "result_thread"):
        socketio.result_thread = socketio.start_background_task(rabbitmq_result_worker)

# Catch-all route to serve React for client-side routing
@app.errorhandler(404)
def not_found(e):
    return send_from_directory(app.static_folder, "index.html")

@app.route("/")
def index():
    # Serve the React index.html
    return send_from_directory(app.static_folder, "index.html")

if __name__ == "__main__":
    Thread(target=start_secrets_watcher, args=(app,), daemon=True).start()
    socketio.run(app, host="0.0.0.0", port=8080, allow_unsafe_werkzeug=True)