# Kubernetes Service Account Authentication with Vault

This guide explains how to set up Kubernetes Service Account authentication with HashiCorp Vault for the GOK-Agent system.

## Overview

The GOK-Agent components (agent and controller) can authenticate with Vault using Kubernetes Service Account tokens instead of requiring manual token management. This provides a secure, automated way to access RabbitMQ credentials stored in Vault.

## Prerequisites

1. Running Kubernetes cluster with GOK-Agent deployed
2. HashiCorp Vault instance accessible from the cluster
3. Vault Kubernetes auth method enabled
4. Appropriate RBAC permissions configured

## Vault Configuration

### 1. Enable Kubernetes Auth Method

```bash
# Enable the Kubernetes auth method
vault auth enable kubernetes

# Configure the Kubernetes auth method
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://kubernetes.default.svc.cluster.local" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

### 2. Create Vault Policy for RabbitMQ Access

```bash
# Create policy file
cat > rabbitmq-policy.hcl << EOF
# Allow reading RabbitMQ credentials
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}

# Allow reading metadata
path "secret/metadata/rabbitmq" {
  capabilities = ["read"]
}
EOF

# Apply the policy
vault policy write rabbitmq-policy rabbitmq-policy.hcl
```

### 3. Create Vault Role for GOK-Agent

```bash
# Create a role that maps K8s service accounts to Vault policies
vault write auth/kubernetes/role/gok-agent \
    bound_service_account_names=gok-agent \
    bound_service_account_namespaces=default,gok-system \
    policies=rabbitmq-policy \
    ttl=24h
```

## Kubernetes Configuration

### 1. Create Service Account

```yaml
# gok-agent-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gok-agent
  namespace: default  # or your preferred namespace
automountServiceAccountToken: true
```

### 2. Create RBAC Permissions (Optional)

If your cluster requires additional permissions:

```yaml
# gok-agent-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gok-agent-vault-auth
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gok-agent-vault-auth
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gok-agent-vault-auth
subjects:
- kind: ServiceAccount
  name: gok-agent
  namespace: default  # or your preferred namespace
```

### 3. Update Deployment Configuration

Update your GOK-Agent deployments to use the service account and provide Vault configuration:

```yaml
# For Agent Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-agent
spec:
  template:
    spec:
      serviceAccountName: gok-agent
      containers:
      - name: gok-agent
        image: your-registry/gok-agent:latest
        env:
        - name: VAULT_ADDR
          value: "http://vault.vault:8200"  # Adjust for your Vault URL
        - name: VAULT_K8S_ROLE
          value: "gok-agent"
        - name: VAULT_K8S_AUTH_PATH
          value: "kubernetes"
        - name: VAULT_PATH
          value: "secret/data/rabbitmq"
        - name: RABBITMQ_HOST
          value: "rabbitmq.rabbitmq"
        - name: RABBITMQ_PORT
          value: "5672"
        - name: RABBITMQ_VHOST
          value: "/"
---
# For Controller Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-controller
spec:
  template:
    spec:
      serviceAccountName: gok-agent
      containers:
      - name: gok-controller
        image: your-registry/gok-controller:latest
        env:
        - name: VAULT_ADDR
          value: "http://vault.vault:8200"  # Adjust for your Vault URL
        - name: VAULT_K8S_ROLE
          value: "gok-agent"
        - name: VAULT_K8S_AUTH_PATH
          value: "kubernetes"
        - name: VAULT_PATH
          value: "secret/data/rabbitmq"
        - name: RABBITMQ_HOST
          value: "rabbitmq.rabbitmq"
        - name: RABBITMQ_PORT
          value: "5672"
        - name: RABBITMQ_VHOST
          value: "/"
```

## Environment Variables

The GOK-Agent components support the following environment variables for Vault authentication:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `VAULT_ADDR` | Vault server URL | `http://localhost:8200` | Yes |
| `VAULT_K8S_ROLE` | Vault role for K8s auth | - | Yes (for K8s auth) |
| `VAULT_K8S_AUTH_PATH` | K8s auth path in Vault | `kubernetes` | No |
| `VAULT_PATH` | Path to RabbitMQ credentials | `secret/data/rabbitmq` | No |
| `VAULT_TOKEN` | Manual Vault token | - | No (if using K8s auth) |

## Authentication Flow

1. **Container Startup**: GOK-Agent reads the service account token from `/var/run/secrets/kubernetes.io/serviceaccount/token`
2. **Vault Authentication**: Sends JWT token to Vault's Kubernetes auth endpoint
3. **Token Acquisition**: Receives a Vault client token with TTL
4. **Credential Access**: Uses the client token to read RabbitMQ credentials
5. **Token Refresh**: Automatically refreshes the token before expiry

## Testing the Setup

### 1. Deploy the Configuration

```bash
# Apply Kubernetes resources
kubectl apply -f gok-agent-serviceaccount.yaml
kubectl apply -f gok-agent-rbac.yaml  # if needed

# Deploy GOK-Agent with updated configuration
kubectl apply -f gok-agent-deployment.yaml
```

### 2. Verify Authentication

Check the logs to verify successful authentication:

```bash
# Check agent logs
kubectl logs -l app=gok-agent

# Check controller logs  
kubectl logs -l app=gok-controller

# Look for messages like:
# "Successfully authenticated with Vault using Kubernetes Service Account (TTL: 86400s)"
# "Successfully retrieved RabbitMQ credentials from Vault"
```

### 3. Test Credential Retrieval

Use the test scripts to verify end-to-end functionality:

```bash
# Run the comprehensive test
kubectl exec -it deployment/gok-agent -- python test_vault_integration.py

# Or run individual components
kubectl exec -it deployment/gok-agent -- python gok_agent_test.py
```

## Troubleshooting

### Common Issues

1. **Service Account Token Not Found**
   - Ensure `automountServiceAccountToken: true` in ServiceAccount
   - Verify the pod has the service account attached

2. **Vault Authentication Failed**
   - Check Vault role configuration matches service account name/namespace
   - Verify Kubernetes auth method is properly configured
   - Check network connectivity to Vault

3. **Permission Denied**
   - Verify Vault policy allows reading the secret path
   - Check role binding between service account and Vault role

4. **Token Expiry Issues**
   - Monitor logs for automatic token refresh messages
   - Adjust TTL in Vault role if needed

### Debug Commands

```bash
# Check service account token
kubectl exec -it deployment/gok-agent -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Test Vault connectivity
kubectl exec -it deployment/gok-agent -- curl -k $VAULT_ADDR/v1/sys/health

# Check Vault auth status
vault read auth/kubernetes/role/gok-agent
vault list auth/kubernetes/role
```

## Security Considerations

1. **Minimal Permissions**: Grant only the minimum required Vault policies
2. **Namespace Isolation**: Use specific namespaces in Vault role bindings
3. **Token TTL**: Set appropriate token TTL based on your security requirements
4. **Network Security**: Ensure Vault communication is encrypted in production
5. **Audit Logging**: Enable Vault audit logging to track credential access

## Migration from Token-Based Auth

If migrating from manual token authentication:

1. **Parallel Deployment**: Deploy new configuration alongside existing
2. **Validation**: Test K8s auth thoroughly in non-production
3. **Gradual Rollout**: Update deployments one at a time
4. **Remove Tokens**: Remove manual `VAULT_TOKEN` environment variables
5. **Cleanup**: Revoke old tokens in Vault

## References

- [Vault Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [Kubernetes Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Vault Policies](https://www.vaultproject.io/docs/concepts/policies)