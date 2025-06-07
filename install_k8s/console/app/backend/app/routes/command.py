import os
import requests
from flask import Blueprint, request, jsonify, current_app
from flask_socketio import emit
from app.socket_bridge import SocketBridge  # You will need to create this file

command_bp = Blueprint("command", __name__)

# Target server config (set these in your environment or .env)
TARGET_SERVER_API = os.environ.get("TARGET_SERVER_API", "http://web-controller.gok-controller.svc:8080/send-command-batch")
TARGET_SOCKET_HOST = os.environ.get("TARGET_SOCKET_HOST", "controller.gokcloud.com")
TARGET_SOCKET_PORT = int(os.environ.get("TARGET_SOCKET_PORT", "9000"))

# Keep track of active bridges per batch_id
bridges = {}

@command_bp.route("/send_command", methods=["POST"])
def send_command():
    data = request.json or {}
    commands = data.get("commands", [])
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        return jsonify({"error": "Invalid commands format"}), 400

    # Skip SSL verification in debug mode
    verify_ssl = not current_app.debug    

    # Forward to target server's /send_batch_command
    print(request.headers)

    resp = requests.post(
        TARGET_SERVER_API,
        json={"commands": commands},
        headers={"Authorization": request.headers.get("Authorization")},
        verify=verify_ssl
    )

    print(resp)
    print(resp.text)

    if resp.status_code != 200:
        return jsonify({"error": "Failed to send to target server", "details": resp.text}), 502

    batch_id = resp.json().get("batch_id")
    if not batch_id:
        return jsonify({"error": "No batch_id from target server"}), 502

    # Start socket bridge for this batch_id
    if batch_id not in bridges:
        bridges[batch_id] = SocketBridge(current_app.socketio, TARGET_SOCKET_HOST, TARGET_SOCKET_PORT)
        bridges[batch_id].start(batch_id)

    return jsonify({"msg": "Command sent", "batch_id": batch_id}), 200