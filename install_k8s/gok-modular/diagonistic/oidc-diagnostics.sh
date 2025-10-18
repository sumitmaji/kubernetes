#!/bin/bash

# GOK OIDC Diagnostic and Fix Script
# This script diagnoses and fixes OIDC authentication issues with gok-login

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REMOTE_USER="sumit"
REMOTE_HOST="10.0.0.244"
KUBERNETES_API_SERVER="https://10.0.0.244:6443"
KEYCLOAK_REALM="https://keycloak.gokcloud.com/realms/GokDevelopers"
CA_CERT_PATH="/usr/local/share/ca-certificates/issuer.crt"
API_SERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

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

log_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Remote execution function
remote_exec() {
    local cmd="$1"
    log_info "Executing remotely: $cmd"
    ./gok-new remote exec "$cmd"
    return $?
}

# Check cluster role bindings
check_cluster_role_bindings() {
    log_header "Checking Cluster Role Bindings"

    log_info "Looking for admin/developer/group related role bindings..."
    remote_exec "kubectl get clusterrolebinding | grep -E '(admin|developer|group)'"

    log_info "Checking specific role bindings for administrators/developers groups..."
    remote_exec "kubectl get clusterrolebinding -o yaml | grep -A 5 -B 5 'administrators\|developers'"
}

# Check API server OIDC configuration
check_api_server_oidc_config() {
    log_header "Checking API Server OIDC Configuration"

    log_info "Checking API server manifest for OIDC parameters..."
    remote_exec "cat $API_SERVER_MANIFEST | grep -A 10 -B 5 oidc"

    log_info "Checking for OIDC CA file configuration..."
    remote_exec "cat $API_SERVER_MANIFEST | grep -A 2 -B 2 oidc-ca"
}

# Check API server logs for OIDC issues
check_api_server_logs() {
    log_header "Checking API Server Logs for OIDC Issues"

    log_info "Checking recent API server logs for OIDC-related messages..."
    remote_exec "kubectl logs kube-apiserver-master.cloud.com -n kube-system --tail=50 | grep -i oidc"
}

# Check certificates
check_certificates() {
    log_header "Checking Certificates"

    log_info "Finding certificates in Kubernetes directory..."
    remote_exec "find /etc/kubernetes -name '*.crt' -o -name '*.pem' | head -10"

    log_info "Finding gok/keycloak/selfsign related files..."
    remote_exec "find /etc -name '*gok*' -o -name '*keycloak*' -o -name '*selfsign*' 2>/dev/null"

    log_info "Checking CA certificates..."
    remote_exec "ls -la /usr/local/share/ca-certificates/"

    log_info "Checking issuer certificate details..."
    remote_exec "openssl x509 -in $CA_CERT_PATH -text -noout | grep -E '(Subject|Issuer):'"
}

# Test OIDC authentication
test_oidc_authentication() {
    log_header "Testing OIDC Authentication"

    local test_token="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJhUEFJNEJXdy1wU2V3MzRkTkhyYkR0MTdqN3ZuWGFqbmJyaGpfNHdFeFdRIn0.eyJleHAiOjE3NjA3OTMxMzAsImlhdCI6MTc2MDc1NzEzMCwianRpIjoiMDQ2NzRjOGItODA5Ni00ZmJhLTg0ZmMtMDA4MWZiYjYyYjE5IiwiaXNzIjoiaHR0cHM6Ly9rZXljbG9hay5nb2tjbG91ZC5jb20vcmVhbG1zL0dva0RldmVsb3BlcnMiLCJhdWQiOlsiZ29rLWRldmVsb3BlcnMtY2xpZW50IiwiYWNjb3VudCJdLCJzdWIiOiJjNWRhMjJkYS05MmU0LTRiNzktYTU0Ni1jZDgyMTA2YTBmY2EiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJnb2stZGV2ZWxvcGVycy1jbGllbnQiLCJzaWQiOiI1YTNiMTkwNC0xOWQwLTRhYmUtYjM5Mi0xNjAyZWNkNmIyZmYiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbImh0dHBzOi8vbG9jYWxob3N0IiwiaHR0cHM6Ly9rdWJlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vYXJnb2NkLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vc3Bpbi1nYXRlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vY2hlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vamVua2lucy5nb2tjbG91ZC5jb20iLCJodHRwczovL2p1cHl0ZXJodWIuZ29rY2xvdWQuY29tIiwiaHR0cHM6Ly9nb2stbG9naW4uZ29rY2xvdWQuY29tIl0sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJvZmZsaW5lX2FjY2VzcyIsImRlZmF1bHQtcm9sZXMtZ29rZGV2ZWxvcGVycyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJ1bnRydXN0ZWQtYXVkaWVuY2UgZW1haWwgZ3JvdXBzIHByb2ZpbGUiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IlN1bWl0IE1hamkiLCJncm91cHMiOlsiYWRtaW5pc3RyYXRvcnMiLCJkZXZlbG9wZXJzIl0sInByZWZlcnJlZF91c2VybmFtZSI6InNrbWFqaTEiLCJnaXZlbl9uYW1lIjoiU3VtaXQiLCJmYW1pbHlfbmFtZSI6Ik1hamkiLCJlbWFpbCI6InNrbWFqaTFAb3V0bG9vay5jb20ifQ.ae-WFfDFSqRCCv6ZsaSA2DEihvkyEHJNxUo-rW8S-ezTOZRZUZ1CAZBz4r1azwtHIWMbYD0yGc22lTpmhoSTAUKNPNkJzt_g9LkcOaVDrTNk3ZCoi7LGbGnVfFYdo5qqVZzxZR4NS4ZFqxUGHsWp-cfYjNzM1N_huh-XFuJLwZnKhhZ7BcIQZBgenrZgNjvocL6OWLXkU8QSrXYGO4KIIuD7b1ryxxx_XtyYNoaHq5vvIqbZ1lmqkngbiGsiECDlJPDt3dlQBEHqtIHyesqDi1_t_nLHsJ2aJ_BQ2pPHb_yRSk_mN-jDQBbLX3RDfX1WnfcMeogHDJwA8wodCRCGoA"

    log_info "Testing direct API call with JWT token..."
    local api_test=$(remote_exec "curl -k -s -H 'Authorization: Bearer $test_token' $KUBERNETES_API_SERVER/api/v1/namespaces/default/pods | head -5")

    if echo "$api_test" | grep -q '"kind": "PodList"'; then
        log_success "API authentication test PASSED"
        return 0
    elif echo "$api_test" | grep -q '"status": "Failure"'; then
        log_error "API authentication test FAILED - Unauthorized"
        return 1
    else
        log_warning "API authentication test result unclear"
        return 1
    fi
}

