# Hybrid Vault Integration Guide

## Overview

The gok-agent system now supports **three different Vault integration modes** to provide maximum flexibility for credential management:

1. **Agent Injector Mode** (`agent`) - Static secrets via Vault Agent Injector
2. **Direct API Mode** (`api`) - Dynamic credentials via Vault REST API
3. **Hybrid Mode** (`hybrid`) - Both approaches with intelligent fallback

## Configuration Modes

### 1. Agent Injector Mode (`agent`)
**Best for**: Static secrets that rarely change (certificates, OAuth client secrets, etc.)

```yaml
vault:
  integration:
    mode: "agent"  # Pure Agent Injector mode
    agentInjector:
      enabled: true
    directApi:
      enabled: false
```

**How it works**:
- Vault Agent Injector automatically injects secrets as files into pods
- Secrets are stored in `/vault/secrets/` directory
- Files are updated automatically when secrets change in Vault
- No network calls needed from application to Vault

### 2. Direct API Mode (`api`)
**Best for**: Dynamic credentials that need frequent refresh (database passwords, API tokens)

```yaml
vault:
  integration:
    mode: "api"  # Pure Direct API mode
    agentInjector:
      enabled: false
    directApi:
      enabled: true
```

**How it works**:
- Application directly calls Vault REST API to fetch secrets
- Uses Kubernetes Service Account authentication
- Handles token refresh and renewal automatically
- Supports multiple fallback strategies

### 3. Hybrid Mode (`hybrid`) - **Recommended**
**Best for**: Production environments that need both static and dynamic secrets

```yaml
vault:
  integration:
    mode: "hybrid"  # Use both approaches
    agentInjector:
      enabled: true
    directApi:
      enabled: true
```

**How it works**:
- Tries Agent Injector first for fast file-based access
- Falls back to Direct API if agent injector files not available
- Provides maximum resilience and performance

## Secret Types and Use Cases

### Static Secrets (Agent Injector Preferred)
- **OAuth Client Secrets**: Used for authentication flows
- **TLS Certificates**: For secure communication
- **Configuration Files**: Application settings that rarely change
- **API Keys**: For external service integration

### Dynamic Secrets (Direct API Preferred)
- **Database Credentials**: Frequently rotated passwords
- **RabbitMQ Credentials**: Message queue authentication
- **Temporary Tokens**: Short-lived access tokens
- **Service-to-Service Credentials**: Inter-service authentication

## Configuration Examples

### Complete Hybrid Configuration

```yaml
# gok-agent/agent/chart/values.yaml or gok-agent/controller/chart/values.yaml
vault:
  enabled: true
  address: "http://vault.vault.svc.cloud.uat:8200"
  
  integration:
    mode: "hybrid"  # Options: "agent", "api", "hybrid"
    
    # Agent Injector Configuration
    agentInjector:
      enabled: true
      role: "gok-agent"  # or "gok-controller"
      secrets:
        config:
          path: "secret/data/gok-agent/config"
          template: |
            {{`{{- with secret "secret/data/gok-agent/config" -}}`}}
            {
              "oauth_client_secret": "{{`{{ .Data.data.oauth_client_secret }}`}}",
              "static_config": "{{`{{ .Data.data.static_config }}`}}"
            }
            {{`{{- end }}`}}
        rabbitmq:
          path: "secret/data/rabbitmq"
          template: |
            {{`{{- with secret "secret/data/rabbitmq" -}}`}}
            {
              "username": "{{`{{ .Data.data.username }}`}}",
              "password": "{{`{{ .Data.data.password }}`}}"
            }
            {{`{{- end }}`}}
    
    # Direct API Configuration
    directApi:
      enabled: true
      credentialPath: "secret/data/rabbitmq"
      configPath: "secret/data/gok-agent/config"
  
  # Authentication using Kubernetes Service Account
  auth:
    method: "kubernetes"
    kubernetes:
      role: "gok-agent"  # or "gok-controller"
      authPath: "kubernetes"
      serviceAccount: "gok-agent"  # or "gok-controller"
      namespace: "gok-agent"  # or "gok-controller"
```

## Environment Variables

The application automatically detects the integration mode and configures itself:

```bash
# Set by Helm chart based on values.yaml
VAULT_INTEGRATION_MODE=hybrid    # Options: "agent", "api", "hybrid"
VAULT_ADDR=http://vault.vault.svc.cloud.uat:8200
VAULT_SECRETS_PATH=/vault/secrets  # For agent injector
VAULT_K8S_ROLE=gok-agent          # For direct API
VAULT_K8S_AUTH_PATH=kubernetes    # For direct API
VAULT_PATH=secret/data/rabbitmq   # For direct API
```

