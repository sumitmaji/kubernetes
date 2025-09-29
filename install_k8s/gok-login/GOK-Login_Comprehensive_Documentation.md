# GOK-Login Service Comprehensive Documentation

## Overview

The `gok-login` service is a Flask-based REST API that provides Kubernetes authentication through Keycloak OIDC integration. It allows users to authenticate with their Keycloak credentials and receive access tokens that can be used to access Kubernetes clusters with proper RBAC permissions.

## Architecture Overview

```
User → login.sh → gok-login API → Keycloak → Access Token → kubectl
```

### Key Components
1. **app.py** - Flask REST API server
2. **login.sh** - Client-side authentication script  
3. **Helm Chart** - Kubernetes deployment configuration
4. **Docker Container** - Containerized Flask application
5. **Ingress Configuration** - HTTPS endpoint exposure

---

## Component Analysis

### 1. app.py - Flask Authentication API

#### Purpose
Provides a REST API endpoint that accepts username/password credentials and exchanges them for Keycloak access tokens.

#### Key Features
- **Endpoint**: `POST /login`
- **Authentication Method**: OAuth2 Resource Owner Password Credentials Grant
- **Keycloak Integration**: Direct integration with Keycloak token endpoint
- **Security**: Supports both public and confidential OIDC clients

#### API Specification

**Endpoint**: `POST /login`

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "username": "user@domain.com",
  "password": "userpassword"
}
```

**Success Response (200)**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "not-before-policy": 0,
  "session_state": "uuid-session-id",
  "scope": "untrusted-audience profile email"
}
```

**Error Response (400/401)**:
```json
{
  "error": "Authentication failed",
  "details": "Invalid user credentials"
}
```

#### Environment Variables
| Variable | Description | Default Value |
|----------|-------------|---------------|
| `KEYCLOAK_URL` | Keycloak token endpoint URL | `https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/token` |
| `CLIENT_ID` | OIDC client identifier | `gok-developers-client` |
| `CLIENT_SECRET` | OIDC client secret (for confidential clients) | `""` (empty for public clients) |

#### Code Structure
```python
# Key components of app.py:

@app.route('/login', methods=['POST'])
def login():
    # 1. Extract username/password from request
    # 2. Prepare OAuth2 payload with grant_type=password
    # 3. Add client credentials if CLIENT_SECRET is provided
    # 4. Send POST request to Keycloak token endpoint
    # 5. Return token response or error details
```

#### Grant Type Details
Uses **Resource Owner Password Credentials Grant** (RFC 6749):
- Direct user credential exchange for access tokens
- Suitable for trusted first-party applications
- Supports both public and confidential OIDC clients
- Includes `scope: untrusted-audience` for cross-client token usage

---

### 2. login.sh - Client Authentication Script

#### Purpose
Command-line script that interacts with the gok-login API to authenticate users and automatically configure kubectl with the received access token.

#### Usage
```bash
# Basic usage
./login.sh <username> <password>

# With verbose output
VERBOSE=1 ./login.sh <username> <password>

# Examples
./login.sh john.doe@company.com mypassword
VERBOSE=1 ./login.sh admin@gokcloud.com secretpass
```

#### Key Features
- **Automatic kubeconfig generation** - Creates `~/.kube/config` with access token
- **SSL verification bypass** - Uses `-k` flag for self-signed certificates
- **Verbose mode** - Detailed curl output for debugging
- **Error handling** - Validates token extraction and provides clear error messages
- **User namespace** - Sets default namespace to username for RBAC isolation

#### Generated Kubeconfig Structure
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://10.0.0.244:6443
    insecure-skip-tls-verify: true
  name: k8s
users:
- name: user
  user:
    token: <ACCESS_TOKEN_FROM_KEYCLOAK>
contexts:
- context:
    cluster: k8s
    user: user
    namespace: <USERNAME>
  name: k8s
