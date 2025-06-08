import os
from flask import Blueprint, jsonify, current_app
from .command_utils import send_command_and_start_bridge

def create_service_blueprint(service_name, commands_map, namespace=None):
    bp = Blueprint(service_name, __name__)
    # Target server config (set these in your environment or .env)
    TARGET_SERVER_API = os.environ.get("TARGET_SERVER_API", "http://web-controller.gok-controller.svc:8080/send-command-batch")
    TARGET_SOCKET_HOST = os.environ.get("TARGET_SOCKET_HOST", "web-controller.gok-controller.svc")
    TARGET_SOCKET_PORT = int(os.environ.get("TARGET_SOCKET_PORT", "8080"))
    bridges = {}

    def get_socketio():
        return current_app.extensions["socketio"]

    for route, commands in commands_map.items():
        endpoint = f"{service_name}_{route}"
        @bp.route(f"/{route}", methods=["POST"], endpoint=endpoint)
        def service_command(route=route, commands=commands):
            # If namespace is provided, format commands with it
            formatted_commands = [cmd.format(namespace=namespace) if namespace else cmd for cmd in commands]
            batch_id, error_resp, status = send_command_and_start_bridge(
                formatted_commands, bridges, get_socketio(), TARGET_SERVER_API, TARGET_SOCKET_HOST, TARGET_SOCKET_PORT
            )
            if error_resp:
                return error_resp, status
            return jsonify({"msg": "Command sent", "batch_id": batch_id}), 200

    return bp