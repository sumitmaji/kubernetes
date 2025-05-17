import os
import jwt
from flask import Flask, request, jsonify, redirect
from kubernetes import client, config

app = Flask(__name__)

# Kubernetes config
if os.getenv("KUBERNETES_SERVICE_HOST"):
    config.load_incluster_config()
else:
    config.load_kube_config()

NAMESPACE = "cloudshell"
TTYD_IMAGE = "tsl0922/ttyd"
TTYD_PORT = 7681

def get_user_info_from_token(token):
    payload = jwt.decode(token, options={"verify_signature": False})
    return {
        "userid": payload.get("sub"),
        "username": payload.get("preferred_username")
    }

def get_pod_name(username):
    return f"ttyd-{username}"

def get_service_name(username):
    return f"ttyd-{username}"

def get_ingress_name(username):
    return f"ttyd-{username}"

def ensure_ttyd_pod(username):
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
                "volumes": [
                    {"name": "tools", "emptyDir": {}}
                ],
                "initContainers": [
                    {
                        "name": "install-tools",
                        "image": "alpine:3.19",
                        "command": [
                            "sh",
                            "-c",
                            (
                                "set -ex\n"
                                "apk update\n"
                                "apk add --no-cache curl bash docker-cli openssl file\n"
                                "# Install kubectl\n"
                                "KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)\n"
                                "curl -LO \"https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl\"\n"
                                "if ! file kubectl | grep -q 'ELF'; then\n"
                                "  echo \"kubectl download failed!\"\n"
                                "  exit 1\n"
                                "fi\n"
                                "install -m 755 kubectl /tools/kubectl\n"
                                "# Install helm\n"
                                "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash\n"
                                "mv /usr/local/bin/helm /tools/helm\n"
                                "# Copy docker client\n"
                                "cp /bin/docker /tools/docker\n"
                            )
                        ],
                        "volumeMounts": [
                            {"name": "tools", "mountPath": "/tools"}
                        ]
                    }
                ],
                "containers": [
                    {
                        "name": "ttyd",
                        "image": TTYD_IMAGE,
                        "imagePullPolicy": "IfNotPresent",
                        "command": ["ttyd"],
                        "args": ["-W", "bash"],
                        "ports": [{"containerPort": TTYD_PORT}],
                        "env": [
                            {
                                "name": "PATH",
                                "value": "/tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                            }
                        ],
                        "resources": {},  # Add resource limits if needed
                        "volumeMounts": [
                            {"name": "tools", "mountPath": "/tools"}
                        ]
                    }
                ]
            }
        }
        v1.create_namespaced_pod(namespace=NAMESPACE, body=pod_manifest)

def ensure_ttyd_service(username):
    v1 = client.CoreV1Api()
    service_name = get_service_name(username)
    try:
        v1.read_namespaced_service(service_name, NAMESPACE)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            service_manifest = {
                "apiVersion": "v1",
                "kind": "Service",
                "metadata": {
                    "name": service_name,
                    "labels": {"user": username}
                },
                "spec": {
                    "selector": {"user": username},
                    "ports": [{
                        "protocol": "TCP",
                        "port": TTYD_PORT,
                        "targetPort": TTYD_PORT
                    }]
                }
            }
            v1.create_namespaced_service(namespace=NAMESPACE, body=service_manifest)
        else:
            raise

def ensure_ttyd_ingress(username):
    networking_v1 = client.NetworkingV1Api()
    ingress_name = get_ingress_name(username)
    try:
        networking_v1.read_namespaced_ingress(ingress_name, NAMESPACE)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            ingress_manifest = {
                "apiVersion": "networking.k8s.io/v1",
                "kind": "Ingress",
                "metadata": {
                    "name": ingress_name,
                    "annotations": {
                        "nginx.ingress.kubernetes.io/auth-url": "https://kube.gokcloud.com/oauth2/auth",
                        "nginx.ingress.kubernetes.io/auth-signin": f"https://kube.gokcloud.com/oauth2/start?rd=https://cloudshell.gokcloud.com/user/{username}",
                        "nginx.ingress.kubernetes.io/auth-response-headers": "Authorization",
                        "kubernetes.io/ingress.class": "nginx",
                        "nginx.ingress.kubernetes.io/proxy-read-timeout": "3600",
                        "nginx.ingress.kubernetes.io/proxy-send-timeout": "3600",
                        "nginx.ingress.kubernetes.io/proxy-http-version": "1.1",
                        "nginx.ingress.kubernetes.io/ssl-redirect": "true",
                        "cert-manager.io/cluster-issuer": "gokselfsign-ca-cluster-issuer",
                        "nginx.ingress.kubernetes.io/rewrite-target": "/"
                    }
                },
                "spec": {
                    "ingressClassName": "nginx",
                    "tls": [{
                        "hosts": ["cloudshell.gokcloud.com"],
                        "secretName": "cloudshell-gokcloud-com"
                    }],
                    "rules": [{
                        "host": "cloudshell.gokcloud.com",
                        "http": {
                            "paths": [{
                                "path": f"/user/{username}",
                                "pathType": "Prefix",
                                "backend": {
                                    "service": {
                                        "name": get_service_name(username),
                                        "port": {"number": TTYD_PORT}
                                    }
                                }
                            }]
                        }
                    }]
                }
            }
            networking_v1.create_namespaced_ingress(namespace=NAMESPACE, body=ingress_manifest)
        else:
            raise

@app.route("/")
def index():
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ", 1)[1]
    userinfo = get_user_info_from_token(token)
    username = userinfo["username"]
    userid = userinfo["userid"]

    # Ensure pod, service, and ingress exist
    ensure_ttyd_pod(username)
    ensure_ttyd_service(username)
    ensure_ttyd_ingress(username)

    user_url = f"https://cloudshell.gokcloud.com/user/{username}/"
    return redirect(user_url)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)