current-context: k8s
```

#### Security Considerations
- **Credentials in command line**: Username/password visible in process list
- **Token storage**: Access token stored in plaintext kubeconfig
- **SSL verification**: Disabled by default (`insecure-skip-tls-verify: true`)
- **Namespace isolation**: Each user gets their own default namespace

#### Script Flow
1. **Input validation** - Checks for username and password arguments
2. **API call** - Makes POST request to gok-login service
3. **Token extraction** - Parses access_token from JSON response
4. **Kubeconfig creation** - Generates kubectl configuration file
5. **Success confirmation** - Reports successful kubeconfig creation

---

### 3. Helm Chart Configuration

#### Chart Structure
```
chart/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default configuration values
└── templates/
    ├── deployment.yaml        # Pod deployment specification
    ├── service.yaml           # Service exposure
    ├── ingress.yaml           # HTTPS ingress configuration
    ├── oidc-configmap.yaml    # OIDC configuration
    ├── oidc-secret.yaml       # OIDC secrets (unused)
    └── _helpers.tpl           # Template helpers
```

#### Key Configuration Values (values.yaml)

**Application Configuration**:
```yaml
replicaCount: 1                # Single replica deployment

image:
  repository: registry.gokcloud.com/gok-login
  tag: latest
  pullPolicy: Always            # Always pull latest image
```

**Service Configuration**:
```yaml
service:
  type: ClusterIP             # Internal cluster service
  port: 5000                  # Service port (matches Flask app)
```

**Ingress Configuration**:
```yaml
ingress:
  enabled: true
  host: gok-login.gokcloud.com  # External domain
  annotations: {}               # Additional ingress annotations
```

**OIDC Integration**:
```yaml
oidc:
  keycloakUrl: "https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/token"
  clientId: "gok-developers-client"
  clientSecret: ""              # Injected during deployment

env:
  OAUTH_ISSUER: "https://keycloak.gokcloud.com/realms/GokDevelopers"
  OAUTH_CLIENT_ID: "gok-developers-client"
```

#### Deployment Specifications

**Pod Configuration**:
```yaml
# From deployment.yaml template:
containers:
  - name: gok-login
    image: "registry.gokcloud.com/gok-login:latest"
    imagePullPolicy: Always
    ports:
      - containerPort: 8080      # Note: Mismatch with Flask port 5000
    env:
      - name: REQUESTS_CA_BUNDLE
        value: /usr/local/share/ca-certificates/issuer.crt
      - name: KEYCLOAK_URL
        valueFrom:
          configMapKeyRef:
            name: oidc
            key: KEYCLOAK_URL
```

**Port Configuration Issue**:
- **Deployment**: `containerPort: 8080`
- **Service**: `targetPort: 5000`
- **Flask App**: Runs on port `5000`
- **Fix Needed**: Deployment should use `containerPort: 5000`

---

### 4. Network Configuration

#### Port Mappings
| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| **Flask App** | 5000 | HTTP | Application server |
| **Service** | 5000 | HTTP | Kubernetes service |
| **Container** | 8080 ❌ | HTTP | **Misconfigured** - should be 5000 |
| **Ingress** | 443 | HTTPS | External access |

#### Ingress Path Configuration
```yaml
# From ingress.yaml:
spec:
  ingressClassName: nginx
  rules:
    - host: gok-login.gokcloud.com
      http:
        paths:
          - path: /login              # Only /login endpoint exposed
            pathType: ImplementationSpecific
            backend:
              service:
                name: gok-login
                port:
                  number: 5000
```

#### SSL/TLS Configuration
- **Certificate Management**: Let's Encrypt via cert-manager
- **TLS Termination**: At ingress controller (nginx)
- **Backend Communication**: HTTP (internal cluster traffic)
- **Client Verification**: Bypassed in login.sh script (`curl -k`)

---

### 5. Integration with GOK Script

#### Installation Function: `gokLoginInst()`

**Location in gok script**: Lines 3404-3434

**Installation Process**:
```bash
gokLoginInst() {
  # 1. Build and push Docker image
  pushd ${MOUNT_PATH}/kubernetes/install_k8s/gok-login
  chmod +x build.sh tag_push.sh
  ./build.sh                    # Build Docker image
  ./tag_push.sh                 # Push to registry
  popd

  # 2. Create Kubernetes namespace
  kubectl create namespace gok-login

  # 3. Create CA certificate ConfigMap
  kubectl create configmap ca-cert \
    --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt \
    -n gok-login

  # 4. Install using Helm chart
  helm install gok-login ${MOUNT_PATH}/kubernetes/install_k8s/gok-login/chart \
    -n gok-login \
    --set oidc.clientSecret="$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_SECRET)"

  # 5. Configure ingress with Let's Encrypt
  gok patch ingress gok-login-gok-login gok-login letsencrypt gok-login

  # 6. Wait for deployment readiness
  kubectl --namespace gok-login wait --for=condition=Ready pods --all --timeout=120s
}
```

#### Usage in GOK Menu System
**Command**: `gok install gok-login`
**Menu Location**: Main installation menu (line 4823)

#### Dependencies
- **Docker registry** access (registry.gokcloud.com)
- **Helm** installed and configured
- **cert-manager** for SSL certificate management
- **nginx-ingress-controller** for ingress handling
- **oauth-secrets** in kube-system namespace

---

## User Guide

### Prerequisites
1. **Kubernetes cluster** with gok-login service installed
2. **Network access** to `gok-login.gokcloud.com`
3. **Valid Keycloak credentials** in GokDevelopers realm
4. **kubectl** installed locally
5. **Bash shell** (for login.sh script)

### Installation Steps

#### 1. Install gok-login Service
```bash
# Using gok script
./gok install gok-login

# Manual verification
kubectl get pods -n gok-login
kubectl get ingress -n gok-login
```

#### 2. Verify Service Accessibility
```bash
# Check ingress
curl -k https://gok-login.gokcloud.com/login

# Should return: 405 Method Not Allowed (GET not supported)
```

#### 3. Test Authentication
```bash
# Download login script
wget https://raw.githubusercontent.com/sumitmaji/kubernetes/feature-12/install_k8s/gok-login/login.sh
chmod +x login.sh

# Test login
./login.sh your-username@domain.com your-password
```

### Usage Examples

#### Basic Authentication
```bash
# Standard login
./login.sh john.doe@company.com mypassword

# Expected output:
# API URL: https://gok-login.gokcloud.com/login
# Username: john.doe@company.com
# Password: [hidden]
# access_token extracted.
# Kubeconfig created at /home/john/.kube/config
```

#### Debugging Authentication Issues
```bash
# Enable verbose mode for troubleshooting
VERBOSE=1 ./login.sh john.doe@company.com mypassword

# This will show detailed curl output including:
# - HTTP request headers and body
# - TLS handshake details
# - Complete HTTP response
```

#### Verify Kubernetes Access
```bash
# After successful login, test kubectl
kubectl get pods                    # List pods in user namespace
kubectl get namespaces             # List accessible namespaces
kubectl auth can-i get pods        # Check permissions
kubectl config current-context     # Verify active context
```

#### Multiple User Management
```bash
# Each user gets their own namespace and context
./login.sh user1@company.com pass1
kubectl config rename-context k8s user1-context

./login.sh user2@company.com pass2  
kubectl config rename-context k8s user2-context

# Switch between contexts
kubectl config use-context user1-context
kubectl config use-context user2-context
```

### Advanced Usage

#### Custom API Endpoint
```bash
# Override default API URL
API_URL="https://custom-gok-login.domain.com/login" ./login.sh username password
```

#### Token Extraction for Automation
```bash
#!/bin/bash
# Extract token for use in scripts
API_URL="https://gok-login.gokcloud.com/login"
RESPONSE=$(curl -sk -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$1\", \"password\": \"$2\"}")

TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
echo "Access Token: $TOKEN"
```

#### Programmatic Authentication
```python
# Python example
import requests
import json

def authenticate(username, password):
    url = "https://gok-login.gokcloud.com/login"
    payload = {"username": username, "password": password}
    
    response = requests.post(url, json=payload, verify=False)
    
    if response.status_code == 200:
        token_data = response.json()
        return token_data['access_token']
    else:
        raise Exception(f"Authentication failed: {response.text}")

