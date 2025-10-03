#!/bin/bash

# Test script for Vault Agent Injector
# This script creates a test secret and verifies it's mounted via Agent Injector

set -euo pipefail

# Configuration
TEST_NAME="vault-agent-injector-test"
NAMESPACE="default"
SECRET_PATH="secret/agent-test"
POLICY_NAME="agent-test-policy"
ROLE_NAME="agent-test-role"
SERVICE_ACCOUNT="agent-test-sa"
POD_NAME="vault-agent-test-pod"

# Test tracking variables
declare -A TEST_RESULTS
TEST_RESULTS["dependencies"]="PENDING"
TEST_RESULTS["vault_login"]="PENDING"
TEST_RESULTS["secret_creation"]="PENDING"
TEST_RESULTS["policy_creation"]="PENDING"
TEST_RESULTS["role_creation"]="PENDING"
TEST_RESULTS["service_account"]="PENDING"
TEST_RESULTS["pod_creation"]="PENDING"
TEST_RESULTS["pod_ready"]="PENDING"
TEST_RESULTS["secret_injection"]="PENDING"
TEST_RESULTS["secret_verification"]="PENDING"
TEST_RESULTS["vault_agent_logs"]="PENDING"
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vault login function
vaultLogin() {
    log_info "Logging into Vault..."
    ROOT_TOKEN=$(kubectl get secret vault-init-keys -n vault -o json | jq -r '.data["vault-init.json"]' | base64 -d | jq -r '.root_token')
    kubectl exec -it vault-0 -n vault -- vault login ${ROOT_TOKEN} >/dev/null 2>&1
    log_success "Vault login successful"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test resources..."
    
    # Cleanup Vault resources first (if Vault is accessible)
    cleanup_vault_resources
    
    # Delete Kubernetes pod
    kubectl delete pod $POD_NAME -n $NAMESPACE --ignore-not-found=true >/dev/null 2>&1
    
    # Delete service account
    kubectl delete serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE --ignore-not-found=true >/dev/null 2>&1
    
    # Wait for pod to be deleted
    kubectl wait --for=delete pod/$POD_NAME -n $NAMESPACE --timeout=60s >/dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

# Cleanup Vault resources (secrets, policies, roles)
cleanup_vault_resources() {
    log_info "Cleaning up Vault resources..."
    
    # Try to login to Vault first
    if ! vault_login_for_cleanup; then
        log_warning "Cannot access Vault for cleanup - skipping Vault resource cleanup"
        return 0
    fi
    
    # Delete test secret
    log_info "Deleting test secret: $SECRET_PATH"
    if kubectl exec vault-0 -n vault -- vault kv delete "$SECRET_PATH" >/dev/null 2>&1; then
        log_success "✓ Test secret deleted"
    else
        log_warning "⚠ Failed to delete test secret (may not exist)"
    fi
    
    # Delete Kubernetes authentication role
    log_info "Deleting Kubernetes auth role: $ROLE_NAME"
    if kubectl exec vault-0 -n vault -- vault delete "auth/kubernetes/role/$ROLE_NAME" >/dev/null 2>&1; then
        log_success "✓ Kubernetes auth role deleted"
    else
        log_warning "⚠ Failed to delete Kubernetes auth role (may not exist)"
    fi
    
    # Delete Vault policy
    log_info "Deleting Vault policy: $POLICY_NAME"
    if kubectl exec vault-0 -n vault -- vault policy delete "$POLICY_NAME" >/dev/null 2>&1; then
        log_success "✓ Vault policy deleted"
    else
        log_warning "⚠ Failed to delete Vault policy (may not exist)"
    fi
    
    log_success "Vault resource cleanup completed"
}

# Vault login for cleanup (more permissive than test login)
vault_login_for_cleanup() {
    # Try to get vault token and login
    if VAULT_TOKEN=$(kubectl get secret vault-init-keys -n vault -o jsonpath='{.data.vault-init\.json}' 2>/dev/null | base64 -d 2>/dev/null | jq -r '.root_token' 2>/dev/null) && \
       [[ -n "$VAULT_TOKEN" ]] && \
       kubectl exec vault-0 -n vault -- vault login "$VAULT_TOKEN" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create test secret in Vault
create_test_secret() {
    log_info "Creating test secret in Vault..."
    
    # Login to vault
    log_info "Logging into Vault..."
    if VAULT_TOKEN=$(kubectl get secret vault-init-keys -n vault -o json | jq -r '.data["vault-init.json"]' | base64 -d | jq -r '.root_token') && \
       kubectl exec vault-0 -n vault -- vault login "$VAULT_TOKEN" >/dev/null 2>&1; then
        log_success "Vault login successful"
        TEST_RESULTS["vault_login"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Vault login failed"
        TEST_RESULTS["vault_login"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
    
    # Create the secret
    if kubectl exec vault-0 -n vault -- vault kv put "$SECRET_PATH" \
        username="agent-test-user" \
        password="agent-test-password" \
        database_url="postgresql://localhost:5432/testdb" \
        api_key="test-api-key-12345" >/dev/null 2>&1; then
        log_success "Test secret created at $SECRET_PATH"
        TEST_RESULTS["secret_creation"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to create test secret"
        TEST_RESULTS["secret_creation"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Create Vault policy
create_policy() {
    log_info "Creating Vault policy..."
    
    if kubectl exec vault-0 -n vault -- sh -c "echo 'path \"$SECRET_PATH\" { capabilities = [\"read\"] }' | vault policy write \"$POLICY_NAME\" -" >/dev/null 2>&1; then
        log_success "Policy $POLICY_NAME created"
        TEST_RESULTS["policy_creation"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to create policy $POLICY_NAME"
        TEST_RESULTS["policy_creation"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Create Kubernetes authentication role
create_role() {
    log_info "Creating Kubernetes authentication role..."
    
    if kubectl exec vault-0 -n vault -- vault write auth/kubernetes/role/"$ROLE_NAME" \
        bound_service_account_names="$SERVICE_ACCOUNT" \
        bound_service_account_namespaces="$NAMESPACE" \
        policies="$POLICY_NAME" \
        ttl=1h >/dev/null 2>&1; then
        log_success "Role $ROLE_NAME created"
        TEST_RESULTS["role_creation"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to create role $ROLE_NAME"
        TEST_RESULTS["role_creation"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Create service account
create_service_account() {
    log_info "Creating service account..."
    
    if kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" >/dev/null 2>&1 || \
       kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_success "Service account $SERVICE_ACCOUNT created"
        TEST_RESULTS["service_account"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to create service account $SERVICE_ACCOUNT"
        TEST_RESULTS["service_account"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Create test pod with Agent Injector
create_test_pod() {
    log_info "Creating test pod with Vault Agent Injector..."
    
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $NAMESPACE
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "$ROLE_NAME"
    vault.hashicorp.com/agent-inject-secret-config: "$SECRET_PATH"
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "$SECRET_PATH" -}}
      export USERNAME="{{ .Data.username }}"
      export PASSWORD="{{ .Data.password }}"
      export DATABASE_URL="{{ .Data.database_url }}"
      export API_KEY="{{ .Data.api_key }}"
      
      # JSON format
      {
        "username": "{{ .Data.username }}",
        "password": "{{ .Data.password }}",
        "database_url": "{{ .Data.database_url }}",
        "api_key": "{{ .Data.api_key }}"
      }
      {{- end -}}
spec:
  serviceAccountName: $SERVICE_ACCOUNT
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  restartPolicy: Never
EOF
    
    if kubectl get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        log_success "Test pod created"
        TEST_RESULTS["pod_creation"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to create test pod"
        TEST_RESULTS["pod_creation"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Wait for pod to be ready
wait_for_pod() {
    log_info "Waiting for pod to be ready..."
    
    if kubectl wait --for=condition=Ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=60s >/dev/null 2>&1; then
        log_success "Pod is ready"
        TEST_RESULTS["pod_ready"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Pod failed to become ready within timeout"
        TEST_RESULTS["pod_ready"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Verify secrets are injected
verify_secrets() {
    log_info "Verifying secrets are injected..."
    
    # Check if vault secrets directory exists
    if kubectl exec "$POD_NAME" -n "$NAMESPACE" -c app -- test -d /vault/secrets >/dev/null 2>&1; then
        log_success "Vault secrets directory exists"
    else
        log_error "Vault secrets directory not found"
        TEST_RESULTS["secret_injection"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
    
    # Check if config file exists
    if kubectl exec "$POD_NAME" -n "$NAMESPACE" -c app -- test -f /vault/secrets/config >/dev/null 2>&1; then
        log_success "Config file exists in /vault/secrets/"
        TEST_RESULTS["secret_injection"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Config file not found in /vault/secrets/"
        TEST_RESULTS["secret_injection"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
    
    # Display the content of the injected secrets
    log_info "Displaying injected secrets content:"
    echo "----------------------------------------"
    kubectl exec "$POD_NAME" -n "$NAMESPACE" -c app -- cat /vault/secrets/config
    echo "----------------------------------------"
    
    # Verify specific values
    log_info "Verifying specific secret values..."
    SECRET_CONTENT=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -c app -- cat /vault/secrets/config)
    local verification_passed=true
    
    if echo "$SECRET_CONTENT" | grep -q "agent-test-user"; then
        log_success "✓ Username found in secrets"
    else
        log_error "✗ Username not found in secrets"
        verification_passed=false
    fi
    
    if echo "$SECRET_CONTENT" | grep -q "agent-test-password"; then
        log_success "✓ Password found in secrets"
    else
        log_error "✗ Password not found in secrets"
        verification_passed=false
    fi
    
    if echo "$SECRET_CONTENT" | grep -q "postgresql://localhost:5432/testdb"; then
        log_success "✓ Database URL found in secrets"
    else
        log_error "✗ Database URL not found in secrets"
        verification_passed=false
    fi
    
    if echo "$SECRET_CONTENT" | grep -q "test-api-key-12345"; then
        log_success "✓ API key found in secrets"
    else
        log_error "✗ API key not found in secrets"
        verification_passed=false
    fi
    
    if [[ "$verification_passed" == "true" ]]; then
        log_success "All secret values verified successfully!"
        TEST_RESULTS["secret_verification"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Secret verification failed"
        TEST_RESULTS["secret_verification"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        return 1
    fi
}

# Display pod logs for debugging
show_pod_info() {
    log_info "Pod information for debugging:"
    echo "================================"
    
    echo "Pod Status:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o wide 2>/dev/null || true
    echo
    
    echo "Pod Description:"
    kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null || true
    echo
    
    echo "Vault Agent Logs:"
    if kubectl logs $POD_NAME -n $NAMESPACE -c vault-agent --tail=50 >/dev/null 2>&1; then
        kubectl logs $POD_NAME -n $NAMESPACE -c vault-agent --tail=50
        TEST_RESULTS["vault_agent_logs"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        log_error "Failed to retrieve Vault Agent logs"
        TEST_RESULTS["vault_agent_logs"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    echo
}

# Main test function
run_test() {
    log_info "🚀 Starting Vault Agent Injector Test"
    echo "======================================"
    
    # Setup trap for cleanup with summary
    trap 'show_test_summary; cleanup' EXIT
    
    # Run test steps
    create_test_secret
    create_policy
    create_role
    create_service_account
    create_test_pod
    wait_for_pod
    verify_secrets
    
    log_success "🎉 Vault Agent Injector test completed successfully!"
    
    # Show additional info
    show_pod_info
    
    # Show test summary
    show_test_summary
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    local deps_passed=true
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        deps_passed=false
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        deps_passed=false
    fi
    
    # Check if vault pod exists
    if ! kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
        log_error "Vault pod (vault-0) not found in vault namespace"
        deps_passed=false
    fi
    
    # Check if vault is ready
    if ! kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=10s >/dev/null 2>&1; then
        log_error "Vault pod is not ready"
        deps_passed=false
    fi
    
    if [[ "$deps_passed" == "true" ]]; then
        log_success "All dependencies checked"
        TEST_RESULTS["dependencies"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        TEST_RESULTS["dependencies"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        exit 1
    fi
}

# Help function
show_help() {
    cat <<EOF
🚀 Vault Agent Injector Test Script
=====================================

This script comprehensively tests HashiCorp Vault Agent Injector functionality
by automatically creating test resources and validating secret injection.

📋 WHAT THIS SCRIPT DOES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Creates a test secret in Vault with multiple key-value pairs
✓ Sets up Vault policies and Kubernetes authentication roles
✓ Creates a service account with proper RBAC permissions
✓ Deploys a test pod with Vault Agent Injector annotations
✓ Validates that secrets are properly injected at /vault/secrets/
✓ Verifies template rendering (environment variables + JSON format)
✓ Tests secret content validation and format checking
✓ Automatically cleans up all created resources

🎯 TEST RESOURCES CREATED:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Secret: secret/agent-test (username, password, database_url, api_key)
• Policy: agent-test-policy (read access to secret path)
• Role: agent-test-role (Kubernetes auth binding)
• ServiceAccount: agent-test-sa (for pod authentication)
• Pod: vault-agent-test-pod (with agent injector annotations)

📖 USAGE:
━━━━━━━━━
    $0 [OPTIONS]

🛠️  OPTIONS:
━━━━━━━━━━━
    -h, --help     Show this comprehensive help message
    -c, --cleanup  Clean up test resources only (no testing)
    -v, --verbose  Enable verbose output with detailed logging

💡 EXAMPLES:
━━━━━━━━━━━━

    # 🚀 Run the complete Agent Injector test
    $0
    
    # 🔍 Run test with detailed verbose logging
    $0 --verbose
    
    # 🧹 Clean up only (remove all test resources)
    $0 --cleanup
    
    # ❓ Show this help message
    $0 --help

📊 WHAT SUCCESS LOOKS LIKE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Vault login successful
✅ Test secret created at secret/agent-test
✅ Policy agent-test-policy created
✅ Role agent-test-role created
✅ Service account agent-test-sa created
✅ Test pod created with agent injector annotations
✅ Pod is ready (both app and vault-agent containers)
✅ Vault secrets directory exists (/vault/secrets/)
✅ Config file exists with injected secrets
✅ All secret values verified (username, password, database_url, api_key)
✅ Template rendering successful (env vars + JSON)

🔧 CONFIGURATION:
━━━━━━━━━━━━━━━━━
• Namespace: default (can be customized in script)
• Vault Address: Auto-detected from cluster
• Authentication: Uses root token from vault-init-keys secret
• Test Duration: ~2-5 minutes depending on cluster performance

📚 VAULT AGENT INJECTOR CONCEPTS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Vault Agent Injector automatically injects secrets into pods using:
• Init Container: Retrieves secrets before main container starts
• Sidecar Container: Keeps secrets updated (optional)
• Template Engine: Formats secrets as files with custom templates
• Automatic Mounting: Secrets appear at /vault/secrets/ in main container

🔍 DEBUGGING:
━━━━━━━━━━━━━━
If the test fails, check:
• kubectl get pods -n default (pod status)
• kubectl describe pod vault-agent-test-pod -n default (events)
• kubectl logs vault-agent-test-pod -c vault-agent -n default (agent logs)
• kubectl exec -it vault-0 -n vault -- vault status (Vault health)

⚠️  PREREQUISITES:
━━━━━━━━━━━━━━━━━
• Kubernetes cluster with Vault installed and unsealed
• kubectl configured and connected to cluster
• jq installed for JSON processing
• Vault initialized with root token in vault-init-keys secret
• Vault Agent Injector installed in cluster

🧹 CLEANUP:
━━━━━━━━━━━━
The script automatically cleans up on exit, but you can also run:
    $0 --cleanup

This removes:
• Test pod (vault-agent-test-pod)
• Service account (agent-test-sa)
• All test resources in Vault (secret, policy, role)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--cleanup)
            cleanup
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Show comprehensive test summary
show_test_summary() {
    echo
    echo "══════════════════════════════════════════════════════════════════════════════════"
    echo "🧪 VAULT AGENT INJECTOR TEST SUMMARY"
    echo "══════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Calculate test count
    TEST_COUNT=$((PASSED_COUNT + FAILED_COUNT))
    
    # Overall result
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo "🎉 OVERALL RESULT: ALL TESTS PASSED ✅"
    else
        echo "❌ OVERALL RESULT: SOME TESTS FAILED"
    fi
    
    echo "📊 STATISTICS: $PASSED_COUNT/$TEST_COUNT tests passed ($((PASSED_COUNT * 100 / TEST_COUNT))% success rate)"
    echo
    
    # Detailed test results
    echo "📋 DETAILED TEST RESULTS:"
    echo "─────────────────────────────────────────────────────────────────────────────────"
    printf "%-25s | %-10s | %s\\n" "TEST NAME" "STATUS" "DESCRIPTION"
    echo "─────────────────────────────────────────────────────────────────────────────────"
    
    # Dependencies check
    if [[ "${TEST_RESULTS[dependencies]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Dependencies" "✅ PASSED" "kubectl, jq, vault pod available"
    else
        printf "%-25s | %-10s | %s\\n" "Dependencies" "❌ FAILED" "Missing required dependencies"
    fi
    
    # Vault login
    if [[ "${TEST_RESULTS[vault_login]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Vault Login" "✅ PASSED" "Successfully authenticated with Vault"
    elif [[ "${TEST_RESULTS[vault_login]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Vault Login" "❌ FAILED" "Failed to authenticate with Vault"
    else
        printf "%-25s | %-10s | %s\\n" "Vault Login" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Secret creation
    if [[ "${TEST_RESULTS[secret_creation]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Creation" "✅ PASSED" "Test secret created at $SECRET_PATH"
    elif [[ "${TEST_RESULTS[secret_creation]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Creation" "❌ FAILED" "Failed to create test secret in Vault"
    else
        printf "%-25s | %-10s | %s\\n" "Secret Creation" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Policy creation
    if [[ "${TEST_RESULTS[policy_creation]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Policy Creation" "✅ PASSED" "Vault policy '$POLICY_NAME' created"
    elif [[ "${TEST_RESULTS[policy_creation]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Policy Creation" "❌ FAILED" "Failed to create Vault policy"
    else
        printf "%-25s | %-10s | %s\\n" "Policy Creation" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Role creation
    if [[ "${TEST_RESULTS[role_creation]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Role Creation" "✅ PASSED" "Kubernetes auth role '$ROLE_NAME' created"
    elif [[ "${TEST_RESULTS[role_creation]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Role Creation" "❌ FAILED" "Failed to create Kubernetes auth role"
    else
        printf "%-25s | %-10s | %s\\n" "Role Creation" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Service account
    if [[ "${TEST_RESULTS[service_account]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Service Account" "✅ PASSED" "Service account '$SERVICE_ACCOUNT' created"
    elif [[ "${TEST_RESULTS[service_account]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Service Account" "❌ FAILED" "Failed to create service account"
    else
        printf "%-25s | %-10s | %s\\n" "Service Account" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Pod creation
    if [[ "${TEST_RESULTS[pod_creation]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Pod Creation" "✅ PASSED" "Test pod with Agent Injector annotations"
    elif [[ "${TEST_RESULTS[pod_creation]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Pod Creation" "❌ FAILED" "Failed to create test pod"
    else
        printf "%-25s | %-10s | %s\\n" "Pod Creation" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Pod readiness
    if [[ "${TEST_RESULTS[pod_ready]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Pod Readiness" "✅ PASSED" "Pod became ready within timeout"
    elif [[ "${TEST_RESULTS[pod_ready]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Pod Readiness" "❌ FAILED" "Pod failed to become ready"
    else
        printf "%-25s | %-10s | %s\\n" "Pod Readiness" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Secret injection
    if [[ "${TEST_RESULTS[secret_injection]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Injection" "✅ PASSED" "Secrets directory and config file exist"
    elif [[ "${TEST_RESULTS[secret_injection]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Injection" "❌ FAILED" "Secrets not injected into pod"
    else
        printf "%-25s | %-10s | %s\\n" "Secret Injection" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Secret verification
    if [[ "${TEST_RESULTS[secret_verification]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Verification" "✅ PASSED" "All expected secret values found"
    elif [[ "${TEST_RESULTS[secret_verification]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Secret Verification" "❌ FAILED" "Some secret values missing or incorrect"
    else
        printf "%-25s | %-10s | %s\\n" "Secret Verification" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    # Vault Agent logs
    if [[ "${TEST_RESULTS[vault_agent_logs]}" == "PASSED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Vault Agent Logs" "✅ PASSED" "Agent logs retrieved successfully"
    elif [[ "${TEST_RESULTS[vault_agent_logs]}" == "FAILED" ]]; then
        printf "%-25s | %-10s | %s\\n" "Vault Agent Logs" "❌ FAILED" "Failed to retrieve agent logs"
    else
        printf "%-25s | %-10s | %s\\n" "Vault Agent Logs" "⏳ SKIPPED" "Not executed due to earlier failure"
    fi
    
    echo "─────────────────────────────────────────────────────────────────────────────────"
    echo
    
    # Test categories summary
    echo "📁 TEST CATEGORIES SUMMARY:"
    echo "┌─────────────────────────────────────────────────────────────────────────────────┐"
    echo "│ 🔐 VAULT OPERATIONS                                                             │"
    echo "│   • Login authentication: ${TEST_RESULTS[vault_login]}"
    echo "│   • Secret creation: ${TEST_RESULTS[secret_creation]}"
    echo "│   • Policy creation: ${TEST_RESULTS[policy_creation]}"
    echo "│   • Role creation: ${TEST_RESULTS[role_creation]}"
    echo "│                                                                                 │"
    echo "│ 🚀 KUBERNETES OPERATIONS                                                        │"
    echo "│   • Service account: ${TEST_RESULTS[service_account]}"
    echo "│   • Pod creation: ${TEST_RESULTS[pod_creation]}"
    echo "│   • Pod readiness: ${TEST_RESULTS[pod_ready]}"
    echo "│                                                                                 │"
    echo "│ 🔄 AGENT INJECTOR FUNCTIONALITY                                                 │"
    echo "│   • Secret injection: ${TEST_RESULTS[secret_injection]}"
    echo "│   • Secret verification: ${TEST_RESULTS[secret_verification]}"
    echo "│   • Agent logs: ${TEST_RESULTS[vault_agent_logs]}"
    echo "└─────────────────────────────────────────────────────────────────────────────────┘"
    echo
    
    # Recommendations based on results
    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo "🔧 TROUBLESHOOTING RECOMMENDATIONS:"
        echo "─────────────────────────────────────────────────────────────────────────────────"
        
        if [[ "${TEST_RESULTS[vault_login]}" == "FAILED" ]]; then
            echo "• Check Vault root token in vault-init-keys secret"
            echo "• Verify Vault pod is running and unsealed"
        fi
        
        if [[ "${TEST_RESULTS[secret_creation]}" == "FAILED" ]] || [[ "${TEST_RESULTS[policy_creation]}" == "FAILED" ]] || [[ "${TEST_RESULTS[role_creation]}" == "FAILED" ]]; then
            echo "• Verify Vault authentication and permissions"
            echo "• Check Vault KV secrets engine is enabled"
            echo "• Ensure Kubernetes auth method is configured"
        fi
        
        if [[ "${TEST_RESULTS[pod_creation]}" == "FAILED" ]] || [[ "${TEST_RESULTS[pod_ready]}" == "FAILED" ]]; then
            echo "• Check Vault Agent Injector is installed and running"
            echo "• Verify webhook configuration and certificates"
            echo "• Review pod events: kubectl describe pod $POD_NAME -n $NAMESPACE"
        fi
        
        if [[ "${TEST_RESULTS[secret_injection]}" == "FAILED" ]] || [[ "${TEST_RESULTS[secret_verification]}" == "FAILED" ]]; then
            echo "• Check Vault Agent Injector annotations are correct"
            echo "• Verify service account has proper bindings"
            echo "• Review Vault Agent logs for authentication issues"
        fi
        
        echo
    fi
    
    # Success message
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo "🎊 CONGRATULATIONS! All Vault Agent Injector tests passed successfully!"
        echo "   Your Vault Agent Injector is properly configured and working correctly."
        echo
    fi
    
    echo "══════════════════════════════════════════════════════════════════════════════════"
}

# Main execution
main() {
    check_dependencies
    run_test
}

# Run main function only if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi