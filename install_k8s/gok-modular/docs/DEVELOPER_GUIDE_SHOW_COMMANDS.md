# Developer Guide: Adding --show-commands Support

## Overview
This guide explains how to add `--show-commands` support to all component installations in the GOK modular system.

## Quick Start

### For Commands Already Using `execute_with_suppression()`
✅ **No changes needed!** These commands automatically show up when `--show-commands` is enabled.

```bash
# This already works:
execute_with_suppression kubectl apply -f manifest.yaml
execute_with_suppression helm repo add myrepo https://...
```

### For Direct Command Executions
Use the helper functions to show commands before execution.

## Helper Functions

### 1. `show_command` - Display any command
Use this for non-sensitive commands:

```bash
# Before:
docker build -t myimage .

# After:
show_command "docker build -t myimage ."
docker build -t myimage .
```

### 2. `show_command_with_secrets` - Display with masked secrets
Use this for commands containing passwords, tokens, or sensitive data:

```bash
# Basic usage - mask one secret:
show_command_with_secrets \
    "helm install myapp --set password=$PASSWORD" \
    "$PASSWORD" "***"

# Mask multiple secrets:
show_command_with_secrets \
    "kubectl create secret generic mysecret --from-literal=password=$PASS --from-literal=token=$TOKEN" \
    "$PASS" "***" \
    "$TOKEN" "***"
```

## Common Patterns

### Docker Build
```bash
# Show the build command with masked secrets
show_command_with_secrets \
    "docker build --build-arg API_KEY=\"$API_KEY\" -t \"$IMAGE_NAME\" ." \
    "$API_KEY" "***"

docker build \
    --build-arg API_KEY="$API_KEY" \
    -t "$IMAGE_NAME" . >"$BUILD_LOG" 2>"$ERROR_LOG" &
```

### Docker Tag
```bash
show_command "docker tag \"$SOURCE_IMAGE\" \"$TARGET_IMAGE\""
docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"
```

### Docker Push
```bash
show_command "docker push \"$IMAGE_URL\""
docker push "$IMAGE_URL" >"$PUSH_LOG" 2>"$ERROR_LOG" &
```

### Helm Install/Upgrade
```bash
# With secrets
show_command_with_secrets \
    "helm upgrade --install $RELEASE_NAME ./chart --set adminPassword=\"$ADMIN_PASS\" --set dbPassword=\"$DB_PASS\"" \
    "$ADMIN_PASS" "***" \
    "$DB_PASS" "***"

helm upgrade --install "$RELEASE_NAME" ./chart \
    --set adminPassword="$ADMIN_PASS" \
    --set dbPassword="$DB_PASS"
```

```bash
# Without secrets
show_command "helm upgrade --install $RELEASE_NAME ./chart --namespace $NAMESPACE"
helm upgrade --install "$RELEASE_NAME" ./chart --namespace "$NAMESPACE"
```

### Helm Repo Operations
```bash
show_command "helm repo add $REPO_NAME $REPO_URL"
execute_with_suppression helm repo add "$REPO_NAME" "$REPO_URL"

show_command "helm repo update"
execute_with_suppression helm repo update
```

### Kubectl Apply
```bash
show_command "kubectl apply -f $MANIFEST_FILE"
kubectl apply -f "$MANIFEST_FILE"
```

### Kubectl Create Namespace
```bash
show_command "kubectl create namespace $NAMESPACE"
execute_with_suppression kubectl create namespace "$NAMESPACE"
```

### Kubectl Create Secret
```bash
show_command_with_secrets \
    "kubectl create secret generic $SECRET_NAME --from-literal=password=$PASSWORD --namespace $NAMESPACE" \
    "$PASSWORD" "***"

kubectl create secret generic "$SECRET_NAME" \
    --from-literal=password="$PASSWORD" \
    --namespace "$NAMESPACE"
```

### Script Execution
```bash
show_command "bash $SCRIPT_PATH --arg1 $VALUE1 --arg2 $VALUE2"
bash "$SCRIPT_PATH" --arg1 "$VALUE1" --arg2 "$VALUE2"
```

### Source Files
```bash
show_command "source $CONFIG_FILE"
source "$CONFIG_FILE"
```

## Complete Example: Component Installation

Here's a complete example showing how to add `--show-commands` support to a component:

```bash
#!/bin/bash

# Component installation function
myComponentInst() {
    local password="$1"
    local api_key="$2"
    
    log_info "Installing My Component..."
    
    # Step 1: Build Docker image
    log_info "Building Docker image..."
    show_command_with_secrets \
        "docker build --build-arg PASSWORD=\"$password\" -t mycomponent:latest ." \
        "$password" "***"
    
    docker build \
        --build-arg PASSWORD="$password" \
        -t mycomponent:latest . >"$BUILD_LOG" 2>&1
    
    # Step 2: Tag image
    local registry_url="registry.example.com"
    local full_image_url="${registry_url}/mycomponent:latest"
    
    show_command "docker tag mycomponent:latest \"$full_image_url\""
    docker tag mycomponent:latest "$full_image_url"
    
    # Step 3: Push image
    show_command "docker push \"$full_image_url\""
    docker push "$full_image_url" >"$PUSH_LOG" 2>&1
    
    # Step 4: Create namespace (using execute_with_suppression)
    execute_with_suppression kubectl create namespace mycomponent
    
    # Step 5: Create secrets
    show_command_with_secrets \
        "kubectl create secret generic mycomponent-secrets --from-literal=password=$password --from-literal=apiKey=$api_key" \
        "$password" "***" \
        "$api_key" "***"
    
    kubectl create secret generic mycomponent-secrets \
        --from-literal=password="$password" \
        --from-literal=apiKey="$api_key" \
        --namespace mycomponent
    
    # Step 6: Deploy with Helm
    show_command_with_secrets \
        "helm upgrade --install mycomponent ./chart --set adminPassword=\"$password\" --set apiKey=\"$api_key\"" \
        "$password" "***" \
        "$api_key" "***"
    
    helm upgrade --install mycomponent ./chart \
        --namespace mycomponent \
        --set adminPassword="$password" \
        --set apiKey="$api_key"
    
    log_success "My Component installed successfully"
}

export -f myComponentInst
```

