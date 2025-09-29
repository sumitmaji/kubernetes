# GOK-Agent System Comprehensive Documentation

## Overview

The GOK-Agent system is a distributed command execution platform for Kubernetes environments, consisting of two main components: the **Agent** and the **Controller**. This system enables secure, authenticated remote command execution on Kubernetes nodes through a web-based interface with real-time result streaming.

## Architecture Overview

```
Web UI (React) → Controller (Flask API) → RabbitMQ → Agent (Python Worker) → Host Commands
                     ↑                        ↓                    ↑
               OAuth2/OIDC Auth         Results Queue     Privileged Container
                     ↑                        ↓                    ↑
              Keycloak Integration     Real-time WebSocket    nsenter to Host
```

### System Components

1. **GOK-Agent** - Privileged container that executes commands on Kubernetes nodes
2. **GOK-Controller** - Web interface and API for command management
3. **RabbitMQ** - Message queue for command distribution and result collection
4. **Vault** - Secret management for API tokens and credentials
5. **Keycloak/OIDC** - Authentication and authorization

---

## Component 1: GOK-Agent

### Purpose
The GOK-Agent is a privileged Kubernetes pod that receives commands from RabbitMQ and executes them on the host system using namespace isolation bypass techniques.

### Key Features
- **Privileged Execution** - Runs commands directly on Kubernetes nodes
- **RBAC Integration** - Role-based command filtering
- **Real-time Streaming** - Live command output via RabbitMQ
- **Batch Processing** - Execute multiple commands in sequence
- **OAuth2 Token Validation** - JWT-based authentication
- **Host Namespace Access** - Uses `nsenter` for host command execution

### Architecture

#### Core Components
```python
# Main application components:
app.py              # Main agent application
batch_message.py    # Data structures for batch commands
requirements.txt    # Python dependencies
Dockerfile          # Container specification
chart/              # Helm deployment configuration
```

#### Authentication Methods
The agent supports dual authentication modes:

**1. Static Token RBAC (Simple)**
```python
TOKEN_GROUP_MAP = {
    "supersecrettoken": "administrators",
    "usertoken": "developers"
}

GROUP_COMMANDS = {
    "administrators": ["*"],           # All commands
    "developers": ["ls", "whoami", "uptime"]  # Limited commands
}
```

**2. OAuth2/JWT Validation (Production)**
- Validates JWT tokens against Keycloak OIDC provider
- Extracts user groups from token claims
- Maps groups to allowed command lists
- Supports JWKS key rotation

#### Command Execution Flow

**1. Message Reception**
```python
def on_message(ch, method, properties, body):
    msg = json.loads(body)
    token = msg.get('token') or msg.get('user_info', {}).get('id_token')
    commands = msg.get('commands', [])
    batch_id = msg.get('batch_id', 'single')
```

**2. Authorization Check**
```python
def is_command_allowed(group, command):
    cmd = command.split()[0]
    if group == "administrators":
        return True
    return group in GROUP_COMMANDS and cmd in GROUP_COMMANDS[group]
```

**3. Host Command Execution**
```python
# Environment setup + nsenter execution
setup = (
    "export MOUNT_PATH=/root && "
    "source /root/kubernetes/install_k8s/gok && "
    "source /root/kubernetes/install_k8s/util && "
)
nsenter_prefix = "nsenter --mount=/host/proc/1/ns/mnt --uts=/host/proc/1/ns/uts --ipc=/host/proc/1/ns/ipc --net=/host/proc/1/ns/net --pid=/host/proc/1/ns/pid --"
command_to_run = f"{nsenter_prefix} bash -c \"{setup}{command}\""
```

**4. Result Streaming**
```python
def stream_result(channel, batch_id, command_id, output):
    result_msg = {
        'batch_id': batch_id,
        'command_id': command_id,
        'output': output
    }
    channel.basic_publish(exchange='', routing_key=RESULTS_QUEUE, body=json.dumps(result_msg))
```

### API Specification

#### Message Format (Commands Queue)
```json
{
  "token": "jwt_token_or_static_token",
  "batch_id": "user-12345-67890",
  "commands": [
    {"command": "ls -la /", "command_id": 0},
    {"command": "uptime", "command_id": 1}
  ],
  "user_info": {
    "sub": "user-uuid",
    "name": "John Doe", 
    "groups": ["administrators"],
    "id_token": "jwt_token"
  }
}
```

#### Result Message Format (Results Queue)
```json
{
  "batch_id": "user-12345-67890",
  "command_id": 0,
  "output": "total 64\ndrwxr-xr-x  19 root root  4096 Oct  1 10:00 .\n..."
}
```

### Docker Configuration

#### Dockerfile Analysis
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY app.py requirements.txt ./

# Critical: Install nsenter for host namespace access
RUN apt-get update && apt-get install -y util-linux

RUN pip install --no-cache-dir -r requirements.txt
CMD ["python", "app.py"]
```

**Key Points**:
- **Base Image**: `python:3.11-slim` for minimal footprint
- **nsenter**: Essential tool for host namespace access (`util-linux` package)
- **Dependencies**: `pika` (RabbitMQ), `requests` (HTTP), `python-jose` (JWT)

#### Build Process
```bash
# From agent/build.sh
source config/config
source configuration  
docker build --build-arg LDAP_DOMAIN=$DOMAIN_NAME \
  --build-arg REGISTRY=$(fullRegistryUrl) \
  --build-arg LDAP_HOSTNAME=$LDAP_HOSTNAME \
  --build-arg BASE_DN=$DC \
  --build-arg LDAP_PASSWORD=sumit -t $IMAGE_NAME .
```

### Kubernetes Deployment

#### Helm Chart Structure
```
agent/chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration
└── templates/
    ├── deployment.yaml     # Pod specification
    └── serviceaccount.yaml # RBAC configuration
```

#### Critical Deployment Configuration
```yaml
# From deployment.yaml
spec:
  template:
    spec:
      hostPID: true                    # Access to host process namespace
      serviceAccountName: agent-backend-sa
      containers:
        - name: agent-backend
          securityContext:
            privileged: true           # Privileged container required
          volumeMounts:
          - name: host-root
            mountPath: /host
            mountPropagation: Bidirectional  # Bidirectional mount propagation
      volumes:
      - name: host-root
        hostPath:
          path: /                      # Mount entire host filesystem
          type: Directory
```

**Security Implications**:
- ⚠️ **Privileged Container**: Full access to host system
- ⚠️ **Host PID Namespace**: Can see all host processes  
- ⚠️ **Host Filesystem Mount**: Read/write access to entire host
- ⚠️ **nsenter Usage**: Bypass container isolation

#### Environment Configuration
```yaml
# From values.yaml
env:
  OAUTH_ISSUER: "https://keycloak.gokcloud.com/realms/GokDevelopers"
  OAUTH_CLIENT_ID: "gok-developers-client"  
  REQUIRED_ROLE: "administrators"
  RABBITMQ_HOST: "rabbitmq-0.rabbitmq-headless.rabbitmq.svc.cloud.uat"
```

---

## Component 2: GOK-Controller

### Purpose
The GOK-Controller provides a web-based interface for authenticated users to submit command batches and receive real-time results through WebSocket connections.

### Key Features
- **React Frontend** - Modern web UI for command submission
- **Flask Backend** - REST API with WebSocket support
- **OAuth2 Integration** - Keycloak OIDC authentication
- **Real-time Results** - Live command output via Socket.IO
- **Vault Integration** - Dynamic secret management
- **Audit Logging** - Comprehensive access logging

### Architecture

#### Multi-Stage Docker Build
```dockerfile
# Stage 1: Build React frontend
FROM node:20 AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
ENV NODE_OPTIONS=--openssl-legacy-provider
COPY frontend/ ./
RUN npm run build

# Stage 2: Prepare Python backend  
FROM python:3.11 AS backend-build
WORKDIR /app/backend
COPY backend/requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt
COPY backend/ ./

# Stage 3: Final runtime image
FROM python:3.11-slim
WORKDIR /app
COPY --from=backend-build /app/backend /app/backend
COPY --from=frontend-build /app/frontend/build /app/backend/static
RUN pip install -r backend/requirements.txt
EXPOSE 8080
CMD ["python", "backend/app.py"]
```

### Backend API Specification

#### Core Dependencies
```python
# From requirements.txt
flask              # Web framework
flask-socketio     # WebSocket support
pika              # RabbitMQ client
python-jose       # JWT validation
watchdog          # File system monitoring (Vault secrets)
requests          # HTTP client
werkzeug          # Security utilities
```

#### Authentication Endpoint
```python
@app.route("/logininfo")
@require_oauth()
def logininfo():
    return jsonify({
        "user": request.user.get("preferred_username"),
        "name": request.user.get("name"), 
        "userid": request.user.get("sub"),
        "groups": request.user.get("groups", []),
        "email": request.user.get("email"),
    })