# Test kubectl with token
test_kubectl_authentication() {
    log_header "Testing kubectl Authentication"

    local test_token="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJhUEFJNEJXdy1wU2V3MzRkTkhyYkR0MTdqN3ZuWGFqbmJyaGpfNHdFeFdRIn0.eyJleHAiOjE3NjA3OTMxMzAsImlhdCI6MTc2MDc1NzEzMCwianRpIjoiMDQ2NzRjOGItODA5Ni00ZmJhLTg0ZmMtMDA4MWZiYjYyYjE5IiwiaXNzIjoiaHR0cHM6Ly9rZXljbG9hay5nb2tjbG91ZC5jb20vcmVhbG1zL0dva0RldmVsb3BlcnMiLCJhdWQiOlsiZ29rLWRldmVsb3BlcnMtY2xpZW50IiwiYWNjb3VudCJdLCJzdWIiOiJjNWRhMjJkYS05MmU0LTRiNzktYTU0Ni1jZDgyMTA2YTBmY2EiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJnb2stZGV2ZWxvcGVycy1jbGllbnQiLCJzaWQiOiI1YTNiMTkwNC0xOWQwLTRhYmUtYjM5Mi0xNjAyZWNkNmIyZmYiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbImh0dHBzOi8vbG9jYWxob3N0IiwiaHR0cHM6Ly9rdWJlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vYXJnb2NkLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vc3Bpbi1nYXRlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vY2hlLmdva2Nsb3VkLmNvbSIsImh0dHBzOi8vamVua2lucy5nb2tjbG91ZC5jb20iLCJodHRwczovL2p1cHl0ZXJodWIuZ29rY2xvdWQuY29tIiwiaHR0cHM6Ly9nb2stbG9naW4uZ29rY2xvdWQuY29tIl0sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJvZmZsaW5lX2FjY2VzcyIsImRlZmF1bHQtcm9sZXMtZ29rZGV2ZWxvcGVycyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJ1bnRydXN0ZWQtYXVkaWVuY2UgZW1haWwgZ3JvdXBzIHByb2ZpbGUiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IlN1bWl0IE1hamkiLCJncm91cHMiOlsiYWRtaW5pc3RyYXRvcnMiLCJkZXZlbG9wZXJzIl0sInByZWZlcnJlZF91c2VybmFtZSI6InNrbWFqaTEiLCJnaXZlbl9uYW1lIjoiU3VtaXQiLCJmYW1pbHlfbmFtZSI6Ik1hamkiLCJlbWFpbCI6InNrbWFqaTFAb3V0bG9vay5jb20ifQ.ae-WFfDFSqRCCv6ZsaSA2DEihvkyEHJNxUo-rW8S-ezTOZRZUZ1CAZBz4r1azwtHIWMbYD0yGc22lTpmhoSTAUKNPNkJzt_g9LkcOaVDrTNk3ZCoi7LGbGnVfFYdo5qqVZzxZR4NS4ZFqxUGHsWp-cfYjNzM1N_huh-XFuJLwZnKhhZ7BcIQZBgenrZgNjvocL6OWLXkU8QSrXYGO4KIIuD7b1ryxxx_XtyYNoaHq5vvIqbZ1lmqkngbiGsiECDlJPDt3dlQBEHqtIHyesqDi1_t_nLHsJ2aJ_BQ2pPHb_yRSk_mN-jDQBbLX3RDfX1WnfcMeogHDJwA8wodCRCGoA"

    log_info "Testing kubectl with JWT token..."
    if remote_exec "kubectl --token='$test_token' --server=$KUBERNETES_API_SERVER --insecure-skip-tls-verify=true get pods -n default --request-timeout=10s | head -5" >/dev/null 2>&1; then
        log_success "kubectl authentication test PASSED"
        return 0
    else
        log_error "kubectl authentication test FAILED"
        return 1
    fi
}

