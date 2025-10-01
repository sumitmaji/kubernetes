# Mock Execution Demo: setup_vault_k8s_auth.sh

This document shows what the script execution would look like in a real environment with Vault and kubectl available.

## 📋 **Real Execution Flow**

### **1. Successful Execution (with all prerequisites)**

```bash
$ export VAULT_ADDR="http://vault.vault:8200"
$ export VAULT_TOKEN="s.abc123def456"  # Real Vault token
$ ./setup_vault_k8s_auth.sh

[INFO] Starting Vault Kubernetes Authentication Setup
[INFO] ==========================================
[INFO] Checking Vault connection to http://vault.vault:8200
[SUCCESS] Connected to Vault successfully
[WARNING] Not running in Kubernetes cluster
[INFO] Getting Kubernetes configuration from kubectl
[INFO] Service account gok-agent exists in namespace default
[SUCCESS] Successfully obtained Kubernetes configuration
[INFO] Enabling Kubernetes auth method
[SUCCESS] Enabled Kubernetes auth method at path: kubernetes
[INFO] Configuring Kubernetes auth method
[SUCCESS] Configured Kubernetes auth method
[INFO] Creating Vault policy: rabbitmq-policy
[SUCCESS] Created Vault policy: rabbitmq-policy
[INFO] Creating Vault role: gok-agent
[SUCCESS] Created Vault role: gok-agent
[INFO] Testing Kubernetes Service Account authentication
[INFO] Testing authentication with fresh service account token
[SUCCESS] Authentication test successful!
[INFO]   Client token: s.xyz789abc123def456...
[INFO]   Lease duration: 86400s
[INFO] Testing secret access
[WARNING] Secret access test failed (this is expected if secret doesn't exist yet)
[INFO] Configuration Summary:
  Vault Address: http://vault.vault:8200
  Auth Path: kubernetes
  Vault Role: gok-agent
  Service Account: gok-agent
  Namespace: default
  Policy Name: rabbitmq-policy
  Secret Path: secret/data/rabbitmq
  Token TTL: 24h

[SUCCESS] Vault Kubernetes authentication setup completed successfully!

[INFO] Next steps:
  1. Ensure the service account exists: kubectl get sa gok-agent -n default
  2. Deploy GOK-Agent with these environment variables:
     VAULT_ADDR=http://vault.vault:8200
     VAULT_K8S_ROLE=gok-agent
     VAULT_K8S_AUTH_PATH=kubernetes
     VAULT_PATH=secret/data/rabbitmq
  3. Store RabbitMQ credentials in Vault:
     vault kv put secret/data/rabbitmq username=<user> password=<pass>
```

### **2. Vault Policy Created**

The script creates this policy in Vault:

```hcl
# Allow reading RabbitMQ credentials
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}

# Allow reading metadata
path "secret/metadata/rabbitmq" {
  capabilities = ["read"]
}

# Allow listing secrets (optional)
path "secret/metadata" {
  capabilities = ["list"]
}
```

### **3. Vault Role Configuration**

The script creates this Kubernetes auth role:

```bash
vault write auth/kubernetes/role/gok-agent \
    bound_service_account_names="gok-agent" \
    bound_service_account_namespaces="default" \
    policies="rabbitmq-policy" \
    ttl="24h"
```

### **4. Kubernetes Auth Method Configuration**

```bash
vault write auth/kubernetes/config \
    token_reviewer_jwt="<service-account-jwt>" \
    kubernetes_host="https://kubernetes.default.svc.cluster.local" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

## 🔧 **What the Script Actually Does**

### **Phase 1: Validation & Prerequisites**
- ✅ Validates VAULT_TOKEN is provided
- ✅ Checks Vault CLI availability and connectivity
- ✅ Obtains Kubernetes cluster configuration
- ✅ Verifies service account exists

### **Phase 2: Vault Configuration**
- ✅ Enables Kubernetes auth method (if not already enabled)
- ✅ Configures Vault to trust the Kubernetes cluster
- ✅ Creates minimal-privilege policy for RabbitMQ access
- ✅ Creates role binding service account to policy

### **Phase 3: Testing & Validation**
- ✅ Tests service account JWT authentication with Vault
- ✅ Verifies token creation and permissions
- ✅ Tests secret access (if secrets exist)
- ✅ Provides comprehensive success/failure feedback

### **Phase 4: Documentation & Next Steps**
- ✅ Displays complete configuration summary
- ✅ Provides exact commands for next deployment steps
- ✅ Shows environment variables needed for GOK-Agent
- ✅ Gives commands for storing credentials

## 📊 **Error Scenarios Handled**

### **Missing Prerequisites**
```bash
[ERROR] VAULT_TOKEN environment variable is required
[ERROR] Vault CLI not found. Please install vault CLI.
[ERROR] Cannot connect to Vault at http://localhost:8200
[ERROR] Service account gok-agent not found in namespace default
```

### **Configuration Issues**
```bash
[WARNING] Kubernetes auth method already enabled at path: kubernetes
[ERROR] Could not obtain Kubernetes JWT token
[ERROR] Authentication test failed
```

### **Permission Issues**
```bash
[ERROR] Insufficient privileges to configure Vault
[ERROR] Cannot create Kubernetes auth role
[WARNING] Secret access test failed (this is expected if secret doesn't exist yet)
```

## 🎯 **Production Usage Pattern**

### **DevOps Pipeline Integration**
```yaml
# .github/workflows/deploy.yml
- name: Setup Vault K8s Authentication
  run: |
    export VAULT_ADDR="${{ secrets.VAULT_ADDR }}"
    export VAULT_TOKEN="${{ secrets.VAULT_TOKEN }}"
    ./setup_vault_k8s_auth.sh
  
- name: Deploy GOK-Agent
  run: |
    helm upgrade --install gok-agent agent/chart \
      --set vault.enabled=true \
      --set vault.auth.kubernetes.role=gok-agent
```

### **Development Environment Setup**
```bash
# Local development setup
export VAULT_ADDR="https://vault-dev.company.com"
export VAULT_TOKEN="$(vault auth -method=userpass username=dev-user)"
export SERVICE_ACCOUNT_NAMESPACE="development"

./setup_vault_k8s_auth.sh
```

### **Production Environment Setup**
```bash
# Production setup with custom configuration
export VAULT_ADDR="https://vault.company.com"
export VAULT_TOKEN="${VAULT_PRODUCTION_TOKEN}"
export SERVICE_ACCOUNT_NAMESPACE="production"
export TOKEN_TTL="12h"
export POLICY_NAME="production-rabbitmq-policy"

./setup_vault_k8s_auth.sh
```

## 🚀 **Integration Benefits**

1. **Automated Security**: No manual Vault configuration steps
2. **Consistent Setup**: Same configuration across all environments  
3. **Validation Built-in**: Comprehensive testing of the setup
4. **Documentation**: Complete next-steps guidance
5. **Error Handling**: Clear error messages and troubleshooting
6. **Production Ready**: Enterprise-grade security configuration

The script transforms what would be 15+ manual Vault and kubectl commands into a single, validated, automated setup process! 🎉