## Application Usage

### Retrieving RabbitMQ Credentials

```python
# The application automatically handles the hybrid approach
connection_params = get_rabbitmq_connection_params()

# This function will:
# 1. Try Agent Injector files first (if mode is "agent" or "hybrid")
# 2. Fall back to Direct API (if mode is "api" or "hybrid")
# 3. Fall back to environment variables as last resort
```

### Retrieving Configuration Secrets

```python
# Get static configuration from Agent Injector
config = get_application_config()

# This function will:
# 1. Try Agent Injector /vault/secrets/config file first
# 2. Fall back to Direct API for dynamic config
# 3. Return empty dict if no config available
```

## Fallback Strategy

The hybrid approach provides multiple levels of fallback:

```
1. Agent Injector Files (/vault/secrets/)
   ↓ (if not available)
2. Direct Vault API (with K8s Service Account auth)
   ↓ (if not available)
3. Kubernetes Secrets (kubectl get secret)
   ↓ (if not available)
4. Environment Variables
   ↓ (if not available)
5. Default Guest Credentials
```

## Monitoring and Debugging

### Log Messages

```bash
# Successful Agent Injector retrieval
INFO - Successfully retrieved RabbitMQ credentials from Vault Agent Injector

# Fallback to Direct API
WARNING - Agent Injector credentials not available, trying Direct API
INFO - Successfully retrieved RabbitMQ credentials from Vault API for user: rabbitmq-user

# Final fallback
WARNING - Could not retrieve credentials from any Vault method, using environment variables
```

### Health Checks

You can test the Vault integration:

```python
# Test Agent Injector files
ls -la /vault/secrets/

# Test Direct API connectivity
vault auth -method=kubernetes role=gok-agent
vault kv get secret/rabbitmq
```

## Production Recommendations

### For High Availability
- Use `mode: "hybrid"` for maximum resilience
- Configure all fallback options (K8s secrets + env vars)
- Monitor both Agent Injector and Direct API paths

### For Security
- Use least-privilege Vault roles
- Enable audit logging in Vault
- Rotate service account tokens regularly
- Use short TTL for Direct API tokens

### For Performance
- Use Agent Injector for frequently accessed static secrets
- Use Direct API only for credentials that need rotation
- Cache credentials appropriately in application

## Migration Path

### From Legacy Hard-coded Credentials
1. Start with `mode: "api"` and direct API integration
2. Add Agent Injector for static secrets: `mode: "hybrid"`
3. Move static secrets to Agent Injector templates

### From Existing Agent Injector
1. Keep current Agent Injector configuration
2. Set `mode: "hybrid"` to enable fallback
3. Add Direct API for dynamic credentials

## Troubleshooting

### Agent Injector Issues
```bash
# Check if Vault Agent is running
kubectl get pods -n <namespace> | grep vault-agent

# Check agent injector logs
kubectl logs <pod-name> -c vault-agent

# Verify secret files
kubectl exec <pod-name> -- ls -la /vault/secrets/
```

### Direct API Issues
```bash
# Test K8s Service Account authentication
kubectl auth can-i create serviceaccounts/token --as=system:serviceaccount:<namespace>:<service-account>

# Check Vault connectivity
kubectl exec <pod-name> -- curl -s http://vault.vault.svc.cloud.uat:8200/v1/sys/health
```

### Application Debug Mode
```bash
# Enable debug logging
kubectl set env deployment/<deployment-name> LOG_LEVEL=DEBUG

# Check application logs
kubectl logs -f deployment/<deployment-name>
```

## Security Considerations

1. **Least Privilege**: Each service account should only access required secrets
2. **Network Security**: Vault communication should use TLS in production
3. **Secret Rotation**: Implement regular rotation for dynamic secrets
4. **Audit Trail**: Enable Vault audit logging for compliance
5. **Backup Strategy**: Ensure secrets are backed up and recoverable

## Best Practices

1. **Use Hybrid Mode**: Provides best balance of performance and resilience
2. **Static vs Dynamic**: Choose the right approach for each secret type
3. **Monitor Both Paths**: Set up alerts for both Agent Injector and API failures
4. **Test Fallbacks**: Regularly test all fallback scenarios
5. **Document Secret Types**: Maintain clear documentation of which secrets use which method