```

**Request Format**:
```http
GET /logininfo
Authorization: Bearer <jwt_token>
```

**Response Format**:
```json
{
  "user": "john.doe@company.com",
  "name": "John Doe",
  "userid": "uuid-12345",
  "groups": ["administrators", "developers"],
  "email": "john.doe@company.com"
}
```

#### Command Batch Submission
```python
@app.route("/send-command-batch", methods=["POST"])
@require_oauth(REQUIRED_GROUP)
def send_command_batch():
    data = request.json or {}
    commands = data.get("commands", [])
    
    # Validate command format
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        return jsonify({"error": "Invalid commands format"}), 400
    
    # Create batch and publish to RabbitMQ
    user_info = {
        "sub": request.user.get("sub"),
        "name": request.user.get("name"),
        "groups": request.user.get("groups", []),
        "id_token": request.headers.get("Authorization").split(" ", 1)[1]
    }
    batch_id = publish_batch(commands, user_info)
    
    return jsonify({
        "msg": "Command batch accepted",
        "batch_id": batch_id,
        "issued_by": user_info["sub"],
        "groups": groups
    }), 200
```

**Request Format**:
```http
POST /send-command-batch
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "commands": ["ls -la", "uptime", "df -h"]
}
```

**Response Format**:
```json
{
  "msg": "Command batch accepted",
  "batch_id": "user-uuid-1234567890",
  "issued_by": "user-uuid",
  "groups": ["administrators"]
}
```

#### WebSocket Integration (Socket.IO)

**Client Connection**:
```javascript
// Join batch room to receive results
socket.emit('join', { batch_id: 'user-uuid-1234567890' });

// Listen for results
socket.on('result', (data) => {
  console.log(`Command ${data.command_id}: ${data.output}`);
});
```

**Server-side Result Broadcasting**:
```python
def rabbitmq_result_worker():
    # Consume results from RabbitMQ
    for method_frame, properties, body in channel.consume("results"):
        if body:
            msg = json.loads(body)
            batch_id = msg.get("batch_id")
            # Broadcast to all clients in batch room
            socketio.emit("result", msg, room=batch_id)
```

### Vault Integration

#### Secret Management
```python
# vault.py
def get_vault_secrets():
    secrets_path = os.environ.get("VAULT_SECRETS_PATH", "/vault/secrets/")
    secrets_file = os.path.join(secrets_path, "web-controller")
    with open(secrets_file, "r") as f:
        data = json.load(f)
    return data
```

#### Dynamic Secret Reloading
```python
class SecretReloadHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith("web-controller"):
            secrets = get_vault_secrets()
            self.app.config["API_TOKEN"] = secrets.get("api-token")
            global API_TOKEN
            API_TOKEN = secrets.get("api-token")
            print("Secrets reloaded from Vault!")
```

### Frontend Architecture

#### React Application Structure
```json
// package.json dependencies
{
  "react": "^18.0.0",
  "react-dom": "^18.0.0", 
  "socket.io-client": "^4.7.2",  // WebSocket communication
  "react-scripts": "^5.0.1",     // Build toolchain
  "react-router-dom": "^5.2.0",  // Routing
  "react-icons": "^4.11.0",      // UI icons
  "axios": "^0.21.1"             // HTTP client
}
```

#### Build Configuration
```json
// Build scripts
{
  "start": "NODE_OPTIONS=--openssl-legacy-provider react-scripts start",
  "build": "react-scripts build",  // Production build
  "test": "react-scripts test"
}
```

### Helm Chart Configuration

#### Service Configuration
```yaml
# From values.yaml
service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"   # Long-lived connections
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"   # Long uploads
    nginx.ingress.kubernetes.io/websocket-services: "web-controller"  # WebSocket support
  hosts:
    - host: web-controller.example.com
      paths:
        - path: /
          pathType: Prefix
```

#### Vault Integration
```yaml
# Vault agent injection annotations
vault:
  enabled: true
  agentInjector: true
  role: "web-controller"
  secretPath: "secret/web-controller"

# Deployment annotations (in template)
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "web-controller"
  vault.hashicorp.com/agent-inject-secret-web-controller: "secret/web-controller"
  vault.hashicorp.com/agent-inject-template-web-controller: |
    {{`{{- printf "{\"api-token\": \"{{ .Data.api-token }}\"}" }}`}}