## Testing

Test your changes with:

```bash
# Test with --show-commands flag
./gok-new install mycomponent --show-commands

# Test with verbose mode (auto-enables show-commands)
./gok-new install mycomponent --verbose

# Test with environment variable
GOK_SHOW_COMMANDS=true ./gok-new install mycomponent
```

## Expected Output

When `--show-commands` is enabled, you should see:

```
ℹ Executing: docker build --build-arg PASSWORD="***" -t mycomponent:latest .
🐳 Building Docker image...
ℹ Executing: docker tag mycomponent:latest "registry.example.com/mycomponent:latest"
ℹ Executing: docker push "registry.example.com/mycomponent:latest"
ℹ Executing: kubectl create namespace mycomponent
ℹ Executing: kubectl create secret generic mycomponent-secrets --from-literal=password=*** --from-literal=apiKey=***
ℹ Executing: helm upgrade --install mycomponent ./chart --set adminPassword="***" --set apiKey="***"
```

## Components That Need Updates

### High Priority
- [ ] Docker installation (`lib/components/infrastructure/docker.sh`)
- [ ] Kubernetes installation (`lib/components/infrastructure/kubernetes.sh`)
- [ ] Helm installation (`lib/components/infrastructure/helm.sh`)
- [ ] Cert-Manager (`lib/components/security/cert-manager.sh`)
- [ ] Keycloak (`lib/components/security/keycloak.sh`)
- [ ] Vault (`lib/components/security/vault.sh`)
- [ ] Monitoring stack (`lib/components/monitoring/prometheus-grafana.sh`)

### Medium Priority
- [ ] ArgoCD (`lib/components/cicd/argocd.sh`)
- [ ] Jenkins (`lib/components/cicd/jenkins.sh`)
- [ ] Registry (`lib/components/cicd/registry.sh`)
- [ ] Dashboard (`lib/components/development/dashboard.sh`)
- [ ] JupyterHub (`lib/components/development/jupyter.sh`)

### Low Priority
- [ ] All other components

## Checklist for Each Component

When updating a component, verify:

- [ ] All `docker build` commands show with masked secrets
- [ ] All `docker tag` commands show
- [ ] All `docker push` commands show
- [ ] All `helm upgrade --install` commands show with masked secrets
- [ ] All `helm repo add/update` commands show
- [ ] All direct `kubectl` commands show (or use `execute_with_suppression`)
- [ ] All shell script executions show
- [ ] All sensitive data (passwords, tokens, keys) is masked with `***`
- [ ] Test with `--show-commands` flag
- [ ] Test with `--verbose` flag
- [ ] Test with `GOK_SHOW_COMMANDS=true` environment variable

## Best Practices

### DO:
✅ Use `show_command_with_secrets` for any command with sensitive data
✅ Mask all passwords, tokens, API keys, and certificates
✅ Show the command right before execution
✅ Use `execute_with_suppression` when possible (it handles this automatically)
✅ Test your changes with different verbosity levels

### DON'T:
❌ Display passwords or secrets in plain text
❌ Skip showing commands that modify the system
❌ Show commands after they execute (show before)
❌ Forget to export helper functions if creating new utility files

## Security Notes

**CRITICAL**: Always mask sensitive data in displayed commands:

```bash
# WRONG - exposes password
show_command "mysql -u root -p$PASSWORD"

# CORRECT - masks password
show_command_with_secrets "mysql -u root -p$PASSWORD" "$PASSWORD" "***"
```

**Common sensitive data to mask:**
- Passwords (`--password`, `-p`, `--set password=`)
- API keys (`--api-key`, `--token`, `APIKEY=`)
- Certificates and private keys
- Database connection strings with credentials
- OAuth tokens and secrets
- SSH keys and passphrases
- Encryption keys

## Troubleshooting

### Commands not showing
```bash
# Verify the flag is set
echo "GOK_SHOW_COMMANDS: $GOK_SHOW_COMMANDS"

# Verify the function is available
declare -f show_command
```

### Secrets still visible
```bash
# Make sure you're using show_command_with_secrets, not show_command
# Verify all secret values are passed as arguments
```

## Integration with Existing Code

The helper functions are already exported from `lib/utils/execution.sh` and available in all components. Simply use them directly:

```bash
# No need to source or import - already available
show_command "your command here"
show_command_with_secrets "command with $SECRET" "$SECRET" "***"
```

## Conclusion

Adding `--show-commands` support is straightforward:
1. For `execute_with_suppression` calls: Already works! ✅
2. For direct commands: Add `show_command` or `show_command_with_secrets` before execution
3. Always mask sensitive data with `show_command_with_secrets`
4. Test with `--show-commands`, `--verbose`, and environment variable

This provides transparency and debugging capabilities while maintaining security.