# Usage
try:
    token = authenticate("user@domain.com", "password")
    print(f"Access token: {token}")
except Exception as e:
    print(f"Error: {e}")
```

---

## Security Considerations

### Authentication Security

#### Strengths
- **OAuth2 standard compliance** - Uses established authentication protocol
- **Token-based access** - No persistent password storage in kubeconfig
- **Namespace isolation** - Users default to their own namespace
- **HTTPS communication** - Encrypted in transit (except internal cluster)

#### Security Risks
- **Password in command line** - Visible in process list and shell history
- **Token in plaintext** - Access token stored unencrypted in kubeconfig
- **SSL verification disabled** - Man-in-the-middle attack vulnerability
- **Public password grant** - Not recommended for production OAuth2 flows

#### Recommended Improvements
1. **Interactive password prompt** instead of command-line argument
2. **Token encryption** in kubeconfig using kubectl credential plugins
3. **Certificate validation** with proper CA trust
4. **Authorization code flow** instead of password grant
5. **Token refresh mechanism** for long-running sessions

### Network Security

#### Current Configuration
```yaml
# Ingress only exposes /login endpoint
paths:
  - path: /login
    pathType: ImplementationSpecific
```

#### Security Measures
- **Path restriction** - Only /login endpoint exposed externally
- **TLS termination** - HTTPS encryption for external access  
- **Internal communication** - HTTP within cluster (acceptable)
- **Network policies** - Could be implemented for additional isolation

### RBAC Integration

#### User Authorization
The service provides authentication only - authorization is handled by:
1. **Kubernetes RBAC** - Based on token claims and user identity
2. **Namespace isolation** - Default namespace set to username
3. **Keycloak groups** - Can be mapped to Kubernetes roles

#### Token Claims Structure
```json
{
  "sub": "user-uuid",
  "preferred_username": "john.doe@company.com",
  "email": "john.doe@company.com",
  "groups": ["developers", "users"],
  "realm_access": {
    "roles": ["user", "developer"]
  },
  "resource_access": {
    "gok-developers-client": {
      "roles": ["user"]
    }
  }
}
```

---

## Troubleshooting Guide

### Common Issues

#### 1. Authentication Fails (401 Unauthorized)
**Symptoms**:
```bash
./login.sh user pass
# Error: access_token not found in response.
```

**Diagnosis**:
```bash
# Enable verbose mode to see actual response
VERBOSE=1 ./login.sh user pass

# Check Keycloak connectivity
curl -k https://keycloak.gokcloud.com/realms/GokDevelopers/.well-known/openid_configuration
```

**Common Causes**:
- Invalid username/password
- Keycloak service unavailable  
- OIDC client misconfiguration
- User not in correct realm

**Solutions**:
- Verify credentials in Keycloak admin console
- Check Keycloak service status: `kubectl get pods -n keycloak`
- Validate OIDC client configuration
- Ensure user exists in GokDevelopers realm

#### 2. Service Unavailable (503/404)
**Symptoms**:
```bash
curl -k https://gok-login.gokcloud.com/login
# curl: (7) Failed to connect to gok-login.gokcloud.com
```

**Diagnosis**:
```bash
# Check service status
kubectl get pods -n gok-login
kubectl get service -n gok-login  
kubectl get ingress -n gok-login

