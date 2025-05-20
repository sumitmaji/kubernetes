import os
import json
from functools import wraps
import pika
import requests
from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit, join_room
from jose import jwt
from vault import get_vault_secrets
from threading import Thread
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

OAUTH_ISSUER = os.environ.get("OAUTH_ISSUER")
OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID")
REQUIRED_ROLE = os.environ.get("REQUIRED_ROLE", "user")
RABBITMQ_HOST = os.environ.get("RABBITMQ_HOST", "mq")

# --- Vault secret reload logic ---
class SecretReloadHandler(FileSystemEventHandler):
    def __init__(self, app):
        self.app = app
    def on_modified(self, event):
        if event.src_path.endswith("web-controller"):
            secrets = get_vault_secrets()
            self.app.config["API_TOKEN"] = secrets["api-token"]
            print("Secrets reloaded from Vault!")

def start_secrets_watcher(app):
    path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    event_handler = SecretReloadHandler(app)
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
        unverified_header = jwt.get_unverified_header(token)
        key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
        payload = jwt.decode(
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
vault_secrets = get_vault_secrets()
app.config["API_TOKEN"] = vault_secrets["api-token"]

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
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        return jsonify({"error": "Invalid commands format"}), 400
    user_info = {
        "sub": request.user.get("sub"),
        "name": request.user.get("name"),
        "roles": request.user.get("roles", []),
        "id_token": request.headers.get("Authorization").split(" ", 1)[1]
    }
    batch_id = publish_batch(commands, user_info)
    return jsonify({"msg": "Command batch accepted", "batch_id": batch_id, "issued_by": user_info["sub"]}), 200

def publish_batch(commands, user_info):
    connection = pika.BlockingConnection(pika.ConnectionParameters(RABBITMQ_HOST))
    channel = connection.channel()
    batch_id = user_info["sub"] + "-" + str(abs(hash(json.dumps(commands))))
    msg = {
        "commands": commands,
        "user_info": user_info,
        "batch_id": batch_id
    }
    channel.queue_declare(queue="commands")
    channel.basic_publish(exchange='', routing_key="commands", body=json.dumps(msg))
    connection.close()
    return batch_id

if __name__ == "__main__":
    Thread(target=start_secrets_watcher, args=(app,), daemon=True).start()
    socketio.run(app, host="0.0.0.0", port=8080)