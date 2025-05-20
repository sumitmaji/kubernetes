import os
import uuid
import json
import pika
import logging
import requests
from datetime import timedelta
from functools import wraps
from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity, get_jwt
)
from werkzeug.security import check_password_hash, generate_password_hash
from vault import get_vault_secrets
from threading import Thread
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from jose import jwt as jose_jwt

# --- Config ---
OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID")
REQUIRED_ROLE = os.environ.get("REQUIRED_ROLE", "user")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "mq")

# --- Vault secret reload logic ---
class SecretReloadHandler(FileSystemEventHandler):
    def __init__(self, app, jwt=None):
        self.app = app
        self.jwt = jwt

    def on_modified(self, event):
        if event.src_path.endswith("web-controller"):
            secrets = get_vault_secrets()
            self.app.config["JWT_SECRET_KEY"] = secrets.get("jwt-secret", self.app.config.get("JWT_SECRET_KEY"))
            self.app.config["API_TOKEN"] = secrets.get("api-token", self.app.config.get("API_TOKEN"))
            global API_TOKEN
            API_TOKEN = secrets.get("api-token", self.app.config.get("API_TOKEN"))
            print("Secrets reloaded from Vault!")

def start_secrets_watcher(app, jwt=None):
    path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    event_handler = SecretReloadHandler(app, jwt)
    observer = Observer()
    observer.schedule(event_handler, path=path, recursive=False)
    observer.start()

# --- OIDC/JWT helpers ---
def get_jwks():
    jwks_uri = requests.get(f"{OAUTH_ISSUER}/.well-known/openid-configuration").json()["jwks_uri"]
    return requests.get(jwks_uri).json()
JWKS = get_jwks()
def verify_id_token(token):
    try:
        unverified_header = jose_jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        payload = jose_jwt.decode(
            token, key, algorithms=["RS256"], audience=OAUTH_CLIENT_ID, issuer=OAUTH_ISSUER,
        )
        return payload
    except Exception as e:
        print("JWT verification failed:", e)
        return None

def require_oauth(required_role=None):
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
            if required_role:
                roles = payload.get("roles", [])
                if isinstance(roles, str): roles = [roles]
                if required_role not in roles:
                    return jsonify({"msg": "Insufficient role"}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator

# --- Flask app ---
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# Initial load
vault_secrets = get_vault_secrets()
app.config["JWT_SECRET_KEY"] = vault_secrets.get("jwt-secret", "changeme")
app.config["API_TOKEN"] = vault_secrets.get("api-token", "changeme")
API_TOKEN = app.config["API_TOKEN"]
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(minutes=30)

jwt = JWTManager(app)
logging.basicConfig(filename="/var/log/web_controller_access.log", level=logging.INFO)

USERS = {
    "admin": {"pw": generate_password_hash("adminpassword"), "role": "admin"},
    "user": {"pw": generate_password_hash("userpassword"), "role": "user"}
}

def log_access(event, username=None, ip=None, details=None, status="success"):
    log_entry = {
        "event": event,
        "username": username,
        "ip": ip or request.remote_addr,
        "details": details,
        "status": status
    }
    logging.info(json.dumps(log_entry))

@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    username = data.get("username")
    password = data.get("password")
    user = USERS.get(username)
    ip = request.remote_addr
    if not user or not check_password_hash(user["pw"], password):
        log_access("login", username, ip, details="invalid credentials", status="failed")
        return jsonify({"msg": "Invalid credentials"}), 401
    access_token = create_access_token(
        identity=username,
        additional_claims={"role": user["role"]}
    )
    log_access("login", username, ip, status="success")
    return jsonify(access_token=access_token)

@app.route("/logininfo")
@require_oauth()
def logininfo():
    return jsonify({
        "user": request.user.get("name"),
        "userid": request.user.get("sub"),
        "roles": request.user.get("roles", []),
        "email": request.user.get("email"),
    })

@app.route("/send-command-batch", methods=["POST"])
@require_oauth(REQUIRED_ROLE)
def send_command_batch():
    username = request.user.get("name") or request.user.get("sub")
    role = request.user.get("roles", [])
    ip = request.remote_addr
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        log_access("send-command-batch", username, ip, details="Invalid commands format", status="failed")
        return jsonify({"error": "Invalid commands format"}), 400
    user_info = {
        "sub": request.user.get("sub"),
        "name": request.user.get("name"),
        "roles": request.user.get("roles", []),
        "id_token": request.headers.get("Authorization").split(" ", 1)[1]
    }
    batch_id = publish_batch(commands, user_info)
    log_access("send-command-batch", username, ip, details={"batch_id": batch_id, "role": role})
    return jsonify({"msg": "Command batch accepted", "batch_id": batch_id, "issued_by": user_info["sub"], "role": role}), 200

def publish_batch(commands, user_info):
    connection = pika.BlockingConnection(pika.ConnectionParameters(RABBITMQ_HOST))
    channel = connection.channel()
    batch_id = user_info["sub"] + "-" + str(abs(hash(json.dumps(commands))))
    msg = {
        "commands": [{"command": c, "command_id": i} for i, c in enumerate(commands)],
        "user_info": user_info,
        "batch_id": batch_id
    }
    channel.queue_declare(queue="commands")
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
    connection = pika.BlockingConnection(pika.ConnectionParameters(RABBITMQ_HOST))
    channel = connection.channel()
    channel.queue_declare(queue="results")
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

@jwt.unauthorized_loader
def unauthorized_callback(callback):
    log_access("unauthorized", None, request.remote_addr, details=callback, status="failed")
    return jsonify({"msg": "Missing or invalid token"}), 401

@jwt.invalid_token_loader
def invalid_token_callback(callback):
    log_access("invalid_token", None, request.remote_addr, details=callback, status="failed")
    return jsonify({"msg": "Invalid token"}), 401

@app.route("/")
def index():
    return "Agent Controller API is running."

if __name__ == "__main__":
    Thread(target=start_secrets_watcher, args=(app, jwt), daemon=True).start()
    socketio.run(app, host="0.0.0.0", port=8080)