# Fix OIDC CA file configuration
fix_oidc_ca_file() {
    log_header "Fixing OIDC CA File Configuration"

    log_info "Checking if OIDC CA file is already configured..."
    local ca_config=$(remote_exec "grep -c 'oidc-ca-file' $API_SERVER_MANIFEST")

    if [[ "$ca_config" -gt 0 ]]; then
        log_success "OIDC CA file is already configured"
        return 0
    fi

    log_warning "OIDC CA file not configured. Adding it..."

    # Backup the current configuration
    log_info "Creating backup of API server configuration..."
    remote_exec "cp $API_SERVER_MANIFEST ${API_SERVER_MANIFEST}.backup.$(date +%Y%m%d_%H%M%S)"

    # Add the OIDC CA file parameter
    log_info "Adding OIDC CA file parameter to API server configuration..."
    remote_exec "sed -i '/--oidc-username-claim/a\    - --oidc-ca-file=$CA_CERT_PATH' $API_SERVER_MANIFEST"

    # Verify the change
    log_info "Verifying the configuration change..."
    remote_exec "grep -A 5 -B 5 oidc-ca $API_SERVER_MANIFEST"

    log_success "OIDC CA file configuration updated. API server will restart automatically."
    log_info "Waiting 30 seconds for API server to restart..."
    sleep 30
}

# Main diagnostic function
run_oidc_diagnostics() {
    log_header "GOK OIDC Authentication Diagnostics"
    echo "This script will diagnose and fix OIDC authentication issues with gok-login"
    echo

    local issues_found=0
    local fixes_applied=0

    # Step 1: Check cluster role bindings
    check_cluster_role_bindings
    echo

    # Step 2: Check API server OIDC configuration
    check_api_server_oidc_config
    echo

    # Step 3: Check certificates
    check_certificates
    echo

    # Step 4: Check API server logs
    check_api_server_logs
    echo

    # Step 5: Test current authentication
    log_info "Testing current authentication status..."
    if ! test_oidc_authentication; then
        issues_found=$((issues_found + 1))
        log_error "OIDC authentication is currently failing"

        # Try to fix the issue
        log_info "Attempting to fix OIDC CA file configuration..."
        fix_oidc_ca_file
        fixes_applied=$((fixes_applied + 1))

        # Wait a bit and test again
        log_info "Waiting for API server to restart and re-testing authentication..."
        sleep 10

        if test_oidc_authentication; then
            log_success "OIDC authentication fix successful!"
        else
            log_error "OIDC authentication still failing after fix attempt"
        fi
    else
        log_success "OIDC authentication is working correctly"
    fi
    echo

    # Step 6: Test kubectl authentication
    if ! test_kubectl_authentication; then
        log_error "kubectl authentication test failed"
        issues_found=$((issues_found + 1))
    else
        log_success "kubectl authentication test passed"
    fi
    echo

    # Summary
    log_header "Diagnostic Summary"
    echo "Issues found: $issues_found"
    echo "Fixes applied: $fixes_applied"

    if [[ $issues_found -eq 0 ]]; then
        log_success "All OIDC authentication checks passed!"
    else
        log_warning "Some issues were found. Please review the output above."
        if [[ $fixes_applied -gt 0 ]]; then
            log_info "Fixes were applied. You may need to wait a few minutes for all changes to take effect."
        fi
    fi
}

# Main execution
case "${1:-diagnose}" in
    "diagnose")
        run_oidc_diagnostics
        ;;
    "check-rbac")
        check_cluster_role_bindings
        ;;
    "check-config")
        check_api_server_oidc_config
        ;;
    "check-logs")
        check_api_server_logs
        ;;
    "check-certs")
        check_certificates
        ;;
    "test-api")
        test_oidc_authentication
        ;;
    "test-kubectl")
        test_kubectl_authentication
        ;;
    "fix-ca")
        fix_oidc_ca_file
        ;;
    "help"|"-h"|"--help")
        echo "GOK OIDC Diagnostic Script"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  diagnose     - Run full diagnostic suite (default)"
        echo "  check-rbac   - Check cluster role bindings"
        echo "  check-config - Check API server OIDC configuration"
        echo "  check-logs   - Check API server logs for OIDC issues"
        echo "  check-certs  - Check certificates"
        echo "  test-api     - Test API authentication with JWT token"
        echo "  test-kubectl - Test kubectl authentication with JWT token"
        echo "  fix-ca       - Fix OIDC CA file configuration"
        echo "  help         - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac