# HashiCorp Vault Token Management Guide

This guide explains how to obtain, manage, and use HashiCorp Vault tokens for the GOK-Agent RabbitMQ integration.

## Overview

Vault tokens are the primary method for authenticating with HashiCorp Vault. This document covers various methods to obtain tokens depending on your environment and authentication setup.

## Table of Contents

- [Development Setup](#development-setup)
- [Production Authentication Methods](#production-authentication-methods)
- [Token Management Commands](#token-management-commands)
- [Integration with GOK-Agent Scripts](#integration-with-gok-agent-scripts)
- [Environment Setup](#environment-setup)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Development Setup

### 1. Vault Dev Server (Quickest Start)

For development and testing purposes, use Vault's built-in dev server:

```bash
# Start Vault in development mode
vault server -dev

# Output will show:
# Root Token: hvs.XXXXXXXXXXXXXXXXXXXX
# Unseal Key: YYYYYYYYYYYYYYYYYYYY

# Export the root token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="hvs.XXXXXXXXXXXXXXXXXXXX"  # Use token from server output

# Verify connection
vault status
```

### 2. Get Token Programmatically from Dev Server

```bash
# If Vault dev server is already running
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN=$(vault print token)

# Verify
echo "Current token: ${VAULT_TOKEN:0:15}..."
```

## Production Authentication Methods

### 1. Username/Password Authentication

#### Initial Setup (Admin Task)
```bash
# Enable userpass authentication
vault auth enable userpass

# Create a user with appropriate policies
vault write auth/userpass/users/myuser \
    password=mypassword \
    policies=gok-agent-policy

# Create the policy if it doesn't exist
vault policy write gok-agent-policy - <<EOF
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}
path "secret/metadata/rabbitmq" {
  capabilities = ["read"]
}
EOF
```

#### Login and Get Token
```bash
# Interactive login
vault auth -method=userpass username=myuser password=mypassword

# Programmatic login
export VAULT_TOKEN=$(vault auth -method=userpass username=myuser password=mypassword -format=json | jq -r '.auth.client_token')

# Alternative without jq
vault auth -method=userpass username=myuser password=mypassword -format=json > /tmp/auth.json
export VAULT_TOKEN=$(python3 -c "import json; print(json.load(open('/tmp/auth.json'))['auth']['client_token'])")
rm /tmp/auth.json
```

### 2. LDAP Authentication

#### Setup (Admin Task)
```bash
# Enable LDAP auth
vault auth enable ldap

# Configure LDAP
vault write auth/ldap/config \
    url="ldap://ldap.company.com" \
    userdn="ou=Users,dc=company,dc=com" \
    userattr="uid" \
    groupdn="ou=Groups,dc=company,dc=com" \
    groupfilter="(&(objectClass=groupOfNames)(member={{.UserDN}}))" \
    groupattr="cn"
```

#### Login with LDAP
```bash
# Interactive login
vault auth -method=ldap username=myuser password=mypassword

# Programmatic login
export VAULT_TOKEN=$(vault auth -method=ldap username=myuser password=mypassword -format=json | jq -r '.auth.client_token')
```

### 3. Kubernetes Service Account (In-Cluster)

#### Setup (Admin Task)
```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for GOK-Agent service accounts
vault write auth/kubernetes/role/gok-agent-role \
    bound_service_account_names=agent-backend-sa,web-controller-sa \
    bound_service_account_namespaces=default \
    policies=gok-agent-policy \
    ttl=1h
```

#### Login from Kubernetes Pod
```bash
# This runs inside a Kubernetes pod with the appropriate service account
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
export VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login role=gok-agent-role jwt=$JWT)
```

### 4. AWS IAM Authentication

#### Setup (Admin Task)
```bash
# Enable AWS auth
vault auth enable aws

# Configure AWS auth
vault write auth/aws/config/client \
    secret_key=YOUR_AWS_SECRET_KEY \
    access_key=YOUR_AWS_ACCESS_KEY

# Create role
vault write auth/aws/role/gok-agent-role \
    auth_type=iam \
    policies=gok-agent-policy \
    max_ttl=1h \
    bound_iam_principal_arn=arn:aws:iam::ACCOUNT-ID:role/MyRole
```

#### Login with AWS
```bash
# Login using AWS credentials
vault auth -method=aws

# Programmatic
export VAULT_TOKEN=$(vault auth -method=aws -format=json | jq -r '.auth.client_token')
```

### 5. Token-based Authentication (Direct)

#### Create Token (Admin Task)
```bash
# Create a token with specific policies
vault token create -policy=gok-agent-policy -ttl=24h

# Create a renewable token
vault token create -policy=gok-agent-policy -renewable=true -ttl=1h

# Create token for specific use
vault token create \
    -policy=gok-agent-policy \
    -display-name="gok-agent-token" \
    -renewable=true \
    -ttl=8h \
    -max-ttl=24h
```

## Token Management Commands

### Check Token Information
```bash
# Check current token details
vault token lookup

# Check token capabilities on specific path
vault token capabilities secret/rabbitmq

# Check if token is valid
vault token lookup -self
```

### Renew Token
```bash
# Renew current token (if renewable)
vault token renew

# Renew with specific increment
vault token renew -increment=1h

# Renew another token (if you have permission)
vault token renew TOKEN_ID
```

### Revoke Token
```bash
# Revoke current token
vault token revoke -self

# Revoke specific token
vault token revoke TOKEN_ID

# Revoke all tokens created by current token
vault token revoke -mode=orphan TOKEN_ID
```

## Integration with GOK-Agent Scripts

### Using Our Vault Setup Script

```bash
# Set environment variables
export VAULT_ADDR="http://vault.vault:8200"
export VAULT_TOKEN="your-token-here"

# Check Vault status and token
./vault_rabbitmq_setup.sh status

# Store RabbitMQ credentials
./vault_rabbitmq_setup.sh store-from-k8s

# Test connectivity
./vault_rabbitmq_setup.sh test-connection
```

### Integration Test with Token
```bash
# Run tests with your token
python3 test_vault_integration.py live

# Run end-to-end tests
python3 gok_agent_test.py connectivity
```

## Environment Setup

### 1. Shell Environment
```bash
# Add to ~/.bashrc, ~/.zshrc, or ~/.profile
export VAULT_ADDR="http://vault.vault:8200"
export VAULT_TOKEN="your-token-here"
export VAULT_PATH="secret/rabbitmq"

# Reload shell configuration
source ~/.bashrc
```

### 2. Environment File
```bash
# Create vault-env.sh
cat > vault-env.sh << 'EOF'
#!/bin/bash
export VAULT_ADDR="http://vault.vault:8200"
export VAULT_TOKEN="hvs.XXXXXXXXXXXXXXXXXXXX"
export VAULT_PATH="secret/rabbitmq"

echo "Vault environment configured:"
echo "  VAULT_ADDR: $VAULT_ADDR"
echo "  VAULT_TOKEN: ${VAULT_TOKEN:0:15}..."
echo "  VAULT_PATH: $VAULT_PATH"
EOF

chmod +x vault-env.sh

# Use it
source ./vault-env.sh
```

### 3. Docker Environment
```bash
# For Docker containers
docker run -e VAULT_ADDR="http://vault:8200" \
           -e VAULT_TOKEN="your-token" \
           your-app:latest
```

### 4. Kubernetes Secrets
```yaml
# Create Kubernetes secret with Vault token
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
type: Opaque
data:
  token: <base64-encoded-token>
---
# Use in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-agent
spec:
  template:
    spec:
      containers:
      - name: agent
        env:
        - name: VAULT_TOKEN
          valueFrom:
            secretKeyRef:
              name: vault-token
              key: token
```

## Troubleshooting

### Common Token Issues

#### 1. Token Not Working
```bash
# Check if token exists and is valid
vault token lookup

# Expected output should show token details
# If you get "invalid token" or permission denied:

# Option 1: Re-authenticate
vault auth -method=userpass username=myuser

# Option 2: Check token expiration
vault token lookup -format=json | jq '.data.ttl'

# Option 3: Renew if renewable
vault token renew
```

#### 2. Permission Denied
```bash
# Check token capabilities
vault token capabilities secret/rabbitmq

# Check assigned policies
vault token lookup -format=json | jq '.data.policies'

# Verify policy exists and has correct permissions
vault policy read gok-agent-policy
```

#### 3. Connection Issues
```bash
# Test Vault connectivity
curl -k $VAULT_ADDR/v1/sys/health

# Check Vault server status
vault status

# Verify environment variables
echo "VAULT_ADDR: $VAULT_ADDR"
echo "VAULT_TOKEN: ${VAULT_TOKEN:0:10}..."
```

#### 4. Token Expired
```bash
# Check token TTL
vault token lookup -format=json | jq '.data.ttl'

# If expired, re-authenticate
vault auth -method=userpass username=myuser

# Or create new token (if you have permission)
vault token create -policy=gok-agent-policy
```

### Script-Specific Troubleshooting

#### Vault Setup Script Issues
```bash
# Enable debug mode
export VAULT_DEBUG=1
./vault_rabbitmq_setup.sh status

# Check script permissions
ls -la vault_rabbitmq_setup.sh

# Manual test
vault kv get secret/rabbitmq
```

#### Python Integration Issues
```bash
# Test Python library directly
python3 -c "
import sys
sys.path.append('.')
from vault_credentials import VaultCredentialManager
manager = VaultCredentialManager()
print('Vault status:', manager.check_vault_status())
"
```

## Security Best Practices

### 1. Token Security
- **Never log tokens**: Avoid logging full tokens in application logs
- **Use short TTLs**: Set appropriate token expiration times
- **Rotate regularly**: Implement token rotation procedures
- **Limit scope**: Use policies to restrict token capabilities

### 2. Environment Security
```bash
# Don't store tokens in version control
echo "vault-env.sh" >> .gitignore
echo ".vault-token" >> .gitignore

# Use restrictive file permissions
chmod 600 vault-env.sh

# Clear history if token was typed
history -c
```

### 3. Production Considerations
- Use Kubernetes service accounts instead of static tokens when possible
- Implement token renewal automation
- Use Vault's dynamic secrets when available
- Enable audit logging
- Monitor token usage patterns

### 4. Policy Management
```bash
# Create least-privilege policies
vault policy write gok-agent-read-only - <<EOF
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}
EOF

# Avoid using root tokens in production
# Create service-specific tokens instead
vault token create -policy=gok-agent-read-only -renewable=true
```

## Quick Reference Commands

### Development Workflow
```bash
# 1. Start Vault dev server
vault server -dev &

# 2. Set environment
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="hvs.XXXXXXXXXXXXXXXXXXXX"

# 3. Test integration
./vault_rabbitmq_setup.sh status
./vault_rabbitmq_setup.sh store-from-k8s

# 4. Run tests
python3 gok_agent_test.py connectivity
```

### Production Workflow
```bash
# 1. Authenticate
vault auth -method=userpass username=myuser

# 2. Export token
export VAULT_TOKEN=$(vault print token)

# 3. Verify permissions
vault token capabilities secret/rabbitmq

# 4. Use with applications
./vault_rabbitmq_setup.sh status
```

### Emergency Procedures
```bash
# If locked out, use recovery key (if available)
vault operator unseal

# If token expired and no auth method available
# Contact Vault administrator for new token

# Reset development environment
pkill vault
rm -rf /tmp/vault-*
vault server -dev
```

## Integration Examples

### Shell Script Integration
```bash
#!/bin/bash
# get-vault-token.sh

# Function to get Vault token based on available auth method
get_vault_token() {
    if [ -n "$VAULT_TOKEN" ]; then
        # Check if current token is valid
        if vault token lookup >/dev/null 2>&1; then
            echo "Using existing valid token"
            return 0
        fi
    fi
    
    # Try different auth methods
    if [ -n "$VAULT_USERNAME" ] && [ -n "$VAULT_PASSWORD" ]; then
        echo "Authenticating with username/password..."
        export VAULT_TOKEN=$(vault auth -method=userpass \
            username="$VAULT_USERNAME" password="$VAULT_PASSWORD" \
            -format=json | jq -r '.auth.client_token')
    elif [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
        echo "Authenticating with Kubernetes service account..."
        JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        export VAULT_TOKEN=$(vault write -field=token \
            auth/kubernetes/login role=gok-agent-role jwt=$JWT)
    else
        echo "No authentication method available"
        return 1
    fi
    
    # Verify token
    if vault token lookup >/dev/null 2>&1; then
        echo "Authentication successful"
        return 0
    else
        echo "Authentication failed"
        return 1
    fi
}

# Usage
get_vault_token && ./vault_rabbitmq_setup.sh status
```

### Python Integration
```python
#!/usr/bin/env python3
# vault_token_helper.py

import os
import subprocess
import json
import sys

def get_vault_token():
    """Get Vault token using various authentication methods"""
    
    # Check existing token
    if os.environ.get('VAULT_TOKEN'):
        if check_token_valid():
            return os.environ['VAULT_TOKEN']
    
    # Try username/password auth
    username = os.environ.get('VAULT_USERNAME')
    password = os.environ.get('VAULT_PASSWORD')
    
    if username and password:
        return auth_userpass(username, password)
    
    # Try Kubernetes auth
    if os.path.exists('/var/run/secrets/kubernetes.io/serviceaccount/token'):
        return auth_kubernetes()
    
    raise Exception("No authentication method available")

def check_token_valid():
    """Check if current token is valid"""
    try:
        result = subprocess.run(['vault', 'token', 'lookup'], 
                              capture_output=True, text=True)
        return result.returncode == 0
    except:
        return False

def auth_userpass(username, password):
    """Authenticate with username/password"""
    try:
        result = subprocess.run([
            'vault', 'auth', '-method=userpass',
            f'username={username}', f'password={password}',
            '-format=json'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            data = json.loads(result.stdout)
            token = data['auth']['client_token']
            os.environ['VAULT_TOKEN'] = token
            return token
    except Exception as e:
        raise Exception(f"Username/password auth failed: {e}")

def auth_kubernetes():
    """Authenticate with Kubernetes service account"""
    try:
        with open('/var/run/secrets/kubernetes.io/serviceaccount/token', 'r') as f:
            jwt = f.read().strip()
        
        result = subprocess.run([
            'vault', 'write', '-field=token',
            'auth/kubernetes/login',
            'role=gok-agent-role',
            f'jwt={jwt}'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            token = result.stdout.strip()
            os.environ['VAULT_TOKEN'] = token
            return token
    except Exception as e:
        raise Exception(f"Kubernetes auth failed: {e}")

if __name__ == "__main__":
    try:
        token = get_vault_token()
        print(f"Token obtained: {token[:15]}...")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
```

This comprehensive guide covers all aspects of Vault token management for your GOK-Agent integration. Use the appropriate method based on your environment and security requirements.