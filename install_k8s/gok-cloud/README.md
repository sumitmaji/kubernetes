# GOK Agent & Controller

This project provides a secure, RBAC-enabled, real-time remote command execution system for Kubernetes clusters. It consists of a **Controller** (backend + frontend) and an **Agent** that runs on cluster nodes.

---

## Architecture Overview

- **Controller (Backend + Frontend):**
  - **Backend:** Flask app with Flask-SocketIO, JWT/OIDC authentication, and RabbitMQ integration.
  - **Frontend:** React app for submitting commands and viewing results in real time.
- **Agent:** Python app that listens for command batches via RabbitMQ, verifies group membership, and executes commands on the host using `nsenter`.

---

## Features

- **RBAC via OIDC/JWT groups:** Only authorized users/groups can execute commands.
- **WebSocket real-time results:** Users see command output as it happens.
- **Host-level command execution:** Agent can run commands directly on the host (with `nsenter`).
- **Vault integration:** Secrets (API tokens, etc.) are securely loaded from Vault.
- **Kubernetes-ready:** Deployable via Helm charts, supports Ingress, TLS, and Vault Agent Injector.

---

## Directory Structure

```
install_k8s/gok-agent/
├── agent/
│   ├── app.py                # Agent code (host command execution)
│   ├── requirements.txt
│   └── Dockerfile
├── controller/
│   ├── backend/
│   │   ├── app.py            # Flask backend
│   │   ├── requirements.txt
│   ├── frontend/
│   │   ├── src/App.js        # React frontend
│   │   └── ...
│   ├── chart/                # Helm chart for controller
│   ├── Dockerfile
│   └── ...
└── ...
```

---

## Deployment

### 1. **Build Docker Images**

**Controller:**
```sh
cd ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/controller
./build.sh
./tag_push.sh
```

**Agent:**
```sh
cd ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/agent
./build.sh
./tag_push.sh
```

---

### 2. **Helm Deployment**

- Edit `values.yaml` in the respective `chart/` directories to set image tags, RabbitMQ host, ingress hostnames, Vault settings, etc.
- Deploy with Helm:
  ```sh
  cd ${MOUNT_PAHT}/kubernetes/install_k8s
  ./gok install gok-controller
  ./gok install gok-agent
  ```

---

### 3. **Kubernetes Ingress Example**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-controller
  namespace: gok-controller
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/websocket-services: "web-controller"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - web-controller.example.com
      secretName: web-controller-tls
  rules:
    - host: web-controller.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-controller
                port:
                  number: 8080
```

---

## Security Notes

- **Agent runs as privileged and with hostPID:** This is required for `nsenter` to execute commands on the host. Only deploy in trusted environments.
- **RBAC enforced via OIDC/JWT groups:** Only users in allowed groups (e.g., `administrators`, `developers`) can execute commands.
- **Vault integration:** Secrets are loaded securely at runtime.

---

## Usage

### **Web UI**
- Login to `https://controller.gokcloud.com` via your OIDC provider (e.g., Keycloak, Auth0) through oauth2-proxy.
- Enter commands in the textarea, one per line.
- Click **Send** to execute. Results stream in real time.

### **RBAC**
- Group membership is checked via the `groups` claim in the JWT.
- `administrators` group can run any command.
- Other groups (e.g., `developers`) are limited to specific commands as defined in `GROUP_COMMANDS`.

---

## Agent Host Command Execution

- The agent uses `nsenter` to run commands in the host's namespaces.
- Example: Running `apt-get update` from the UI will execute it on the host, not in the container.

---

## Environment Variables

**Controller:**
- `OAUTH_ISSUER`: OIDC issuer URL
- `OAUTH_CLIENT_ID`: OIDC client ID
- `REQUIRED_GROUP`: Group required to execute commands (default: `user`)
- `RABBITMQ_HOST`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`: RabbitMQ connection

**Agent:**
- `OAUTH_ISSUER`, `OAUTH_CLIENT_ID`, `REQUIRED_GROUP`
- `RABBITMQ_HOST`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`

---

## Token Lifetime

- Token lifetime is controlled by your OIDC provider (e.g., Keycloak).
- To increase, adjust the **Access Token Lifespan** and **ID Token Lifespan** in your provider's settings.

---

## Development

- **Frontend:** React app in `controller/frontend/`
- **Backend:** Flask app in `controller/backend/`
- **Agent:** Python app in `agent/`

---

## Troubleshooting

- **WebSocket issues:** Ensure NGINX/Ingress is configured for WebSocket upgrades.
- **RabbitMQ authentication errors:** Check `RABBITMQ_USER` and `RABBITMQ_PASSWORD`.
- **OIDC/JWT errors:** Ensure tokens are valid and contain the correct `groups` claim.

---

## License

MIT or your organization’s license.

---

## Authors

- [Your Name/Team]