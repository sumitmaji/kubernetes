# Vault Kubernetes Authentication Debugging Guide

## Overview

The `debug_vault_k8s_auth.sh` script is a comprehensive debugging tool that contains all the commands and tests used to validate the Vault Kubernetes authentication setup. It replicates the exact debugging session that successfully identified and resolved authentication issues during the initial implementation.

## Quick Start

### Basic Usage
```bash
# Run all debugging steps
./debug_vault_k8s_auth.sh all

# Run specific diagnostic steps
./debug_vault_k8s_auth.sh basic
./debug_vault_k8s_auth.sh auth-config
./debug_vault_k8s_auth.sh test-auth
```

### With Custom Configuration
```bash
# Use specific Vault token
VAULT_ROOT_TOKEN=hvs.your-token ./debug_vault_k8s_auth.sh all

# Use different namespace
VAULT_NAMESPACE=my-vault ./debug_vault_k8s_auth.sh basic

# Use different service account
SERVICE_ACCOUNT=my-service-account ./debug_vault_k8s_auth.sh service-accounts
```

## Command Reference

### 1. `basic` - Basic Connectivity Checks
- ✅ Validates Vault pod status
- ✅ Checks Vault services
- ✅ Tests Vault connectivity
- ✅ Verifies Vault health and seal status
- ✅ Confirms root token access

**When to use**: Start here to verify basic Vault functionality.

### 2. `auth-config` - Authentication Configuration
- 🔍 Lists all authentication methods
- 🔍 Shows Kubernetes auth configuration  
- 🔍 Displays Vault role configuration
- 🔍 Lists Vault policies
- 🔍 Checks RabbitMQ policy
- 🔍 Verifies stored credentials

**When to use**: When authentication is failing and you need to verify configuration.

### 3. `service-accounts` - RBAC and Service Accounts
- 👤 Lists service accounts in test namespace
- 👤 Shows gok-agent service account details
- 👤 Checks vault-auth service account
- 👤 Verifies cluster role bindings
- 👤 Tests token review permissions
- 👤 Generates fresh service account tokens

**When to use**: When getting "service account not authorized" errors.

### 4. `test-auth` - Authentication Testing
- 🧪 Creates test pod with gok-agent service account
- 🧪 Tests authentication from different contexts
- 🧪 Validates JWT token structure
- 🧪 Attempts authentication with fresh tokens
- 🧪 Shows detailed error responses

**When to use**: Core authentication troubleshooting.

### 5. `troubleshoot` - Advanced Troubleshooting
- 🔧 Analyzes Vault logs for auth errors
- 🔧 Validates JWT token structure and claims
- 🔧 Checks Kubernetes API server configuration
- 🔧 Tests token reviewer configuration
- 🔧 Performs manual token review tests
- 🔧 Validates role and policy bindings

**When to use**: When basic tests pass but authentication still fails.

### 6. `credentials` - End-to-End Validation
- 🎯 Tests credential retrieval with root token
- 🎯 Validates the complete credential flow
- 🎯 Proves the integration is working

**When to use**: To confirm the end-to-end flow works regardless of auth method.

### 7. `setup` - Run Setup Script
- ⚙️ Executes the `setup_vault_k8s_auth.sh` script
- ⚙️ Applies all configuration from within Vault pod

**When to use**: To re-run the setup script during debugging.

### 8. `cleanup` - Resource Cleanup
- 🧹 Removes test pods
- 🧹 Keeps service accounts for production use

**When to use**: After debugging to clean up temporary resources.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_NAMESPACE` | `vault` | Namespace where Vault is deployed |
| `VAULT_POD` | `vault-0` | Name of the Vault pod |
| `VAULT_ROOT_TOKEN` | (auto-discover) | Vault root token for admin access |
| `TEST_NAMESPACE` | `default` | Namespace for test resources |
| `SERVICE_ACCOUNT` | `gok-agent` | Service account name for testing |
| `VAULT_ROLE` | `gok-agent` | Vault role name for authentication |

## Debugging Workflow

### Step 1: Initial Diagnosis
```bash
./debug_vault_k8s_auth.sh basic
```
Confirms Vault is running and accessible.

### Step 2: Configuration Check
```bash
./debug_vault_k8s_auth.sh auth-config
```
Verifies Vault authentication configuration.

### Step 3: RBAC Validation
```bash
./debug_vault_k8s_auth.sh service-accounts
```
Ensures service accounts and permissions are correct.

### Step 4: Authentication Testing
```bash
./debug_vault_k8s_auth.sh test-auth
```
Tests the actual authentication flow.

### Step 5: Deep Troubleshooting (if needed)
```bash
./debug_vault_k8s_auth.sh troubleshoot
```
Advanced debugging for complex issues.

### Step 6: Proof of Concept
```bash
./debug_vault_k8s_auth.sh credentials
```
Validates the end-to-end credential retrieval.

## Common Issues and Solutions

### Issue: "permission denied" Error
**Diagnosis Steps:**
1. Run `auth-config` to check role configuration
2. Run `service-accounts` to verify RBAC setup
3. Check Vault logs with `troubleshoot`

**Common Causes:**
- Missing audience parameter in Vault role
- Incorrect service account name binding
- Token reviewer JWT not configured properly

### Issue: "service account name not authorized"
**Diagnosis Steps:**
1. Run `service-accounts` to verify service account exists
2. Check role configuration with `auth-config`
3. Verify the correct service account is being used

### Issue: Connection Timeouts
**Diagnosis Steps:**
1. Run `basic` to check connectivity
2. Verify Vault service IP and ports
3. Check network policies and firewall rules

### Issue: JWT Token Problems
**Diagnosis Steps:**
1. Use `troubleshoot` to analyze token structure
2. Check audience and issuer configuration
3. Verify token reviewer permissions

## Output Interpretation

### ✅ Green Success Messages
Indicates the component is working correctly.

### ⚠️ Yellow Warning Messages  
Indicates potential issues that may need attention.

### ❌ Red Error Messages
Indicates critical failures that must be resolved.

### 🔍 Blue Info Messages
Provides informational context and status updates.

## Integration with Production

### Before Production Deployment
```bash
# Full validation
./debug_vault_k8s_auth.sh all

# Focused authentication test
./debug_vault_k8s_auth.sh test-auth

# Verify credentials work
./debug_vault_k8s_auth.sh credentials
```

### During Production Issues
```bash
# Quick health check
./debug_vault_k8s_auth.sh basic

# Authentication troubleshooting
./debug_vault_k8s_auth.sh test-auth troubleshoot
```

### After Configuration Changes
```bash
# Verify configuration
./debug_vault_k8s_auth.sh auth-config

# Test authentication
./debug_vault_k8s_auth.sh test-auth
```

## Script Maintenance

### Adding New Debug Steps
1. Add new function following the existing pattern
2. Update the `main()` function case statement
3. Add documentation in `show_usage()`
4. Update this guide

### Customizing for Different Environments
- Modify default environment variables
- Adjust namespace and service names
- Update Vault configuration paths
- Customize authentication methods

## Historical Context

This script was created during the successful debugging session that resolved initial Vault Kubernetes authentication issues. It contains the exact sequence of commands that:

1. ✅ Identified missing audience configuration
2. ✅ Resolved token reviewer setup issues  
3. ✅ Validated service account permissions
4. ✅ Confirmed end-to-end credential retrieval
5. ✅ Proved the integration concept works

The script serves as both a debugging tool and documentation of the successful troubleshooting methodology.

## See Also

- `setup_vault_k8s_auth.sh` - Initial setup script
- `test_vault_k8s_e2e.sh` - End-to-end testing script
- `IMPLEMENTATION_COMPLETE.md` - Complete project documentation
- `TROUBLESHOOTING.md` - Detailed troubleshooting guide