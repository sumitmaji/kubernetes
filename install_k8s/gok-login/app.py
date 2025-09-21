from flask import Flask, request, jsonify
import requests
import os

app = Flask(__name__)

KEYCLOAK_URL = os.environ.get("KEYCLOAK_URL", "https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/token")
CLIENT_ID = os.environ.get("CLIENT_ID", "gok-developers-client")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")

@app.route('/login', methods=['POST'])
def login():
    import logging
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger("gok-login")

    logger.debug(f"Received login request: {request.json}")
    data = request.json
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        logger.warning("Missing username or password in request")
        return jsonify({"error": "Missing username or password"}), 400
    payload = {
        'grant_type': 'password',
        'client_id': CLIENT_ID,
        'username': username,
        'password': password
    }
    if CLIENT_SECRET:
        payload['client_secret'] = CLIENT_SECRET
    logger.debug(f"Sending payload to Keycloak: {payload}")
    try:
        resp = requests.post(KEYCLOAK_URL, data=payload)
        logger.debug(f"Keycloak response status: {resp.status_code}")
        logger.debug(f"Keycloak response body: {resp.text}")
    except Exception as e:
        logger.error(f"Exception during Keycloak request: {e}")
        return jsonify({"error": "Internal server error", "details": str(e)}), 500
    if resp.status_code == 200:
        logger.info("Login successful")
        return jsonify(resp.json())
    else:
        logger.warning(f"Authentication failed: {resp.text}")
        return jsonify({"error": "Authentication failed", "details": resp.text}), resp.status_code

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