# Check ingress controller
kubectl get pods -n ingress-nginx
```

**Solutions**:
- Restart gok-login deployment: `kubectl rollout restart deployment/gok-login-gok-login -n gok-login`
- Check ingress controller logs
- Verify DNS resolution for gok-login.gokcloud.com
- Ensure Let's Encrypt certificate is valid

#### 3. Port Configuration Mismatch
**Symptoms**:
```bash
# Service unreachable even though pods are running
kubectl get endpoints -n gok-login
# No endpoints shown
```

**Diagnosis**:
```bash
# Check port configuration
kubectl describe deployment gok-login-gok-login -n gok-login
kubectl describe service gok-login-gok-login -n gok-login
```

**Issue**: Deployment uses `containerPort: 8080` but service expects `targetPort: 5000`

**Solution**:
```bash
# Fix deployment port
kubectl patch deployment gok-login-gok-login -n gok-login -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "gok-login",
            "ports": [
              {
                "containerPort": 5000
              }
            ]
          }
        ]
      }
    }
  }
}'
```

#### 4. SSL Certificate Issues
**Symptoms**:
```bash
curl https://gok-login.gokcloud.com/login
# curl: (60) SSL certificate problem: self signed certificate
```

**Diagnosis**:
```bash
# Check certificate status
kubectl describe certificate -n gok-login
kubectl get certificaterequests -n gok-login

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

**Solutions**:
- Wait for Let's Encrypt certificate issuance (can take 2-10 minutes)
- Check DNS propagation for gok-login.gokcloud.com
- Verify cert-manager is properly configured
- Use `-k` flag in curl for testing (not production)

#### 5. Kubeconfig Access Issues
**Symptoms**:
```bash
kubectl get pods
# error: You must be logged in to the server (Unauthorized)
```

**Diagnosis**:
```bash
# Check kubeconfig contents
cat ~/.kube/config

# Verify token is present
kubectl config view --raw

# Test token directly
kubectl --token="YOUR_TOKEN" get pods
```

**Solutions**:
- Re-run login.sh to refresh token
- Check token expiration (typically 5-15 minutes)
- Verify Kubernetes API server is accessible
- Check user permissions with `kubectl auth can-i --list`

### Debugging Commands

#### Service Health Check
```bash
# Complete service health verification
kubectl get all -n gok-login
kubectl describe ingress gok-login-gok-login -n gok-login
kubectl logs deployment/gok-login-gok-login -n gok-login
```

#### Network Connectivity Test
```bash
# Test internal connectivity
kubectl run test-pod --image=curlimages/curl -it --rm -- \
  curl http://gok-login-gok-login.gok-login.svc.cluster.local:5000/login

# Test external connectivity  
nslookup gok-login.gokcloud.com
telnet gok-login.gokcloud.com 443
```

#### Configuration Validation
```bash
# Check OIDC configuration
kubectl get configmap oidc -n gok-login -o yaml

# Verify secrets
kubectl get secrets -n gok-login
kubectl describe secret oauth-secrets -n kube-system
```

---

## Monitoring and Maintenance

### Health Monitoring
```bash
# Basic health checks
kubectl get pods -n gok-login -w
kubectl top pods -n gok-login

# Service endpoint monitoring
curl -f -k https://gok-login.gokcloud.com/login || echo "Service down"
```

### Log Analysis
```bash
# Application logs
kubectl logs -f deployment/gok-login-gok-login -n gok-login

# Ingress logs
kubectl logs -f -n ingress-nginx deployment/ingress-nginx-controller
```

### Performance Metrics
```bash
# Pod resource usage
kubectl top pod -n gok-login

# Service response time testing
time curl -sk -X POST https://gok-login.gokcloud.com/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

### Maintenance Tasks

#### Image Updates
```bash
# Build and deploy new image
cd /path/to/gok-login
./build.sh
./tag_push.sh

# Update deployment
kubectl rollout restart deployment/gok-login-gok-login -n gok-login
kubectl rollout status deployment/gok-login-gok-login -n gok-login
```

#### Configuration Updates
```bash
# Update OIDC settings
kubectl patch configmap oidc -n gok-login -p '
{
  "data": {
    "KEYCLOAK_URL": "https://new-keycloak.domain.com/realms/NewRealm/protocol/openid-connect/token"
  }
}'

# Restart to apply changes
kubectl rollout restart deployment/gok-login-gok-login -n gok-login
```

#### Cleanup and Reset
```bash
# Complete service removal
helm uninstall gok-login -n gok-login
kubectl delete namespace gok-login

# Reinstall
gok install gok-login
```

This comprehensive documentation covers all aspects of the gok-login service, from technical implementation details to practical usage guidance and troubleshooting procedures.