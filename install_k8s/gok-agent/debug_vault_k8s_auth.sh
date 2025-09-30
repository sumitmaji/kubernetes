#!/bin/bash
# Debug and Validate Vault Kubernetes Authentication Setup
# =======================================================
# 
# This script contains all the debugging commands used to test and validate
# the setup_vault_k8s_auth.sh script and Vault Kubernetes authentication.
# 
# Usage:
#   ./debug_vault_k8s_auth.sh [command]
# 
# Commands:
#   all                - Run all debugging steps
#   basic             - Basic connectivity and status checks
#   auth-config       - Check Vault authentication configuration
#   test-auth         - Test authentication with different methods
#   service-accounts  - Check service accounts and RBAC
#   troubleshoot      - Advanced troubleshooting
#   cleanup           - Clean up test resources
# 
# Author: Generated from successful Vault K8s auth debugging session
# Date: September 30, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
VAULT_ROOT_TOKEN="${VAULT_ROOT_TOKEN:-}"
TEST_NAMESPACE="${TEST_NAMESPACE:-default}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-gok-agent}"
VAULT_ROLE="${VAULT_ROLE:-gok-agent}"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "\n${CYAN}🔍 $1${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

log_step() {
    echo -e "\n${PURPLE}🔹 Step $1: $2${NC}"
    echo -e "${PURPLE}$(printf -- '-%.0s' $(seq 1 60))${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    log_success "kubectl is available"
    
    # Check if connected to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Not connected to Kubernetes cluster"
        exit 1
    fi
    log_success "Connected to Kubernetes cluster"
    
    # Check if Vault namespace exists
    if ! kubectl get namespace "$VAULT_NAMESPACE" &> /dev/null; then
        log_error "Vault namespace '$VAULT_NAMESPACE' not found"
        exit 1
    fi
    log_success "Vault namespace '$VAULT_NAMESPACE' exists"
    
    # Check if Vault pod exists
    if ! kubectl get pod "$VAULT_POD" -n "$VAULT_NAMESPACE" &> /dev/null; then
        log_error "Vault pod '$VAULT_POD' not found in namespace '$VAULT_NAMESPACE'"
        exit 1
    fi
    log_success "Vault pod '$VAULT_POD' exists"
    
    # Get Vault root token if not provided
    if [ -z "$VAULT_ROOT_TOKEN" ]; then
        log_info "Attempting to retrieve Vault root token..."
        VAULT_ROOT_TOKEN=$(kubectl get secret vault-init-keys -n "$VAULT_NAMESPACE" -o jsonpath='{.data.root-token}' 2>/dev/null | base64 -d || echo "")
        if [ -z "$VAULT_ROOT_TOKEN" ]; then
            log_error "Could not retrieve Vault root token. Please set VAULT_ROOT_TOKEN environment variable"
            exit 1
        fi
    fi
    log_success "Vault root token available"
}

# Basic connectivity and status checks
basic_checks() {
    log_header "Basic Connectivity and Status Checks"
    
    log_step 1 "Check Vault Pod Status"
    kubectl get pods -n "$VAULT_NAMESPACE" | grep vault
    
    log_step 2 "Check Vault Services"
    kubectl get services -n "$VAULT_NAMESPACE"
    
    log_step 3 "Test Vault Connectivity from Pod"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault status
    "
    
    log_step 4 "Check Vault Initialization and Seal Status"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_ADDR='http://127.0.0.1:8200'
        curl -s http://127.0.0.1:8200/v1/sys/health | jq '.'
    " || echo "jq not available, showing raw output:"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_ADDR='http://127.0.0.1:8200'
        curl -s http://127.0.0.1:8200/v1/sys/health
    "
    
    log_step 5 "Verify Vault Root Token Access"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault token lookup
    "
}

# Check Vault authentication configuration
check_auth_config() {
    log_header "Vault Authentication Configuration"
    
    log_step 1 "List Authentication Methods"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault auth list
    "
    
    log_step 2 "Check Kubernetes Auth Configuration"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault read auth/kubernetes/config
    "
    
    log_step 3 "Check Vault Role Configuration"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault read auth/kubernetes/role/$VAULT_ROLE || echo 'Role not found'
    "
    
    log_step 4 "List Vault Policies"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault policy list
    "
    
    log_step 5 "Check RabbitMQ Policy"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault policy read rabbitmq-policy || echo 'Policy not found'
    "
    
    log_step 6 "Check Stored RabbitMQ Credentials"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        vault kv get secret/data/rabbitmq || echo 'Credentials not found'
    "
}

# Check service accounts and RBAC
check_service_accounts() {
    log_header "Service Accounts and RBAC Configuration"
    
    log_step 1 "Check Service Accounts in Test Namespace"
    kubectl get serviceaccounts -n "$TEST_NAMESPACE"
    
    log_step 2 "Check GOK-Agent Service Account"
    kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$TEST_NAMESPACE" -o yaml || log_warning "Service account '$SERVICE_ACCOUNT' not found"
    
    log_step 3 "Check Vault-Auth Service Account"
    kubectl get serviceaccount vault-auth -n "$TEST_NAMESPACE" -o yaml || log_warning "Service account 'vault-auth' not found"
    
    log_step 4 "Check Cluster Role Bindings"
    kubectl get clusterrolebindings | grep vault || log_warning "No vault-related cluster role bindings found"
    
    log_step 5 "Check Token Review Permissions"
    kubectl auth can-i create tokenreviews --as=system:serviceaccount:default:vault-auth || log_warning "Token review permission check failed"
    
    log_step 6 "Generate Service Account Tokens"
    log_info "Creating fresh token for $SERVICE_ACCOUNT..."
    FRESH_TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$TEST_NAMESPACE" --duration=1h 2>/dev/null || echo "")
    if [ -n "$FRESH_TOKEN" ]; then
        log_success "Fresh token created (length: ${#FRESH_TOKEN})"
        echo "Token preview: ${FRESH_TOKEN:0:50}..."
    else
        log_error "Failed to create fresh token"
    fi
}

