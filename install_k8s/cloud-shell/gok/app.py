import os
import jwt
from flask import Flask, request, redirect, url_for, jsonify
from kubernetes import client, config

app = Flask(__name__)

# Load kube config (in-cluster or local)
if os.getenv("KUBERNETES_SERVICE_HOST"):
    config.load_incluster_config()
else:
    config.load_kube_config()

NAMESPACE = "cloudshell"
TTYD_IMAGE = "tsl0922/ttyd"
TTYD_PORT = 7681

def get_user_info_from_token(token):
    # Decode JWT without verification (for demo; in prod, verify signature!)
    payload = jwt.decode(token, options={"verify_signature": False})
    return {
        "userid": payload.get("sub"),
        "username": payload.get("preferred_username")
    }

def get_pod_name(username):
    return f"ttyd-{username}"

@app.route("/")
def index():
    # Get Authorization header from oauth2-proxy
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ", 1)[1]
    userinfo = get_user_info_from_token(token)
    username = userinfo["username"]
    userid = userinfo["userid"]

    # Create ttyd pod if not exists
    v1 = client.CoreV1Api()
    pod_name = get_pod_name(username)
    pods = v1.list_namespaced_pod(NAMESPACE, label_selector=f"user={username}")
    if not pods.items:
        pod_manifest = {
            "apiVersion": "v1",
            "kind": "Pod",
            "metadata": {
                "name": pod_name,
                "labels": {"user": username}
            },
            "spec": {
                "containers": [{
                    "name": "ttyd",
                    "image": TTYD_IMAGE,
                    "command": ["ttyd"],
                    "args": ["-W", "bash"],
                    "ports": [{"containerPort": TTYD_PORT}]
                }]
            }
        }
        v1.create_namespaced_pod(namespace=NAMESPACE, body=pod_manifest)

    # Return per-user proxy URL
    user_url = f"https://cloudshell.gokcloud.com/user/{username}/"
    return jsonify({
        "userid": userid,
        "username": username,
        "ttyd_url": user_url
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)