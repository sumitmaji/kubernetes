# HashiCorp Vault Integration Guide

This guide provides comprehensive documentation for the three Vault integration test scripts that demonstrate different methods of accessing secrets from HashiCorp Vault in Kubernetes environments.

## 📋 Overview

The three test scripts demonstrate the primary methods for integrating applications with HashiCorp Vault:

| Script | Method | Use Case | Best For |
|--------|--------|----------|----------|
| `test_vault_agent_injector.sh` | Sidecar Injection | Automatic secret injection | Legacy apps, simple integration |
| `test_vault_csi.sh` | Volume Mounting | File-based secret access | Cloud-native apps, high security |
| `test_vault_api.sh` | Direct API Calls | Programmatic access | Microservices, dynamic secrets |

---

## 🔐 Authentication & Authorization Flow

All three methods use **Kubernetes Service Account Token Authentication** to Vault:

1. **Service Account** → JWT Token (mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`)
2. **JWT Token** → Vault Authentication (`/v1/auth/kubernetes/login`)
3. **Vault Token** → Secret Access (with policy-based permissions)

---

## 🧪 Test Script 1: Vault Agent Injector (`test_vault_agent_injector.sh`)

### 🎯 Purpose
Tests HashiCorp Vault Agent Injector for **automatic sidecar-based secret injection** into application pods.

### 🏗️ Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │    │  Vault Agent     │    │  HashiCorp      │
│   Container     │    │  Sidecar         │    │  Vault          │
│                 │    │                  │    │                 │
│  Reads secrets  │◄───┤ • Authenticates  │◄───┤ • Stores secrets│  
│  from files     │    │ • Fetches secrets│    │ • Validates JWT │
│  in /vault/     │    │ • Renders files  │    │ • Issues tokens │
│  secrets/       │    │ • Manages tokens │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🔑 Vault Resources Created

#### 1. **Test Secret** (`secret/agent-test`)
```bash
# Complex test data structure
vault kv put secret/agent-test \
    username="agent-test-user" \
    password="agent-test-password-456" \
    database_url="postgresql://agent-test:secret@db:5432/testdb" \
    api_token="agent-test-token-xyz789" \
    config_json='{"enabled":true,"timeout":45}' \
    ssl_cert="-----BEGIN CERTIFICATE-----..." \
    environment="production" \
    service_port="8080" \
    debug_mode="false"
```

#### 2. **Vault Policy** (`agent-test-policy`)
```hcl
# Read access to test secret
path "secret/data/agent-test" {
  capabilities = ["read"]
}

# List capability for secret discovery
path "secret/metadata/agent-test" {
  capabilities = ["list", "read"]
}

# Token self-lookup for validation
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

#### 3. **Kubernetes Auth Role** (`agent-test-role`)
```bash
vault write auth/kubernetes/role/agent-test-role \
    bound_service_account_names="agent-test-sa" \
    bound_service_account_namespaces="default" \
    policies="agent-test-policy" \
    ttl=24h
```

### 🚀 Kubernetes Resources

#### 1. **Service Account** (`agent-test-sa`)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: agent-test-sa
  namespace: default
```

#### 2. **Test Pod with Vault Annotations**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-agent-test-pod
  annotations:
    # Enable Vault Agent Injector
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "agent-test-role"
    
    # Secret injection configurations
    vault.hashicorp.com/agent-inject-secret-credentials: "secret/agent-test"
    vault.hashicorp.com/agent-inject-template-credentials: |
      {{- with secret "secret/agent-test" -}}
      USERNAME="{{ .Data.data.username }}"
      PASSWORD="{{ .Data.data.password }}"
      DATABASE_URL="{{ .Data.data.database_url }}"
      API_TOKEN="{{ .Data.data.api_token }}"
      {{- end }}
      
    # Individual secret files
    vault.hashicorp.com/agent-inject-secret-config: "secret/agent-test"
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/agent-test" -}}
      {{ .Data.data.config_json }}
      {{- end }}
spec:
  serviceAccountName: agent-test-sa
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
```

### 📁 Secret File Structure
After injection, secrets are available at:
```
/vault/secrets/
├── credentials          # Environment-style variables
├── config              # JSON configuration
├── username            # Individual secret values
├── password
├── database_url
├── api_token
├── ssl_cert
├── environment
├── service_port
└── debug_mode
```

### ⚙️ Key Configuration Requirements

1. **Vault Agent Injector Installed**:
   ```bash
   helm repo add hashicorp https://helm.releases.hashicorp.com
   helm install vault hashicorp/vault --set "injector.enabled=true"
   ```

2. **Kubernetes Auth Method Enabled**:
   ```bash
   vault auth enable kubernetes
   vault write auth/kubernetes/config \
       token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
       kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
       kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
   ```

3. **Pod Annotations**: Required for Vault Agent Injector to activate
4. **Service Account**: Must match the role binding
5. **Network Connectivity**: Pods must reach Vault service

### 📊 Test Results (13 Tests)
- ✅ **Infrastructure**: Dependencies, Vault login
- ✅ **Vault Setup**: Secret creation, policy, role configuration  
- ✅ **Kubernetes**: Service account, pod creation, readiness
- ✅ **Agent Injection**: Sidecar deployment, secret rendering
- ✅ **File Validation**: All 9 secret files created and accessible

---

## 💾 Test Script 2: Vault CSI Driver (`test_vault_csi.sh`)

### 🎯 Purpose
Tests **Secrets Store CSI Driver** with Vault provider for **volume-based secret mounting** into pods.

### 🏗️ Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │    │  CSI Driver      │    │  HashiCorp      │
│   Container     │    │  DaemonSet       │    │  Vault          │
│                 │    │                  │    │                 │
│  Mounts volume  │◄───┤ • Node-level ops │◄───┤ • Stores secrets│  
│  at /mnt/       │    │ • Fetches secrets│    │ • Validates JWT │
│  secrets-store/ │    │ • Creates files  │    │ • Issues tokens │
│                 │    │ • Syncs K8s      │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🔑 Vault Resources Created

#### 1. **Test Secret** (`secret/csi-test`)
```bash
# Comprehensive test data
vault kv put secret/csi-test \
    username="csi-test-user" \
    password="csi-test-password-123" \
    database_url="postgresql://csi-test:secret@db:5432/testdb" \
    api_token="csi-test-token-abcd1234" \
    config_json='{"debug":true,"timeout":30}'
```

#### 2. **Vault Policy** (`csi-test-policy`)
```hcl
# Read access to CSI test secret
path "secret/data/csi-test" {
  capabilities = ["read"]
}

path "secret/metadata/csi-test" {
  capabilities = ["read"]
}
```

#### 3. **Kubernetes Auth Role** (`csi-test-role`)
```bash
vault write auth/kubernetes/role/csi-test-role \
    bound_service_account_names="csi-test-sa" \
    bound_service_account_namespaces="default" \
    policies="csi-test-policy" \
    ttl=1h
```

### 🚀 Kubernetes Resources

#### 1. **Service Account** (`csi-test-sa`)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-test-sa
  namespace: default
```

#### 2. **SecretProviderClass**
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-csi-test-provider
spec:
  provider: vault
  parameters:
    roleName: "csi-test-role"
    vaultAddress: "http://vault.vault.svc.cloud.uat:8200"
    objects: |
      - objectName: "username"
        secretPath: "secret/data/csi-test"
        secretKey: "username"
      - objectName: "password"
        secretPath: "secret/data/csi-test"
        secretKey: "password"
      - objectName: "database_url"
        secretPath: "secret/data/csi-test"
        secretKey: "database_url"
      - objectName: "api_token"
        secretPath: "secret/data/csi-test"
        secretKey: "api_token"
      - objectName: "config_json"
        secretPath: "secret/data/csi-test"
        secretKey: "config_json"
  # Optional: Sync to Kubernetes secrets
  secretObjects:
  - secretName: vault-csi-secret
    type: Opaque
    data:
    - objectName: username
      key: username
    - objectName: password
      key: password
```

#### 3. **Test Pod with CSI Volume**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-csi-test-pod
spec:
  serviceAccountName: csi-test-sa
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "vault-csi-test-provider"
```

### 📁 Secret File Structure
Secrets mounted at `/mnt/secrets-store/`:
```
/mnt/secrets-store/
├── username             # csi-test-user
├── password            # csi-test-password-123
├── database_url        # postgresql://csi-test:secret@db:5432/testdb
├── api_token          # csi-test-token-abcd1234
└── config_json        # {"debug":true,"timeout":30}
```

### ⚙️ Key Configuration Requirements

1. **Secrets Store CSI Driver Installed**:
   ```bash
   helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
   helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
       --set syncSecret.enabled=true
   ```

2. **Vault CSI Provider**:
   ```bash
   helm install vault-csi-provider hashicorp/vault-csi-provider
   ```

3. **RBAC Permissions** (for secret synchronization):
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: csi-secrets-store-role
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     verbs: ["create", "get", "list", "patch", "update", "watch"]
   ```

4. **SecretProviderClass**: Must specify correct Vault address and object mappings
5. **Volume Mount**: Pod must mount the CSI volume
6. **Network Access**: CSI driver must reach Vault

### 🔍 RBAC Issue Detection
The script includes intelligent RBAC detection:
```bash
# Automatically detects permission issues
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=50 | \
    grep -q "secrets is forbidden" && write_permission_summary
```

### 📊 Test Results (12 Tests)
- ✅ **Infrastructure**: Dependencies, CSI driver verification
- ✅ **Vault Setup**: Login, secret, policy, role creation
- ✅ **Kubernetes**: Service account, SecretProviderClass, pod deployment
- ✅ **CSI Functionality**: Volume mounting, file creation, data validation

---

## 🌐 Test Script 3: Vault API (`test_vault_api.sh`)

### 🎯 Purpose
Tests **direct Vault REST API access** from applications using Python client libraries.

### 🏗️ Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Python        │    │  Vault REST      │    │  HashiCorp      │
│   Application   │    │  API             │    │  Vault          │
│                 │    │                  │    │                 │
│  HTTP requests  │────┤ /v1/auth/        │◄───┤ • Stores secrets│  
│  with tokens    │    │ kubernetes/login │    │ • Validates JWT │
│                 │◄───┤ /v1/secret/      │    │ • Manages tokens│
│  JSON responses │    │ api-test         │    │ • Policy engine │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🔑 Vault Resources Created

#### 1. **Test Secret** (`secret/api-test`)
```bash
# Complex data types for API testing
vault kv put secret/api-test \
    username="api-test-user" \
    password="api-test-password" \
    database_host="postgres.example.com" \
    database_port="5432" \
    database_name="api_test_db" \
    api_endpoint="https://api.example.com/v1" \
    api_key="api-test-key-abcdef123456" \
    config_json='{"timeout":60,"retries":3,"debug":true}' \
    ssl_cert="-----BEGIN CERTIFICATE-----\nMIIC...test...cert\n-----END CERTIFICATE-----"
```

#### 2. **Vault Policy** (`api-test-policy`)
```hcl
# API access permissions
path "secret/api-test" {
  capabilities = ["read", "list"]
}

path "secret/api-test/*" {
  capabilities = ["read", "list"]
}

# Token management
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

#### 3. **Kubernetes Auth Role** (`api-test-role`)
```bash
vault write auth/kubernetes/role/api-test-role \
    bound_service_account_names="api-test-sa" \
    bound_service_account_namespaces="default" \
    policies="api-test-policy" \
    ttl=24h
```

### 🚀 Kubernetes Resources

#### 1. **Service Account** (`api-test-sa`)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-test-sa
  namespace: default
```

#### 2. **Python API Client ConfigMap**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-api-test-script
data:
  test_script.py: |
    import requests
    import json
    
    class VaultAPIClient:
        def authenticate(self):
            # Read service account token
            with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
                jwt_token = f.read().strip()
            
            # Authenticate with Vault
            auth_data = {"role": "api-test-role", "jwt": jwt_token}
            response = requests.post(f"{vault_url}/v1/auth/kubernetes/login", 
                                   json=auth_data)
            self.token = response.json()['auth']['client_token']
        
        def get_secret(self, path):
            # Retrieve secret via API
            headers = {'X-Vault-Token': self.token}
            response = requests.get(f"{vault_url}/v1/{path}", headers=headers)
            return response.json()
```

#### 3. **Test Pod with Python Runtime**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-api-test-pod
spec:
  serviceAccountName: api-test-sa
  containers:
  - name: python-app
    image: python:3.11-slim
    command: ["/bin/bash", "-c"]
    args:
    - |
      pip install requests urllib3
      python /app/test_script.py
      sleep 3600
    volumeMounts:
    - name: test-script
      mountPath: /app
  volumes:
  - name: test-script
    configMap:
      name: vault-api-test-script
```

### 🔗 API Endpoints Used

#### 1. **Authentication**
```http
POST /v1/auth/kubernetes/login
Content-Type: application/json

{
  "role": "api-test-role",
  "jwt": "<service-account-token>"
}
```

#### 2. **Token Validation**
```http
GET /v1/auth/token/lookup-self
X-Vault-Token: <vault-token>
```

#### 3. **Secret Retrieval**
```http
GET /v1/secret/api-test
X-Vault-Token: <vault-token>
```

### 📊 API Response Format
```json
{
  "request_id": "uuid",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "username": "api-test-user", 
    "password": "api-test-password",
    "database_host": "postgres.example.com",
    "database_port": "5432",
    "database_name": "api_test_db",
    "api_endpoint": "https://api.example.com/v1",
    "api_key": "api-test-key-abcdef123456",
    "config_json": "{\"timeout\":60,\"retries\":3,\"debug\":true}",
    "ssl_cert": "-----BEGIN CERTIFICATE-----..."
  }
}
```

### ⚙️ Key Configuration Requirements

1. **Vault HTTP API Accessible**:
   - Service: `http://vault.vault.svc.cluster.local:8200`
   - Ingress: `https://vault.gokcloud.com`

2. **Python Dependencies**:
   ```bash
   pip install requests urllib3
   ```

3. **Token Management**: Application must handle token expiration and renewal

4. **Error Handling**: Robust handling of network and authentication failures

5. **SSL Configuration**: Handle self-signed certificates if needed:
   ```python
   requests.get(url, verify=False)  # For self-signed certs
   ```

### 📊 Test Results (13 Tests)
- ✅ **Infrastructure**: Dependencies, Vault connectivity
- ✅ **Vault Setup**: Login, secret, policy, role configuration
- ✅ **Kubernetes**: Service account, Python script, pod deployment
- ✅ **API Functionality**: Authentication, token validation, secret retrieval, data parsing

---

## 🔄 Comparison Matrix

| Feature | Agent Injector | CSI Driver | Direct API |
|---------|---------------|------------|------------|
| **Complexity** | Low | Medium | High |
| **Secret Updates** | Pod restart required | Automatic | Real-time |
| **Token Management** | Automatic | Automatic | Manual |
| **Performance** | High (cached) | High (cached) | Medium (per-request) |
| **Security** | High | High | Medium |
| **Flexibility** | Limited | Medium | Full |
| **Legacy App Support** | Excellent | Good | Requires changes |
| **Debugging** | Moderate | Difficult | Easy |
| **Resource Usage** | High (sidecar) | Low | Low |

---

## 🛠️ Prerequisites

### 1. **HashiCorp Vault Setup**
```bash
# Install Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault

# Initialize and unseal Vault
kubectl exec vault-0 -n vault -- vault operator init
kubectl exec vault-0 -n vault -- vault operator unseal <key>
```

### 2. **Enable Kubernetes Auth**
```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

### 3. **Install Required Components**
```bash
# For Agent Injector
helm install vault hashicorp/vault --set "injector.enabled=true"

# For CSI Driver  
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
helm install vault-csi-provider hashicorp/vault-csi-provider

# For API Access
# No additional components required
```

---

## 🚀 Running the Tests

### Execute Individual Tests
```bash
# Test Agent Injector
./test_vault_agent_injector.sh

# Test CSI Driver  
./test_vault_csi.sh

# Test Direct API
./test_vault_api.sh
```

### View Help Documentation
```bash
# Comprehensive help with examples
./test_vault_agent_injector.sh --help
./test_vault_csi.sh --help
./test_vault_api.sh --help
```

### Cleanup Resources
```bash
# Clean up specific test resources
./test_vault_agent_injector.sh --cleanup
./test_vault_csi.sh --cleanup  
./test_vault_api.sh --cleanup
```

---

## 📝 Best Practices

### 1. **Security**
- Use least-privilege policies
- Rotate tokens regularly  
- Enable audit logging
- Use TLS for Vault communication

### 2. **Production Readiness**
- Implement proper error handling
- Add retry logic with exponential backoff
- Monitor token expiration
- Use structured logging

### 3. **Performance**
- Cache tokens when possible
- Batch secret retrievals
- Use appropriate TTL values
- Implement circuit breakers

### 4. **Operational**
- Set up monitoring and alerting
- Document secret rotation procedures
- Implement backup strategies
- Plan for disaster recovery

---

## 🔍 Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check service account permissions
   - Verify Kubernetes auth configuration
   - Ensure network connectivity

2. **Secret Access Denied**
   - Review Vault policies
   - Check role bindings
   - Verify secret paths

3. **CSI Mount Issues**
   - Check RBAC permissions
   - Verify SecretProviderClass
   - Review CSI driver logs

4. **API Connection Problems**
   - Test Vault connectivity
   - Check SSL/TLS settings
   - Verify endpoint URLs

### Debug Commands
```bash
# Check Vault status
kubectl exec vault-0 -n vault -- vault status

# View CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver

# Test API connectivity
kubectl run test --rm -it --image=curlimages/curl -- \
    curl -k https://vault.gokcloud.com/v1/sys/health
```

This comprehensive guide provides everything needed to understand, implement, and troubleshoot Vault integrations in Kubernetes environments! 🎯