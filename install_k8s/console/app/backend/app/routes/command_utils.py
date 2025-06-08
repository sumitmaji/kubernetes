import requests
from flask import current_app, request, jsonify
from app.socket_bridge import SocketBridge

def send_command_and_start_bridge(commands, bridges, socketio, target_api, target_host, target_port):
    # Skip SSL verification in debug mode
    verify_ssl = not current_app.debug

    resp = requests.post(
        target_api,
        json={"commands": commands},
        headers={"Authorization": request.headers.get("Authorization")},
        verify=verify_ssl
    )

    if resp.status_code != 200:
        return None, jsonify({"error": "Failed to send to target server", "details": resp.text}), 502

    batch_id = resp.json().get("batch_id")
    if not batch_id:
        return None, jsonify({"error": "No batch_id from target server"}), 502

    # Start socket bridge for this batch_id
    if batch_id not in bridges:
        bridges[batch_id] = SocketBridge(socketio, target_host, target_port)
        bridges[batch_id].start(batch_id)

    return batch_id, None, None