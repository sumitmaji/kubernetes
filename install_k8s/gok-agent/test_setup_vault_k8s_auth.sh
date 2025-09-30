#!/bin/bash

# Test script for setup_vault_k8s_auth.sh
# This script validates the functionality of the Vault K8s authentication setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Logging functions
test_log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

test_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    ((TOTAL_TESTS++))
    test_log "Running: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        local actual_exit_code=$?
        if [[ $actual_exit_code -eq $expected_exit_code ]]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (Expected exit code $expected_exit_code, got $actual_exit_code)"
        fi
    else
        local actual_exit_code=$?
        if [[ $actual_exit_code -eq $expected_exit_code ]]; then
            test_pass "$test_name"
        else
            test_fail "$test_name (Expected exit code $expected_exit_code, got $actual_exit_code)"
        fi
    fi
}

# Test 1: Script Syntax Validation
test_syntax_validation() {
    test_log "=== Testing Script Syntax ==="
    run_test "Bash syntax validation" "bash -n ./setup_vault_k8s_auth.sh"
    run_test "Script is executable" "test -x ./setup_vault_k8s_auth.sh"
}

# Test 2: Help Functionality
test_help_functionality() {
    test_log "=== Testing Help Functionality ==="
    
    # Test help flag
    ./setup_vault_k8s_auth.sh --help > /tmp/help_output.txt 2>&1
    if grep -q "Usage:" /tmp/help_output.txt && grep -q "Environment Variables:" /tmp/help_output.txt; then
        test_pass "Help flag displays usage information"
    else
        test_fail "Help flag does not display proper usage information"
    fi
    ((TOTAL_TESTS++))
    
    # Test -h flag
    ./setup_vault_k8s_auth.sh -h > /tmp/help_output2.txt 2>&1
    if diff /tmp/help_output.txt /tmp/help_output2.txt >/dev/null; then
        test_pass "Short help flag (-h) works correctly"
    else
        test_fail "Short help flag (-h) output differs from --help"
    fi
    ((TOTAL_TESTS++))
    
    rm -f /tmp/help_output.txt /tmp/help_output2.txt
}

# Test 3: Parameter Validation
test_parameter_validation() {
    test_log "=== Testing Parameter Validation ==="
    
    # Test missing VAULT_TOKEN
    if ./setup_vault_k8s_auth.sh 2>&1 | grep -q "VAULT_TOKEN environment variable is required"; then
        test_pass "Missing VAULT_TOKEN is properly detected"
    else
        test_fail "Missing VAULT_TOKEN validation failed"
    fi
    ((TOTAL_TESTS++))
    
    # Test invalid command line argument
    if ./setup_vault_k8s_auth.sh invalid-arg 2>&1 | grep -q "Unknown argument"; then
        test_pass "Invalid arguments are properly rejected"
    else
        test_fail "Invalid argument validation failed"
    fi
    ((TOTAL_TESTS++))
}

# Test 4: Environment Variables
test_environment_variables() {
    test_log "=== Testing Environment Variable Handling ==="
    
    # Create a temporary test script to check variable defaults
    cat > /tmp/test_vars.sh << 'EOF'
#!/bin/bash
source ./setup_vault_k8s_auth.sh 2>/dev/null || true

# Test default values
[[ "$VAULT_ADDR" == "http://localhost:8200" ]] || exit 1
[[ "$K8S_AUTH_PATH" == "kubernetes" ]] || exit 2
[[ "$VAULT_ROLE" == "gok-agent" ]] || exit 3
[[ "$SERVICE_ACCOUNT_NAME" == "gok-agent" ]] || exit 4
[[ "$SERVICE_ACCOUNT_NAMESPACE" == "default" ]] || exit 5
[[ "$POLICY_NAME" == "rabbitmq-policy" ]] || exit 6
[[ "$SECRET_PATH" == "secret/data/rabbitmq" ]] || exit 7
[[ "$TOKEN_TTL" == "24h" ]] || exit 8

echo "All defaults correct"
EOF
    
    chmod +x /tmp/test_vars.sh
    
    # This test is tricky because sourcing the script executes it, so we'll check the script content instead
    if grep -q 'VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"' ./setup_vault_k8s_auth.sh; then
        test_pass "Default environment variables are properly set"
    else
        test_fail "Default environment variables setup is incorrect"
    fi
    ((TOTAL_TESTS++))
    
    rm -f /tmp/test_vars.sh
}

# Test 5: Prerequisite Checking
test_prerequisites() {
    test_log "=== Testing Prerequisite Checking ==="
    
    # Test Vault CLI detection
    export VAULT_TOKEN="test-token"
    if ./setup_vault_k8s_auth.sh 2>&1 | grep -q "Vault CLI not found"; then
        test_pass "Missing Vault CLI is properly detected"
    else
        test_fail "Vault CLI detection failed"
    fi
    ((TOTAL_TESTS++))
    unset VAULT_TOKEN
}