```

---

## GOK Script Integration

### Installation Functions

#### Agent Installation: `gokAgentInstall()`

**Location**: Lines 2699-2714 in gok script

```bash
gokAgentInstall(){
  # 1. Build and push Docker image
  pushd ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/agent
  ./build.sh     # Build Docker image
  ./tag_push.sh  # Push to registry
  popd

  # 2. Create Kubernetes namespace
  kubectl create namespace gok-agent

  # 3. Create CA certificate ConfigMap
  kubectl create configmap ca-cert \
    --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt \
    -n gok-agent

  # 4. Install using Helm chart
  helm install gok-agent \
    ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/agent/chart \
    --namespace gok-agent
}
```

**Installation Process**:
1. **Image Build** - Creates privileged container with nsenter capability
2. **Registry Push** - Uploads to `registry.gokcloud.com/agent:latest`
3. **Namespace Creation** - Isolated namespace for agent deployment
4. **Certificate Setup** - CA certificate for OIDC validation
5. **Helm Deployment** - Deploys privileged DaemonSet/Deployment

#### Controller Installation: `gokControllerInstall()`

**Location**: Lines 2738-2767 in gok script

```bash
gokControllerInstall(){
  # 1. Build and push Docker image
  pushd ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/controller
  ./build.sh     # Multi-stage build (React + Flask)
  ./tag_push.sh  # Push to registry
  popd

  # 2. Create namespace
  kubectl create namespace gok-controller
  
  # 3. Setup Vault integration
  createVaultSecretStore \
    -p "secret/web-controller" \
    -r "web-controller" \
    -l "web-controller-policy" \
    -s "web-controller-provider" \
    -x "web-controller" \
    -n "gok-controller" \
    -k "api-token=adfasdfasdfasdfasd"
  
  # 4. Create CA certificate
  kubectl create configmap ca-cert \
    --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt \
    -n gok-controller

  # 5. Install using Helm
  helm install gok-controller \
    ${MOUNT_PATH}/kubernetes/install_k8s/gok-agent/controller/chart \
    --namespace gok-controller

  # 6. Configure ingress with SSL
  gok patch ingress web-controller gok-controller letsencrypt controller
  patchControllerWithOauth
}
```

**Installation Process**:
1. **Multi-stage Build** - React frontend + Flask backend in single image
2. **Registry Push** - Uploads to `registry.gokcloud.com/web-controller:latest`
3. **Namespace Setup** - Dedicated namespace for web interface
4. **Vault Configuration** - Creates secret store, role, and policy
5. **Certificate Management** - CA certificate for OIDC/HTTPS
6. **Helm Deployment** - Web application with Vault agent injection
7. **Ingress Configuration** - HTTPS endpoint with Let's Encrypt
8. **OAuth2 Integration** - Keycloak authentication setup

### Menu Integration

**Installation Commands**:
```bash
# Individual components
gok install gok-agent      # Install agent only
gok install gok-controller # Install controller only

# Combined installation  
gok install controller     # Installs both agent + controller
```

**Menu Structure** (lines 4810-4815):
```bash
elif [ "$COMPONENT" == "gok-agent" ]; then
  gokAgentInstall
elif [ "$COMPONENT" == "gok-controller" ]; then
  gokControllerInstall
elif [ "$COMPONENT" == "controller" ]; then
  gok install gok-agent      # Install agent first
  gok install gok-controller # Then controller
```

### Dependencies

**Required Components**:
- **RabbitMQ** - Message queue service (`gok install rabbitmq`)
- **Vault** - Secret management (`gok install vault`)
- **Keycloak** - OIDC provider (`gok install keycloak`)
- **cert-manager** - SSL certificates (`gok install cert-manager`)
- **nginx-ingress** - Ingress controller (`gok install ingress`)

**Installation Order**:
1. Base infrastructure (ingress, cert-manager)
2. Authentication (Keycloak, oauth2-proxy)  
3. Storage & messaging (Vault, RabbitMQ)
4. GOK components (agent, controller)

---

## Security Architecture

### Authentication & Authorization

#### OIDC Integration Flow
```
User → Browser → Controller → Keycloak → JWT Token → Controller → RabbitMQ → Agent
  ↑                   ↓           ↑         ↓          ↓           ↓        ↓
