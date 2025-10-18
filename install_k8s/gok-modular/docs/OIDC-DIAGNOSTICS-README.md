# GOK OIDC Diagnostics and Fix Script

This script automates the diagnosis and fixing of OIDC authentication issues between gok-login and Kubernetes clusters.

## Overview

The script performs comprehensive diagnostics of OIDC authentication setup and can automatically apply fixes for common issues, particularly the missing OIDC CA file configuration that prevents the Kubernetes API server from validating Keycloak certificates.

## Usage

```bash
# Run full diagnostic suite (recommended)
./oidc-diagnostics.sh

# Or run specific diagnostic checks
./oidc-diagnostics.sh diagnose

# Check specific components
./oidc-diagnostics.sh check-rbac      # Check cluster role bindings
./oidc-diagnostics.sh check-config    # Check API server OIDC config
./oidc-diagnostics.sh check-logs      # Check API server logs
./oidc-diagnostics.sh check-certs     # Check certificates
./oidc-diagnostics.sh test-api        # Test API authentication
./oidc-diagnostics.sh test-kubectl    # Test kubectl authentication

# Apply fixes
./oidc-diagnostics.sh fix-ca          # Fix OIDC CA file configuration

# Show help
./oidc-diagnostics.sh help
```

## What It Diagnoses

### 1. Cluster Role Bindings
- Checks for admin/developer/group related role bindings
- Verifies specific role bindings for "administrators" and "developers" groups
- Ensures proper RBAC permissions are configured

### 2. API Server OIDC Configuration
- Verifies OIDC client ID, issuer URL, and username/group claim settings
- Checks for OIDC CA file configuration
- Validates API server manifest settings

### 3. Certificate Validation
- Locates certificates in the Kubernetes directory
- Finds gok/keycloak/selfsign related files
- Verifies the issuer.crt CA certificate details

### 4. Authentication Testing
- Tests direct API calls with JWT tokens
- Tests kubectl authentication with tokens
- Validates end-to-end OIDC flow

## Common Issues Fixed

### OIDC CA File Missing
**Problem**: API server logs show "tls: failed to verify certificate" errors
**Solution**: Automatically adds `--oidc-ca-file=/usr/local/share/ca-certificates/issuer.crt` to API server configuration

### RBAC Permissions
**Problem**: Authentication works but access is denied
**Solution**: Identifies missing ClusterRoleBindings for user groups

### Certificate Issues
**Problem**: Keycloak certificates not trusted
**Solution**: Ensures proper CA certificate configuration

## Configuration

The script is pre-configured for your environment:

- **Remote Host**: 10.0.0.244
- **Remote User**: sumit
- **Kubernetes API**: https://10.0.0.244:6443
- **Keycloak Realm**: https://keycloak.gokcloud.com/realms/GokDevelopers
- **CA Certificate**: /usr/local/share/ca-certificates/issuer.crt

## Output

The script provides color-coded output:
- 🔵 **INFO**: General information and progress
- 🟢 **SUCCESS**: Successful operations
- 🟡 **WARNING**: Potential issues or recommendations
- 🔴 **ERROR**: Failures or problems requiring attention

## Automated Fixes

When issues are detected, the script can automatically apply fixes:

1. **OIDC CA File**: Adds missing CA file configuration to API server
2. **Configuration Backup**: Creates timestamped backups before making changes
3. **Verification**: Tests fixes to ensure they work

## Troubleshooting

### Script Won't Run
```bash
chmod +x oidc-diagnostics.sh
```

### Remote Connection Issues
Ensure `./gok-new remote exec` works and you have SSH access to the remote host.

### API Server Won't Restart
The API server should restart automatically when the manifest changes. If not:
```bash
kubectl delete pod kube-apiserver-master.cloud.com -n kube-system
```

### Certificate Issues Persist
Verify the CA certificate is correct:
```bash
openssl x509 -in /usr/local/share/ca-certificates/issuer.crt -text -noout
```

## Integration with gok-new

This script integrates with your existing gok-new remote execution system and can be run from your local development environment to diagnose and fix remote Kubernetes clusters.

## Example Output

```
================================================
GOK OIDC Authentication Diagnostics
================================================

================================================
Checking Cluster Role Bindings
================================================
[INFO] Looking for admin/developer/group related role bindings...
[INFO] ℹ Executing on default remote (sumit@10.0.0.244): sudo bash -c "kubectl get clusterrolebinding | grep -E '(admin|developer|group)'"
NAME                                                   ROLE                 AGE
cluster-admin                                          ClusterRole/cluster-admin  2d4h
...
[SUCCESS] OIDC CA file is already configured
[SUCCESS] API authentication test PASSED
[SUCCESS] kubectl authentication test passed

================================================
Diagnostic Summary
================================================
Issues found: 0
Fixes applied: 0
[SUCCESS] All OIDC authentication checks passed!
```

## Security Notes

- The script contains a test JWT token for diagnostic purposes
- In production, ensure tokens are properly rotated and not hardcoded
- The script requires SSH access to the remote Kubernetes nodes
- API server configuration changes require appropriate permissions