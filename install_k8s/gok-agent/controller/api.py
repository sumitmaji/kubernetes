import os
import uuid
import json
import pika
import logging
from datetime import timedelta
from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity, get_jwt
)
from werkzeug.security import check_password_hash, generate_password_hash
from vault import get_vault_secrets

# For secret file watching
from threading import Thread
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class SecretReloadHandler(FileSystemEventHandler):
    def __init__(self, app, jwt):
        self.app = app
        self.jwt = jwt

    def on_modified(self, event):
        if event.src_path.endswith("web-controller"):
            # Reload secrets
            secrets = get_vault_secrets()
            self.app.config["JWT_SECRET_KEY"] = secrets["jwt-secret"]
            global API_TOKEN
            API_TOKEN = secrets["api-token"]
            # Flask-JWT-Extended uses app.config["JWT_SECRET_KEY"]
            print("Secrets reloaded from Vault!")

def start_secrets_watcher(app, jwt):
    path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    event_handler = SecretReloadHandler(app, jwt)
    observer = Observer()
    observer.schedule(event_handler, path=path, recursive=False)
    observer.start()

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# Initial load
vault_secrets = get_vault_secrets()
app.config["JWT_SECRET_KEY"] = vault_secrets["jwt-secret"]
API_TOKEN = vault_secrets["api-token"]
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

@app.route("/send-command-batch", methods=["POST"])
@jwt_required()
def send_command_batch():
    username = get_jwt_identity()
    claims = get_jwt()
    role = claims.get("role")
    ip = request.remote_addr
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        log_access("send-command-batch", username, ip, details="Invalid commands format", status="failed")
        return jsonify({"error": "Invalid commands format"}), 400
    batch_id = publish_batch(commands, API_TOKEN)
    log_access("send-command-batch", username, ip, details={"batch_id": batch_id, "role": role})
    return jsonify({"batch_id": batch_id, "issued_by": username, "role": role}), 200

@socketio.on("join")
def on_join(data):
    batch_id = data.get("batch_id")
    if batch_id:
        join_room(batch_id)
        emit("joined", {"batch_id": batch_id})

def rabbitmq_result_worker():
    connection = pika.BlockingConnection(pika.ConnectionParameters(os.environ.get("RABBITMQ_HOST", "rabbitmq.default.svc.cluster.local")))
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

def publish_batch(commands, token):
    connection = pika.BlockingConnection(pika.ConnectionParameters(os.environ.get("RABBITMQ_HOST", "rabbitmq.default.svc.cluster.local")))
    channel = connection.channel()
    batch_id = str(uuid.uuid4())
    batch_msg = {
        "commands": [{"command": c, "command_id": i} for i, c in enumerate(commands)],
        "token": token,
        "batch_id": batch_id
    }
    channel.queue_declare(queue="commands")
    channel.basic_publish(exchange='', routing_key="commands", body=json.dumps(batch_msg))
    connection.close()
    return batch_id

if __name__ == "__main__":
    Thread(target=start_secrets_watcher, args=(app, jwt), daemon=True).start()
    socketio.run(app, host="0.0.0.0", port=8080)