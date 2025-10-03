# Helm Charts Vault Configuration Sync

## Overview
Updated both `gok-agent` and `gok-controller` Helm charts to align with the multi-namespace Vault authentication setup configured in `setup_vault_k8s_auth.sh`.

## Changes Made

### 1. Agent Chart (`/agent/chart/values.yaml`)
**Service Account Configuration:**
- ✅ Keeps `serviceAccount.name: gok-agent`
- ✅ Deploys in `gok-agent` namespace

**Environment Variables Updated:**
```yaml
env:
  # Vault Configuration (using service URL with cloud.uat domain)
  VAULT_ADDR: "http://vault.vault.svc.cloud.uat:8200"      # Vault service URL
  VAULT_K8S_AUTH_PATH: "kubernetes"                        # Auth path
  VAULT_K8S_ROLE: "gok-agent"                             # Agent-specific role
  VAULT_PATH: "secret/data/rabbitmq"                      # KV v2 secret path
```

**Vault Configuration Updated:**
```yaml
vault:
  enabled: true
  address: "http://vault.vault.svc.cloud.uat:8200"         # Vault service URL
  credentialPath: "secret/data/rabbitmq"
  auth:
    method: "kubernetes"
    kubernetes:
      role: "gok-agent"                            # Agent-specific role
      authPath: "kubernetes"
      serviceAccount: "gok-agent"
      namespace: "gok-agent"                       # Added namespace
      tokenPath: "/var/run/secrets/kubernetes.io/serviceaccount/token"
```

### 2. Controller Chart (`/controller/chart/values.yaml`)
**Service Account Configuration:**
- ✅ Updated `serviceAccount.name: gok-controller` (was gok-agent)
- ✅ Deploys in `gok-controller` namespace

**Environment Variables Updated:**
```yaml
env:
  # Vault Configuration (using service URL with cloud.uat domain)
  VAULT_ADDR: "http://vault.vault.svc.cloud.uat:8200"      # Vault service URL
  VAULT_K8S_AUTH_PATH: "kubernetes"                        # Auth path
  VAULT_K8S_ROLE: "gok-controller"                        # Controller-specific role
  VAULT_PATH: "secret/data/rabbitmq"                      # KV v2 secret path
```

**Vault Configuration Updated:**
```yaml
vault:
  enabled: true
  address: "http://vault.vault.svc.cloud.uat:8200"         # Vault service URL
  credentialPath: "secret/data/rabbitmq"
  auth:
    method: "kubernetes"
    kubernetes:
      role: "gok-controller"                       # Controller-specific role
      authPath: "kubernetes"
      serviceAccount: "gok-controller"
      namespace: "gok-controller"                  # Added namespace
      tokenPath: "/var/run/secrets/kubernetes.io/serviceaccount/token"
```

### 3. Template Updates

**Agent Chart Templates:**
- ✅ `templates/deployment.yaml` - Uses correct Vault env vars from values
- ✅ `templates/serviceaccount.yaml` - Correctly defaults to "gok-agent"

**Controller Chart Templates:**
- ✅ `templates/deployment.yaml` - Updated default serviceAccount to "gok-controller"
- ✅ `templates/serviceaccount.yaml` - Updated default name to "gok-controller"

## Validation Results

### Helm Template Generation
Both charts now generate correct configurations:

**Agent Chart:**
```yaml
env:
- name: VAULT_ADDR
  value: "http://vault.vault.svc.cloud.uat:8200"
- name: VAULT_K8S_ROLE
  value: "gok-agent"
- name: VAULT_K8S_AUTH_PATH
  value: "kubernetes"
- name: VAULT_PATH
  value: "secret/data/rabbitmq"
```

**Controller Chart:**
```yaml
env:
- name: VAULT_ADDR
  value: "http://vault.vault.svc.cloud.uat:8200"
- name: VAULT_K8S_ROLE
  value: "gok-controller"
- name: VAULT_K8S_AUTH_PATH
  value: "kubernetes"
- name: VAULT_PATH
  value: "secret/data/rabbitmq"
```

## Deployment Instructions

### For gok-agent namespace:
```bash
cd /home/sumit/Documents/repository/kubernetes/install_k8s/gok-agent/agent/chart
helm upgrade --install gok-agent . --namespace gok-agent --create-namespace
```

### For gok-controller namespace:
```bash
cd /home/sumit/Documents/repository/kubernetes/install_k8s/gok-agent/controller/chart
helm upgrade --install gok-controller . --namespace gok-controller --create-namespace
```

## Configuration Alignment

The charts now perfectly align with the `setup_vault_k8s_auth.sh` configuration:

| Component | Namespace | Service Account | Vault Role | Auth Method |
|-----------|-----------|-----------------|------------|-------------|
| Agent | gok-agent | gok-agent | gok-agent | kubernetes |
| Controller | gok-controller | gok-controller | gok-controller | kubernetes |

Both applications will now:
1. Use their respective service accounts for Vault authentication
2. Access the same RabbitMQ credentials at `secret/data/rabbitmq`
3. Authenticate using Kubernetes service account tokens
4. Use the Vault service URL with cloud.uat domain

**Service URL Format:** `vault.vault.svc.cloud.uat`
- `vault` = service name
- `vault` = namespace  
- `svc.cloud.uat` = Custom Kubernetes service domain (UAT environment)

## Next Steps

1. **Deploy the charts** using the commands above
2. **Verify authentication** by checking pod logs for successful Vault connections
3. **Test RabbitMQ connectivity** using the retrieved credentials
4. **Monitor** the applications for any authentication issues

The Helm charts are now fully synchronized with the multi-namespace Vault authentication setup!