Login    React UI   Flask API   Validate  Groups   Commands   Receive  Execute
```

#### JWT Token Validation
```python
# Controller and Agent both validate JWT tokens
def verify_id_token(token):
    unverified_header = jose_jwt.get_unverified_header(token)
    key = next(k for k in JWKS["keys"] if k["kid"] == unverified_header["kid"])
    payload = jose_jwt.decode(
        token, key, 
        algorithms=["RS256"], 
        audience=OAUTH_CLIENT_ID, 
        issuer=OAUTH_ISSUER
    )
    return payload
```

#### RBAC Implementation
```python
# Group-based command authorization
GROUP_COMMANDS = {
    "administrators": ["*"],                    # Unrestricted access
    "developers": ["ls", "whoami", "uptime"],  # Limited commands
    "operators": ["kubectl", "docker", "systemctl"]  # Infrastructure commands
}

def is_command_allowed(group, command):
    cmd = command.split()[0]  # Extract base command
    if group == "administrators":
        return True
    return group in GROUP_COMMANDS and cmd in GROUP_COMMANDS[group]
```

### Security Risks & Mitigations

#### High-Risk Components
⚠️ **Agent Container**:
- **Risk**: Privileged container with host access
- **Mitigation**: RBAC-based command filtering, JWT validation
- **Impact**: Complete host compromise if exploited

⚠️ **nsenter Usage**:
- **Risk**: Bypasses container isolation
- **Mitigation**: Command allowlists per user group
- **Impact**: Direct host system access

⚠️ **Host Filesystem Mount**:
- **Risk**: Full filesystem read/write access
- **Mitigation**: Restricted to administrator group
- **Impact**: Data exfiltration, system modification

#### Medium-Risk Components
⚠️ **RabbitMQ Communication**:
- **Risk**: Unencrypted internal messaging
- **Mitigation**: Network policies, service mesh
- **Impact**: Command interception, privilege escalation

⚠️ **Vault Secret Management**:
- **Risk**: API token exposure in memory/logs
- **Mitigation**: Dynamic secret rotation, secure logging
- **Impact**: Unauthorized API access

#### Recommended Security Enhancements
1. **Network Segmentation** - Isolate agent nodes from general cluster
2. **Command Auditing** - Log all executed commands with user attribution
3. **Resource Limits** - Restrict CPU/memory for agent containers
4. **Image Scanning** - Regular security scans of base images
5. **Secret Rotation** - Automated rotation of Vault secrets
6. **Network Policies** - Restrict inter-pod communication

---

## Operational Procedures

### Deployment Verification

#### Agent Health Check
```bash
# Verify agent deployment
kubectl get pods -n gok-agent
kubectl logs -f deployment/agent-backend -n gok-agent

# Check RabbitMQ connectivity
kubectl exec -it deployment/agent-backend -n gok-agent -- python -c "
import pika
credentials = pika.PlainCredentials('rabbitmq', 'rabbitmq')
connection = pika.BlockingConnection(pika.ConnectionParameters('rabbitmq-host', credentials=credentials))
print('RabbitMQ connection: OK')
"
```

#### Controller Health Check  
```bash
# Verify controller deployment
kubectl get pods -n gok-controller
kubectl logs -f deployment/web-controller -n gok-controller

# Test web interface
curl -k https://controller.$(kubectl get cm cluster-info -o jsonpath='{.data.domain}')

