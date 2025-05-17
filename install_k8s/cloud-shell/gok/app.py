import os
import jwt
import re
from flask import Flask, request, redirect, abort, render_template_string
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
        "username": payload.get("preferred_username"),
        "groups": payload.get("groups", [])
    }

def get_pod_name(username):
    return f"ttyd-{username}"

def get_service_name(username):
    return f"ttyd-{username}"

def get_ingress_name(username):
    return f"ttyd-{username}"

def ensure_serviceaccount(username):
    v1 = client.CoreV1Api()
    sa_name = f"user-{username}"
    try:
        v1.read_namespaced_service_account(sa_name, NAMESPACE)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            sa_manifest = {
                "apiVersion": "v1",
                "kind": "ServiceAccount",
                "metadata": {"name": sa_name}
            }
            v1.create_namespaced_service_account(namespace=NAMESPACE, body=sa_manifest)
        else:
            raise

def ensure_rolebinding(username, groups):
    rbac_v1 = client.RbacAuthorizationV1Api()
    rb_name = f"user-{username}-binding"
    sa_name = f"user-{username}"
    # Example: Give admin if in administrators, else developer role
    if "administrators" in groups:
        role = "admin"
    elif "developers" in groups:
        role = "edit"
    else:
        role = "view"
    try:
        rbac_v1.read_namespaced_role_binding(rb_name, NAMESPACE)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            rb_manifest = {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "RoleBinding",
                "metadata": {"name": rb_name},
                "subjects": [{
                    "kind": "ServiceAccount",
                    "name": sa_name,
                    "namespace": NAMESPACE
                }],
                "roleRef": {
                    "kind": "ClusterRole",
                    "name": role,
                    "apiGroup": "rbac.authorization.k8s.io"
                }
            }
            rbac_v1.create_namespaced_role_binding(namespace=NAMESPACE, body=rb_manifest)
        else:
            raise

def ensure_ttyd_pod(username, token):
    v1 = client.CoreV1Api()
    pod_name = get_pod_name(username)
    sa_name = f"user-{username}"
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
                # "serviceAccountName": sa_name,
                "volumes": [
                    {"name": "tools", "emptyDir": {}}
                ],
                "initContainers": [
                    {
                        "name": "install-tools",
                        "image": "alpine:3.19",
                        "env": [
                            {
                                "name": "KUBE_TOKEN",
                                "value": token
                            }
                        ],
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
                                "cp /usr/bin/docker /tools/docker\n"
                                "# Write kubeconfig\n"
                                "cat <<EOF > /tools/kubeconfig\n"
                                "apiVersion: v1\n"
                                "kind: Config\n"
                                "clusters:\n"
                                "- cluster:\n"
                                "    server: https://kubernetes.default.svc\n"
                                "    insecure-skip-tls-verify: true\n"
                                "  name: k8s\n"
                                "users:\n"
                                "- name: user\n"
                                "  user:\n"
                                "    token: $KUBE_TOKEN\n"
                                "contexts:\n"
                                "- context:\n"
                                "    cluster: k8s\n"
                                "    user: user\n"
                                "  name: k8s\n"
                                "current-context: k8s\n"
                                "EOF\n"
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
                            },
                            {
                                "name": "KUBECONFIG",
                                "value": "/tools/kubeconfig"
                            },
                            {
                                "name": "KUBE_TOKEN",
                                "value": token
                            }
                        ],
                        "resources": {},
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
                        "nginx.ingress.kubernetes.io/auth-url": "https://cloudshell.gokcloud.com/shell/validate",
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

@app.route("/validate")
def validate_user():
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ", 1)[1]
    userinfo = get_user_info_from_token(token)
    current_user = userinfo["username"]

    # Extract original URI from header
    orig_uri = request.headers.get("X-Original-URI", "")

    # Match /user/<username> (optionally with trailing slash or path)
    m = re.match(r"^/user/([^/]+)", orig_uri)
    if not m:
        abort(400, f"Bad request: cannot extract username from path, current_user: {current_user} orig_uri: {orig_uri}")
    username = m.group(1)

    if current_user != username:
        abort(403, "Forbidden: You cannot access another user's terminal.")
    return {"allowed": True}

@app.route("/status/<username>")
def status(username):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ", 1)[1]
    userinfo = get_user_info_from_token(token)
    current_user = userinfo["username"]
    if current_user != username:
        abort(403, "Forbidden")
    v1 = client.CoreV1Api()
    service_name = get_service_name(username)
    try:
        svc = v1.read_namespaced_service(service_name, NAMESPACE)
        pods = v1.list_namespaced_pod(NAMESPACE, label_selector=f"user={username}")
        if pods.items and all(pod.status.phase == "Running" for pod in pods.items):
            return {"ready": True}
    except Exception:
        pass
    return {"ready": False}

@app.route("/")
def index():
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ", 1)[1]
    userinfo = get_user_info_from_token(token)
    username = userinfo["username"]
    userid = userinfo["userid"]
    groups = userinfo.get("groups", [])

    # ensure_serviceaccount(username)
    # ensure_rolebinding(username, groups)
    ensure_ttyd_pod(username, token)
    ensure_ttyd_service(username)
    ensure_ttyd_ingress(username)

    user_url = f"https://cloudshell.gokcloud.com/user/{username}/"
    # Serve progress page with JS polling
    return render_template_string("""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Starting your Cloud Shell...</title>
      <script>
        async function poll() {
          let resp = await fetch("/shell/status/{{username}}", {headers: {"Authorization": document.cookie.split('; ').find(row => row.startsWith('Authorization='))?.split('=')[1] ? "Bearer " + document.cookie.split('; ').find(row => row.startsWith('Authorization='))?.split('=')[1] : ""}});
          let data = await resp.json();
          if (data.ready) {
            window.location.href = "{{user_url}}";
          } else {
            setTimeout(poll, 2000);
          }
        }
        window.onload = poll;
      </script>
    </head>
    <body>
      <h2>Starting your Cloud Shell...</h2>
      <p>Please wait while your environment is being prepared.</p>
      <div id="spinner" style="font-size:48px;">⏳</div>
    </body>
    </html>
    """, username=username, user_url=user_url)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)