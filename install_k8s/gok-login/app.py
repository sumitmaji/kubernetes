from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

KEYCLOAK_URL = os.environ.get("KEYCLOAK_URL", "https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/token")
CLIENT_ID = os.environ.get("CLIENT_ID", "gok-developers-client")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        return jsonify({"error": "Missing username or password"}), 400
    payload = {
        'grant_type': 'password',
        'client_id': CLIENT_ID,
        'username': username,
        'password': password
    }
    if CLIENT_SECRET:
        payload['client_secret'] = CLIENT_SECRET
    resp = requests.post(KEYCLOAK_URL, data=payload)
    if resp.status_code == 200:
        return jsonify(resp.json())
    else:
        return jsonify({"error": "Authentication failed", "details": resp.text}), resp.status_code

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