# Verify Vault integration
kubectl exec -it deployment/web-controller -n gok-controller -- ls -la /vault/secrets/
```

### Command Execution Testing

#### Basic Functionality Test
```bash
# 1. Authenticate and get JWT token
TOKEN=$(curl -sk -X POST https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=gok-developers-client&username=admin&password=admin" \
  | jq -r '.access_token')

# 2. Submit command batch
BATCH_ID=$(curl -sk -X POST https://controller.gokcloud.com/send-command-batch \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"commands": ["hostname", "uptime"]}' \
  | jq -r '.batch_id')

# 3. Monitor results via WebSocket (manual test)
```

#### RBAC Testing
```bash
# Test developer user (limited commands)
curl -sk -X POST https://controller.gokcloud.com/send-command-batch \
  -H "Authorization: Bearer $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"commands": ["ls /"]}'     # Should succeed

curl -sk -X POST https://controller.gokcloud.com/send-command-batch \
  -H "Authorization: Bearer $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"commands": ["rm -rf /"]}'  # Should fail with authorization error
```

### Monitoring & Alerting

#### Key Metrics
- **Agent Availability** - Pod readiness and RabbitMQ connectivity
- **Command Execution Rate** - Successful vs failed command ratio
- **Authentication Failures** - Invalid JWT tokens or insufficient permissions
- **Queue Depth** - RabbitMQ command and result queue lengths
- **Resource Usage** - CPU/memory consumption of privileged containers

#### Log Analysis
```bash
# Agent logs
kubectl logs -f deployment/agent-backend -n gok-agent | grep "ERROR\|WARNING"

# Controller logs  
kubectl logs -f deployment/web-controller -n gok-controller | grep "authentication\|authorization"

# RabbitMQ logs
kubectl logs -f statefulset/rabbitmq -n rabbitmq | grep "connection\|queue"
```

### Troubleshooting Guide

#### Common Issues

**1. Agent Cannot Connect to RabbitMQ**
```bash
# Symptoms: Agent logs show "connection refused" 
# Check RabbitMQ service
kubectl get svc -n rabbitmq
kubectl get pods -n rabbitmq

# Verify network connectivity
kubectl exec -it deployment/agent-backend -n gok-agent -- nslookup rabbitmq-0.rabbitmq-headless.rabbitmq.svc.cluster.local
```

**2. Controller Authentication Failures**
```bash
# Symptoms: "Invalid token" errors in controller logs
# Verify Keycloak connectivity
kubectl exec -it deployment/web-controller -n gok-controller -- curl -k https://keycloak.gokcloud.com/realms/GokDevelopers/.well-known/openid-configuration

# Check OIDC configuration
kubectl get configmap -n gok-controller -o yaml
```

**3. Commands Not Executing on Host**
```bash
# Symptoms: Commands fail with "permission denied"
# Verify privileged container
kubectl describe pod -n gok-agent | grep -A5 "securityContext"

# Check host mount
kubectl exec -it deployment/agent-backend -n gok-agent -- ls -la /host/
```

**4. Vault Secret Access Issues**
```bash
# Symptoms: "Failed to load secrets" in controller logs
# Check Vault agent injection
kubectl describe pod -n gok-controller | grep -A10 "vault.hashicorp.com"

# Verify secret file
kubectl exec -it deployment/web-controller -n gok-controller -- cat /vault/secrets/web-controller
```

### Maintenance Procedures

#### Image Updates
```bash
# Agent image update
cd $MOUNT_PATH/kubernetes/install_k8s/gok-agent/agent
./build.sh && ./tag_push.sh
kubectl rollout restart deployment/agent-backend -n gok-agent

# Controller image update
cd $MOUNT_PATH/kubernetes/install_k8s/gok-agent/controller  
./build.sh && ./tag_push.sh
kubectl rollout restart deployment/web-controller -n gok-controller
```

#### Configuration Updates
```bash
# Update RBAC rules
kubectl edit configmap agent-config -n gok-agent

# Update OIDC settings
helm upgrade gok-controller ./chart --namespace gok-controller \
  --set oidc.issuer=https://new-keycloak.domain.com/realms/NewRealm
```

#### Clean Shutdown
```bash
# Graceful shutdown order
kubectl scale deployment web-controller --replicas=0 -n gok-controller
kubectl scale deployment agent-backend --replicas=0 -n gok-agent

# Complete removal
gok reset controller  # If reset function exists
helm uninstall gok-controller -n gok-controller
helm uninstall gok-agent -n gok-agent
kubectl delete namespace gok-controller gok-agent
```

---

## Best Practices & Recommendations

### Security Best Practices
1. **Principle of Least Privilege** - Restrict command access by user group
2. **Regular Security Audits** - Review RBAC policies and command logs
3. **Image Hardening** - Use minimal base images and regular security patches
4. **Network Isolation** - Implement network policies to restrict pod communication
5. **Secret Management** - Use Vault for all sensitive configuration data

### Operational Best Practices
1. **Monitoring Integration** - Implement comprehensive monitoring and alerting
2. **Backup Procedures** - Regular backups of RBAC configurations and audit logs
3. **Incident Response** - Define procedures for security incidents and system failures
4. **Change Management** - Version control all configuration changes
5. **Documentation** - Maintain up-to-date operational runbooks

### Performance Optimization
1. **Resource Limits** - Set appropriate CPU/memory limits for all components
2. **Queue Management** - Monitor RabbitMQ queue depths and implement alerts
3. **Connection Pooling** - Optimize database and message queue connections
4. **Caching Strategies** - Cache JWKS keys and user permissions where appropriate
5. **Load Testing** - Regular performance testing under expected load conditions

This comprehensive documentation provides complete coverage of the GOK-Agent system architecture, implementation details, security considerations, and operational procedures for both components.