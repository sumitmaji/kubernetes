# HashiCorp Vault Integration with GOK-Agent and RabbitMQ

This documentation explains how to integrate HashiCorp Vault with the GOK-Agent system for secure RabbitMQ credential management.

## Overview

The integration provides secure credential management for RabbitMQ by:
1. Storing RabbitMQ credentials in HashiCorp Vault
2. Updating GOK-Agent components to retrieve credentials from Vault
3. Providing fallback mechanisms for high availability
4. Comprehensive testing and validation tools

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GOK-Agent     │    │  HashiCorp      │    │   RabbitMQ      │
│                 │    │  Vault          │    │   Cluster       │
│  ┌───────────┐  │    │                 │    │                 │
│  │   Agent   │──┼────┤ Credentials     │    │  ┌───────────┐  │
│  └───────────┘  │    │ Storage         │    │  │ Messages  │  │
│                 │    │                 │    │  │   Queue   │  │
│  ┌───────────┐  │    │                 │    │  └───────────┘  │
│  │Controller │──┼────┤                 │    │                 │
│  └───────────┘  │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Components

### 1. Vault Credential Storage Script (`vault_rabbitmq_setup.sh`)

**Purpose**: Manages RabbitMQ credentials in HashiCorp Vault

**Key Features**:
- Store credentials from Kubernetes secrets to Vault
- Retrieve and test credentials
- Credential rotation capabilities
- Comprehensive error handling and logging

**Usage Examples**:
```bash
# Set environment variables
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="your-vault-token"

# Store credentials from Kubernetes
./vault_rabbitmq_setup.sh store-from-k8s

# Test connectivity
./vault_rabbitmq_setup.sh test-connection

# Retrieve credentials
./vault_rabbitmq_setup.sh retrieve

# Rotate credentials
./vault_rabbitmq_setup.sh rotate
```

### 2. Vault Credentials Library (`vault_credentials.py`)

**Purpose**: Python library for Vault credential integration  
**Location**: Copied to both `agent/vault_credentials.py` and `controller/backend/vault_credentials.py`

**Key Classes**:
- `VaultCredentialManager`: Main class for Vault operations
- `RabbitMQCredentials`: Data class for credential storage
- Fallback functions for high availability

**Usage Example**:
```python
# From within agent or controller components
from vault_credentials import get_rabbitmq_credentials, VaultCredentialManager

# Get credentials with automatic fallback
credentials = get_rabbitmq_credentials(prefer_vault=True)

# Direct Vault manager usage
manager = VaultCredentialManager()
credentials = manager.get_rabbitmq_credentials()
```

### 3. Updated GOK-Agent Components

**Agent (`agent/app.py`)**:
- Modified to use Vault for RabbitMQ credentials
- Maintains fallback to Kubernetes secrets
- Updated connection parameter handling

**Controller (`controller/backend/app.py`)**:
- Updated RabbitMQ connection management
- Integrated Vault credential retrieval
- Preserved existing functionality

### 4. Test Suites

**Vault Integration Tests (`test_vault_integration.py`)**:
- Comprehensive unit tests for all Vault components
- Mock testing for isolated functionality
- Live service integration tests

**End-to-End Tests (`gok_agent_test.py`)**:
- Complete workflow testing
- Agent-to-Controller communication validation
- RabbitMQ message processing verification

## Installation and Setup

### Prerequisites

1. **HashiCorp Vault**: Running and accessible
2. **RabbitMQ Cluster**: Operational with existing credentials
3. **Python Dependencies**: 
   ```bash
   pip install pika requests python-jose
   ```
4. **Vault CLI**: Installed and configured

### Setup Steps

#### 1. Configure Vault

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Create policy for GOK-Agent access
vault policy write gok-agent-policy - <<EOF
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}
path "secret/metadata/rabbitmq" {
  capabilities = ["read"]
}
EOF
```

#### 2. Set Up Kubernetes Authentication (Optional)

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for GOK-Agent
vault write auth/kubernetes/role/gok-agent-role \
    bound_service_account_names=agent-backend-sa,gok-controller-sa \
    bound_service_account_namespaces=default \
    policies=gok-agent-policy \
    ttl=1h
```

#### 3. Store Initial Credentials

```bash
# Set Vault environment variables
export VAULT_ADDR="http://vault.vault:8200"
export VAULT_TOKEN="your-vault-token"

# Store credentials from existing Kubernetes setup
./vault_rabbitmq_setup.sh store-from-k8s
```

#### 4. Update Helm Deployments

Update `values.yaml` files with Vault configuration:

**Agent Configuration**:
```yaml
vault:
  enabled: true
  address: "http://vault.vault:8200"
  credentialPath: "secret/rabbitmq"
```

**Controller Configuration**:
```yaml
vault:
  enabled: true  
  address: "http://vault.vault:8200"
  credentialPath: "secret/rabbitmq"
```

#### 5. Deploy Updated Components

```bash
# From the gok-agent directory
# Deploy agent
helm upgrade --install gok-agent ./agent/chart -f agent/chart/values.yaml

# Deploy controller  
helm upgrade --install gok-controller ./controller/chart -f controller/chart/values.yaml
```

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VAULT_ADDR` | Vault server address | `http://localhost:8200` |
| `VAULT_TOKEN` | Vault authentication token | None (required) |
| `VAULT_PATH` | Path to RabbitMQ credentials | `secret/rabbitmq` |
| `RABBITMQ_HOST` | RabbitMQ server hostname | `rabbitmq.rabbitmq` |
| `RABBITMQ_PORT` | RabbitMQ server port | `5672` |
| `RABBITMQ_VHOST` | RabbitMQ virtual host | `/` |

