# Cloud Shell for Kubernetes

This project provides a **Kubernetes Cloud Shell** experience for users, launching a personal web terminal (powered by [ttyd](https://github.com/tsl0922/ttyd)) in a dedicated pod, with RBAC and OIDC integration.

---

## Features

- **Per-user web terminals**: Each user gets their own pod running a shell, accessible via browser.
- **RBAC integration**: User's Kubernetes permissions are mapped to their shell session.
- **OIDC/JWT authentication**: User identity and group membership are extracted from tokens.
- **Dynamic resource management**: Pods, Services, and Ingresses are created and deleted on demand.
- **Pre-installed tools**: `kubectl`, `helm`, `docker`, and more are available in the shell.
- **Ingress with SSO**: NGINX Ingress is configured for secure, SSO-protected access.

---

## Directory Structure

```
cloud-shell/gok/
├── app.py                # Flask backend for Cloud Shell management
console/app/
├── Dockerfile            # Multi-stage build for backend + frontend
```

---

## How It Works

1. **User accesses `/`**:  
   - The backend extracts the user's JWT (from header or cookie).
   - Ensures a pod, service, and ingress exist for the user.
   - Returns a progress page that redirects to the user's shell when ready.

2. **Pod Initialization**:  
   - An init container installs tools (`kubectl`, `helm`, etc.) and writes a kubeconfig using the user's token.
   - The main container runs `ttyd`, exposing a web terminal.

3. **RBAC**:  
   - The backend can create a ServiceAccount and RoleBinding for the user, mapping their group to a Kubernetes role.

4. **Ingress**:  
   - Each user gets a unique ingress path (e.g., `/user/<username>`) protected by SSO.

5. **Session Deletion**:  
   - Users can delete their shell resources via the `/delete` endpoint.

---

## Installation

### 1. **Build the Docker Image**

```sh
cd ${MOUNT_PAHT}/kubernetes/install_k8s/cloud-shell/gok
./build.sh
./tag_push.sh
```
---

### 2. **Deploy to Kubernetes**

- Create a namespace (e.g., `cloudshell`):

  ```sh
  cd ${MOUNT_PATH}/kubernetes/install_k8s
  ./gok install cloudshell
  ```

- Deploy the backend (Flask app) and expose it (e.g., via a Deployment and Service).

- Configure NGINX Ingress with SSO (oauth2-proxy or similar) and TLS.

---

### 3. **OIDC/JWT Setup**

- The backend expects a JWT in the `Authorization` header or `X-Auth-Request-Access-Token` (for NGINX `auth_request`).
- The JWT should include `sub`, `preferred_username`, and `groups` claims.

---

### 4. **Ingress Example**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cloudshell
  namespace: cloudshell
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://cloudshell.gokcloud.com/shell/validate?uri=$request_uri"
    nginx.ingress.kubernetes.io/auth-signin: "https://kube.gokcloud.com/oauth2/start?rd=https://cloudshell.gokcloud.com/user/$user"
    nginx.ingress.kubernetes.io/auth-response-headers: "Authorization"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "gokselfsign-ca-cluster-issuer"
    nginx.ingress.kubernetes.io/rewrite-target: "/"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - cloudshell.gokcloud.com
      secretName: cloudshell-gokcloud-com
  rules:
    - host: cloudshell.gokcloud.com
      http:
        paths:
          - path: /user/(.*)
            pathType: Prefix
            backend:
              service:
                name: cloudshell
                port:
                  number: 8080
```

---

## API Endpoints

- `/`  
  Launch or redirect to the user's shell session.

- `/status/<username>`  
  Check if the user's pod is ready.

- `/delete`  
  Delete the user's pod, service, and ingress.

- `/validate`  
  Used by NGINX for SSO validation.

---

## WEB Endpoints

This application provides a cloud-based shell environment accessible via `https://cloudshell.gokcloud.com/shell`.

Once a user starts a container session, they are automatically redirected to a personalized URL:

`https://cloudshell.gokcloud.com/user/<username>`

where `<username>` is replaced with the authenticated user's identifier.

This setup enables secure, user-specific shell access within isolated containers.

## Environment Variables

- `KUBERNETES_SERVICE_HOST` (auto-set in-cluster)
- `NAMESPACE` (default: `cloudshell`)
- `TTYD_IMAGE` (default: `tsl0922/ttyd`)
- `TTYD_PORT` (default: `7681`)

---

## Security Notes

- **Pods run with the user's token**: Only allow trusted users.
- **Ingress is SSO-protected**: Do not expose without authentication.
- **Resource cleanup**: Users can delete their own resources via `/delete`.

---

## Development

- **Backend:** Flask app in `cloud-shell/gok/app.py`
- **Dockerfile:** Multi-stage build in `console/app/Dockerfile`

---

## Troubleshooting

- **Pod not starting:** Check logs for the init container and main container.
- **Ingress 403:** Ensure SSO and JWT claims are correct.
- **Tools missing:** Check the init container's install script.

---

## License

MIT or your organization’s license.

---

## Authors

- [Your Name/Team]