# Test authentication with different methods
test_authentication() {
    log_header "Authentication Testing"
    
    # Get Vault service IP
    VAULT_SERVICE_IP=$(kubectl get service vault -n "$VAULT_NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    log_info "Vault service IP: $VAULT_SERVICE_IP"
    
    log_step 1 "Test Authentication from Vault Pod (Expected to Fail)"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        VAULT_JWT=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        echo 'Testing authentication with vault pod service account (should fail):'
        vault write auth/kubernetes/login role=$VAULT_ROLE jwt=\"\$VAULT_JWT\" 2>&1 || echo 'Expected failure - vault pod uses different service account'
    "
    
    log_step 2 "Create Test Pod for Authentication"
    cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vault-auth-test
  namespace: default
  labels:
    app: vault-auth-test
spec:
  serviceAccountName: gok-agent
  containers:
  - name: test
    image: curlimages/curl:latest
    command:
    - /bin/sh
    - -c
    - |
      echo "Vault authentication test pod ready"
      while true; do sleep 3600; done
  restartPolicy: Never
EOF
    
    log_info "Waiting for test pod to be ready..."
    kubectl wait --for=condition=Ready pod/vault-auth-test --timeout=60s || log_warning "Test pod not ready within 60s"
    
    log_step 3 "Test Authentication from Test Pod"
    kubectl exec vault-auth-test -- sh -c "
        JWT_TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
        echo 'Service Account Token Details:'
        echo 'Namespace: '\$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
        echo 'Token length: '\${#JWT_TOKEN}
        echo 'Token preview: '\${JWT_TOKEN:0:50}'...'
        echo ''
        
        echo 'Testing Vault connectivity:'
        curl -s --connect-timeout 10 http://$VAULT_SERVICE_IP:8200/v1/sys/health || echo 'Connection failed'
        echo ''
        
        echo 'Testing authentication:'
        AUTH_RESPONSE=\$(curl -s -X POST \\
            -H 'Content-Type: application/json' \\
            -d '{\"role\":\"$VAULT_ROLE\",\"jwt\":\"'\$JWT_TOKEN'\"}' \\
            'http://$VAULT_SERVICE_IP:8200/v1/auth/kubernetes/login')
        
        echo 'Authentication response:'
        echo \"\$AUTH_RESPONSE\"
        
        if echo \"\$AUTH_RESPONSE\" | grep -q 'client_token'; then
            echo 'Authentication successful!'
        else
            echo 'Authentication failed'
        fi
    " || log_error "Test pod execution failed"
    
    log_step 4 "Test with Fresh Token (if available)"
    if [ -n "$FRESH_TOKEN" ]; then
        kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
            export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
            export VAULT_ADDR='http://127.0.0.1:8200'
            echo 'Testing with fresh token:'
            vault write auth/kubernetes/login role=$VAULT_ROLE jwt='$FRESH_TOKEN' || echo 'Authentication with fresh token failed'
        "
    else
        log_warning "No fresh token available for testing"
    fi
}

# Advanced troubleshooting
advanced_troubleshooting() {
    log_header "Advanced Troubleshooting"
    
    log_step 1 "Check Vault Logs"
    kubectl logs -n "$VAULT_NAMESPACE" "$VAULT_POD" --tail=20 | grep -E "(ERROR|WARN|auth)" || echo "No relevant log entries found"
    
    log_step 2 "Validate JWT Token Structure"
    if kubectl get pod vault-auth-test &>/dev/null; then
        kubectl exec vault-auth-test -- sh -c "
            JWT_TOKEN=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
            echo 'JWT Token Analysis:'
            
            # Decode header
            HEADER=\$(echo \$JWT_TOKEN | cut -d. -f1)
            echo 'Header: '\$HEADER
            
            # Decode payload
            PAYLOAD=\$(echo \$JWT_TOKEN | cut -d. -f2)
            # Add padding for base64 decoding
            while [ \$((\${#PAYLOAD} % 4)) -ne 0 ]; do PAYLOAD=\"\${PAYLOAD}=\"; done
            echo 'Decoded payload:'
            echo \$PAYLOAD | base64 -d 2>/dev/null | head -c 500 || echo 'Decode failed'
        "
    fi
    
    log_step 3 "Check Kubernetes API Server Configuration"
    log_info "Checking service account token audience..."
    kubectl exec vault-auth-test -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null | cut -d. -f2 | base64 -d 2>/dev/null | grep -o '"aud":\[[^]]*\]' || echo "Could not extract audience"
    
    log_step 4 "Test Token Reviewer Configuration"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        echo 'Current token reviewer configuration:'
        vault read auth/kubernetes/config | grep -E '(token_reviewer_jwt_set|kubernetes_host|issuer)'
    "
    
    log_step 5 "Manual Token Review Test"
    REVIEWER_TOKEN=$(kubectl create token vault-auth --duration=1h 2>/dev/null || echo "")
    if [ -n "$REVIEWER_TOKEN" ]; then
        kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
            export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
            export VAULT_ADDR='http://127.0.0.1:8200'
            CA_CERT=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
            echo 'Updating Vault config with fresh token reviewer:'
            vault write auth/kubernetes/config \\
                kubernetes_host='https://kubernetes.default.svc.cluster.local' \\
                kubernetes_ca_cert=\"\$CA_CERT\" \\
                token_reviewer_jwt='$REVIEWER_TOKEN' \\
                disable_iss_validation=true
        "
    fi
    
    log_step 6 "Check Role and Policy Binding"
    kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
        export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
        export VAULT_ADDR='http://127.0.0.1:8200'
        echo 'Current role configuration:'
        vault read auth/kubernetes/role/$VAULT_ROLE
        echo ''
        echo 'Testing policy access:'
        vault auth -method=token token='$VAULT_ROOT_TOKEN'
        vault kv get secret/data/rabbitmq
    "
}

# Test credential retrieval (proof of concept)
test_credential_retrieval() {
    log_header "Credential Retrieval Test (Proof of Concept)"
    
    log_step 1 "Test with Root Token (Should Work)"
    if kubectl get pod vault-auth-test &>/dev/null; then
        VAULT_SERVICE_IP=$(kubectl get service vault -n "$VAULT_NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        kubectl exec vault-auth-test -- sh -c "
            echo 'Testing credential retrieval with root token:'
            CREDS_RESPONSE=\$(curl -s -H 'X-Vault-Token: $VAULT_ROOT_TOKEN' 'http://$VAULT_SERVICE_IP:8200/v1/secret/data/rabbitmq')
            
            if echo \"\$CREDS_RESPONSE\" | grep -q 'username'; then
                echo 'Successfully retrieved RabbitMQ credentials!'
                USERNAME=\$(echo \"\$CREDS_RESPONSE\" | sed -n 's/.*\"username\":\"\([^\"]*\)\".*/\1/p')
                PASSWORD=\$(echo \"\$CREDS_RESPONSE\" | sed -n 's/.*\"password\":\"\([^\"]*\)\".*/\1/p')
                echo 'Username: '\$USERNAME
                echo 'Password: '\$(echo \$PASSWORD | sed 's/./*/g')
            else
                echo 'Failed to retrieve credentials'
                echo 'Response: '\$CREDS_RESPONSE
            fi
        "
    else
        log_warning "Test pod not available"
    fi
}

# Cleanup test resources
cleanup_resources() {
    log_header "Cleaning Up Test Resources"
    
    log_step 1 "Remove Test Pod"
    kubectl delete pod vault-auth-test --ignore-not-found=true
    log_success "Test pod removed"
    
    log_step 2 "Keep Service Accounts"
    log_info "Service accounts (gok-agent, vault-auth) kept for production use"
}

# Run setup_vault_k8s_auth.sh if available
run_setup_script() {
    log_header "Running Setup Script"
    
    if [ -f "setup_vault_k8s_auth.sh" ]; then
        log_info "Running setup_vault_k8s_auth.sh..."
        kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- sh -c "
            export VAULT_TOKEN='$VAULT_ROOT_TOKEN'
            export VAULT_ADDR='http://127.0.0.1:8200'
            $(cat setup_vault_k8s_auth.sh)
        "
    else
        log_warning "setup_vault_k8s_auth.sh not found in current directory"
    fi
}

# Show usage information
show_usage() {
    echo "Debug and Validate Vault Kubernetes Authentication Setup"
    echo "======================================================"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  all                - Run all debugging steps"
    echo "  basic             - Basic connectivity and status checks"
    echo "  auth-config       - Check Vault authentication configuration"
    echo "  test-auth         - Test authentication with different methods"
    echo "  service-accounts  - Check service accounts and RBAC"
    echo "  troubleshoot      - Advanced troubleshooting"
    echo "  credentials       - Test credential retrieval"
    echo "  setup             - Run setup_vault_k8s_auth.sh script"
    echo "  cleanup           - Clean up test resources"
    echo ""
    echo "Environment Variables:"
    echo "  VAULT_NAMESPACE    - Vault namespace (default: vault)"
    echo "  VAULT_POD          - Vault pod name (default: vault-0)"
    echo "  VAULT_ROOT_TOKEN   - Vault root token (will be auto-discovered if not set)"
    echo "  TEST_NAMESPACE     - Test namespace (default: default)"
    echo "  SERVICE_ACCOUNT    - Service account name (default: gok-agent)"
    echo "  VAULT_ROLE         - Vault role name (default: gok-agent)"
    echo ""
    echo "Example:"
    echo "  $0 all                           # Run all debugging steps"
    echo "  VAULT_ROOT_TOKEN=hvs.xxx $0 basic  # Run basic checks with specific token"
}

# Main execution logic
main() {
    local command=${1:-all}
    
    case $command in
        "basic")
            check_prerequisites
            basic_checks
            ;;
        "auth-config")
            check_prerequisites
            check_auth_config
            ;;
        "service-accounts")
            check_prerequisites
            check_service_accounts
            ;;
        "test-auth")
            check_prerequisites
            test_authentication
            ;;
        "troubleshoot")
            check_prerequisites
            advanced_troubleshooting
            ;;
        "credentials")
            check_prerequisites
            test_credential_retrieval
            ;;
        "setup")
            check_prerequisites
            run_setup_script
            ;;
        "cleanup")
            cleanup_resources
            ;;
        "all")
            check_prerequisites
            basic_checks
            check_auth_config
            check_service_accounts
            test_authentication
            advanced_troubleshooting
            test_credential_retrieval
            log_info "Use '$0 cleanup' to clean up test resources"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run the script
main "$@"