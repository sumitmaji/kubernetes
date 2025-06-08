import os
from flask import Blueprint, request, jsonify, current_app
from .command_utils import send_command_and_start_bridge
from app.socketio_handlers import register_socketio_handlers

rabbitmq_bp = Blueprint("rabbitmq", __name__)

# Target server config (set these in your environment or .env)
TARGET_SERVER_API = os.environ.get("TARGET_SERVER_API", "http://web-controller.gok-controller.svc:8080/send-command-batch")
TARGET_SOCKET_HOST = os.environ.get("TARGET_SOCKET_HOST", "web-controller.gok-controller.svc")
TARGET_SOCKET_PORT = int(os.environ.get("TARGET_SOCKET_PORT", "8080"))

# Keep track of active bridges per batch_id
bridges = {}

def get_socketio():
    return current_app.extensions["socketio"]

@rabbitmq_bp.route("/logs", methods=["POST"])
def rabbitmq_logs():
    commands = ["kubectl logs -n rabbitmq -l app.kubernetes.io/name=rabbitmq"]
    batch_id, error_resp, status = send_command_and_start_bridge(
        commands, bridges, get_socketio(), TARGET_SERVER_API, TARGET_SOCKET_HOST, TARGET_SOCKET_PORT
    )
    if error_resp:
        return error_resp, status
    return jsonify({"msg": "Command sent", "batch_id": batch_id}), 200

@rabbitmq_bp.route("/pods", methods=["POST"])
def rabbitmq_pods():
    commands = ["kubectl get pods -n rabbitmq"]
    batch_id, error_resp, status = send_command_and_start_bridge(
        commands, bridges, get_socketio(), TARGET_SERVER_API, TARGET_SOCKET_HOST, TARGET_SOCKET_PORT
    )
    if error_resp:
        return error_resp, status
    return jsonify({"msg": "Command sent", "batch_id": batch_id}), 200