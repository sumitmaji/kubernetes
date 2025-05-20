import os
from functools import wraps
from flask import Flask, request, jsonify, abort
from flask_socketio import SocketIO, emit, join_room
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
            # Optional RBAC
            if required_role:
                roles = payload.get("roles", [])
                if isinstance(roles, str):
                    roles = [roles]
                if required_role not in roles:
                    return jsonify({"msg": "Insufficient role"}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route("/send-command-batch", methods=["POST"])
@require_oauth(REQUIRED_ROLE)
def send_command_batch():
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        return jsonify({"error": "Invalid commands format"}), 400
    # Include user's identity and roles in the message to the agent backend
    user_info = {
        "sub": request.user.get("sub"),
        "name": request.user.get("name"),
        "roles": request.user.get("roles", []),
        "id_token": request.headers.get("Authorization").split(" ", 1)[1]
    }
    # Publish to MQ:
    publish_batch(commands, user_info)
    return jsonify({"msg": "Command batch accepted", "issued_by": user_info["sub"]}), 200

# For WebSocket authentication, you can pass the token in the query string or headers and validate on connect.
@socketio.on("connect")
def ws_connect(auth):
    token = auth.get("token") if auth else None
    payload = verify_id_token(token)
    if not payload:
        return False  # reject connection
    # Attach user info to the socket session if needed

def publish_batch(commands, user_info):
    # Send commands, user_info (including id_token) to agent via MQ (e.g., RabbitMQ)
    pass  # Implement MQ publish here

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=8080)