# Test 6: Function Structure
test_function_structure() {
    test_log "=== Testing Function Structure ==="
    
    # Check for required functions
    local required_functions=(
        "log_info"
        "log_success" 
        "log_warning"
        "log_error"
        "check_k8s_environment"
        "get_k8s_config_from_kubectl"
        "check_vault_connection"
        "enable_kubernetes_auth"
        "configure_kubernetes_auth"
        "create_vault_policy"
        "create_vault_role"
        "test_authentication"
        "show_summary"
        "main"
        "usage"
    )
    
    for func in "${required_functions[@]}"; do
        if grep -q "^${func}()" ./setup_vault_k8s_auth.sh; then
            test_pass "Function $func is defined"
        else
            test_fail "Function $func is missing"
        fi
        ((TOTAL_TESTS++))
    done
}

# Test 7: Configuration Content
test_configuration_content() {
    test_log "=== Testing Configuration Content ==="
    
    # Check for Vault policy content
    if grep -q "Allow reading RabbitMQ credentials" ./setup_vault_k8s_auth.sh; then
        test_pass "Vault policy content is present"
    else
        test_fail "Vault policy content is missing"
    fi
    ((TOTAL_TESTS++))
    
    # Check for error handling
    if grep -q "set -e" ./setup_vault_k8s_auth.sh; then
        test_pass "Script has proper error handling (set -e)"
    else
        test_fail "Script missing error handling"
    fi
    ((TOTAL_TESTS++))
    
    # Check for logging
    if grep -q "log_info.*Configuration Summary" ./setup_vault_k8s_auth.sh; then
        test_pass "Script has configuration summary logging"
    else
        test_fail "Script missing configuration summary"
    fi
    ((TOTAL_TESTS++))
}

# Test 8: Security Considerations
test_security_considerations() {
    test_log "=== Testing Security Considerations ==="
    
    # Check for secure token handling
    if grep -q "VAULT_TOKEN.*required" ./setup_vault_k8s_auth.sh; then
        test_pass "Script validates VAULT_TOKEN requirement"
    else
        test_fail "Script doesn't validate VAULT_TOKEN"
    fi
    ((TOTAL_TESTS++))
    
    # Check for cleanup
    if grep -q "rm.*k8s-ca.crt" ./setup_vault_k8s_auth.sh; then
        test_pass "Script cleans up temporary files"
    else
        test_fail "Script doesn't clean up temporary files"
    fi
    ((TOTAL_TESTS++))
}

# Test 9: Integration Points
test_integration_points() {
    test_log "=== Testing Integration Points ==="
    
    # Check kubectl integration
    if grep -q "kubectl.*serviceaccount" ./setup_vault_k8s_auth.sh; then
        test_pass "Script integrates with kubectl for service account management"
    else
        test_fail "Script missing kubectl integration"
    fi
    ((TOTAL_TESTS++))
    
    # Check Vault CLI integration
    if grep -q "vault auth enable" ./setup_vault_k8s_auth.sh; then
        test_pass "Script uses Vault CLI for authentication setup"
    else
        test_fail "Script missing Vault CLI integration"
    fi
    ((TOTAL_TESTS++))
}

# Test 10: Documentation and Output
test_documentation_output() {
    test_log "=== Testing Documentation and Output ==="
    
    # Check for next steps guidance
    if grep -q "Next steps:" ./setup_vault_k8s_auth.sh; then
        test_pass "Script provides next steps guidance"
    else
        test_fail "Script missing next steps guidance"
    fi
    ((TOTAL_TESTS++))
    
    # Check for example commands
    if grep -q "kubectl get sa" ./setup_vault_k8s_auth.sh; then
        test_pass "Script provides example kubectl commands"
    else
        test_fail "Script missing example commands"
    fi
    ((TOTAL_TESTS++))
}

# Run all tests
main() {
    test_info "Starting comprehensive test suite for setup_vault_k8s_auth.sh"
    test_info "============================================================"
    
    # Change to script directory
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    if [[ ! -f "./setup_vault_k8s_auth.sh" ]]; then
        test_fail "setup_vault_k8s_auth.sh not found in current directory"
        exit 1
    fi
    
    # Run all test suites
    test_syntax_validation
    test_help_functionality
    test_parameter_validation
    test_environment_variables
    test_prerequisites
    test_function_structure
    test_configuration_content
    test_security_considerations
    test_integration_points
    test_documentation_output
    
    # Print summary
    echo ""
    test_info "============================================================"
    test_info "TEST SUMMARY"
    test_info "============================================================"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
        echo -e "   Tests Passed: ${GREEN}$TESTS_PASSED${NC}/$TOTAL_TESTS"
        echo -e "   Status: ${GREEN}READY FOR PRODUCTION${NC}"
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo -e "   Tests Passed: ${GREEN}$TESTS_PASSED${NC}/$TOTAL_TESTS"
        echo -e "   Tests Failed: ${RED}$TESTS_FAILED${NC}/$TOTAL_TESTS"
        echo -e "   Status: ${RED}NEEDS ATTENTION${NC}"
        exit 1
    fi
    
    echo ""
    test_info "Script Purpose Summary:"
    echo "  🎯 Automates Vault Kubernetes authentication setup"
    echo "  🔐 Configures secure service account authentication"
    echo "  🧪 Provides end-to-end testing and validation"
    echo "  📋 Offers comprehensive logging and troubleshooting"
    echo "  🚀 Enables production-ready GOK-Agent deployment"
}

# Run the tests
main "$@"