### Helm Chart Values

**Vault Configuration**:
```yaml
vault:
  enabled: true
  address: "http://vault.vault:8200"
  credentialPath: "secret/rabbitmq"
  auth:
    method: "kubernetes"  # or "token"
    kubernetes:
      role: "gok-agent-role"
  fallback:
    useKubernetesSecret: true
    useEnvironmentVariables: true
```

## Testing and Validation

### Unit Tests

```bash
# Run comprehensive unit tests
python test_vault_integration.py

# Run with live service tests
python test_vault_integration.py --with-live
```

### End-to-End Tests

```bash
# Simple connectivity test
python gok_agent_test.py connectivity

# Full end-to-end test
python gok_agent_test.py full
```

### Manual Testing

```bash
# Test Vault connectivity
./vault_rabbitmq_setup.sh status

# Test credential retrieval
./vault_rabbitmq_setup.sh retrieve

# Test RabbitMQ connection with Vault credentials
./vault_rabbitmq_setup.sh test-connection
```

## Security Considerations

### 1. Vault Token Management
- Use Kubernetes service accounts for authentication when possible
- Implement token rotation policies
- Use least-privilege access policies

### 2. Network Security
- Use TLS for Vault communication in production
- Implement network policies to restrict Vault access
- Use internal DNS for service communication

### 3. Credential Rotation
- Implement regular credential rotation
- Use Vault's dynamic secrets when possible
- Monitor credential usage and access patterns

### 4. Audit and Monitoring
- Enable Vault audit logging
- Monitor credential access patterns
- Set up alerts for authentication failures

## Troubleshooting

### Common Issues

#### 1. Vault Connection Failed
```bash
# Check Vault status
vault status

# Verify network connectivity
curl -k $VAULT_ADDR/v1/sys/health

# Check authentication
vault auth -method=userpass username=myuser
```

#### 2. Credential Retrieval Failed
```bash
# Verify secret exists
vault kv get secret/rabbitmq

# Check permissions
vault policy read gok-agent-policy

# Test with vault CLI
vault kv get -field=username secret/rabbitmq
```

#### 3. RabbitMQ Connection Failed
```bash
# Test credentials manually
./vault_rabbitmq_setup.sh test-connection

# Check RabbitMQ status
kubectl get pods -n rabbitmq

# Verify network connectivity
telnet rabbitmq.rabbitmq 5672
```

### Debugging Tools

#### 1. Vault Setup Script Debug Mode
```bash
# Enable debug logging
export VAULT_DEBUG=1
./vault_rabbitmq_setup.sh status
```

#### 2. Python Debug Mode
```python
# Enable debug logging in Python
import logging
logging.getLogger().setLevel(logging.DEBUG)
```

#### 3. GOK-Agent Debug Mode
```bash
# Add debug environment variable to deployment
kubectl set env deployment/gok-agent LOG_LEVEL=DEBUG
```

## Migration Guide

### From Kubernetes Secrets to Vault

#### 1. Backup Existing Credentials
```bash
# Export current credentials
kubectl get secret rabbitmq-default-user -n rabbitmq -o yaml > rabbitmq-backup.yaml
```

#### 2. Store in Vault
```bash
# Use migration script
./vault_rabbitmq_setup.sh store-from-k8s
```

#### 3. Update Applications
- Deploy updated agent and controller
- Verify functionality with tests
- Monitor logs for any issues

#### 4. Remove Old Secrets (Optional)
```bash
# After successful migration and testing
kubectl delete secret rabbitmq-default-user -n rabbitmq
```

### Rollback Procedure

If issues occur, you can rollback by:

1. **Restore Kubernetes Secrets**:
   ```bash
   kubectl apply -f rabbitmq-backup.yaml
   ```

2. **Disable Vault in Helm Charts**:
   ```yaml
   vault:
     enabled: false
   ```

3. **Redeploy Components**:
   ```bash
   helm upgrade gok-agent ./agent/chart
   helm upgrade gok-controller ./controller/chart
   ```

## Performance Considerations

### 1. Connection Pooling
- Implement connection pooling for Vault API calls
- Cache credentials for a reasonable duration
- Use connection timeouts and retries

### 2. Fallback Strategy
- Implement graceful degradation
- Monitor fallback usage
- Ensure fallback paths are tested regularly

### 3. Monitoring Metrics
- Track credential retrieval latency
- Monitor Vault API response times
- Alert on fallback usage patterns

## Best Practices

### 1. Development
- Use separate Vault paths for different environments
- Implement proper secret scanning in CI/CD
- Use infrastructure as code for Vault configuration

### 2. Production
- Use high availability Vault clusters
- Implement proper backup and disaster recovery
- Monitor and alert on all credential operations

### 3. Operations
- Implement regular credential rotation
- Monitor access patterns and audit logs
- Test disaster recovery procedures regularly

## Conclusion

This integration provides a robust, secure, and highly available credential management solution for the GOK-Agent system. The combination of HashiCorp Vault for secure storage, comprehensive fallback mechanisms, and thorough testing ensures reliable operation in production environments.

For additional support or questions, refer to:
- HashiCorp Vault documentation
- GOK-Agent specific documentation
- RabbitMQ Cluster Operator documentation