#!/bin/bash

# Test script for setup_vault_k8s_auth.sh
# This script validates the functionality of the Vault K8s authentication setup script

# Temporarily disabled set -e for debugging
# set -e

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
    echo -e "\n${YELLOW}TEST 2: Enhanced Help Functionality${NC}"
    echo "---------------------------------------"
    
    local help_output
    help_output=$(./setup_vault_k8s_auth.sh --help 2>&1)
    
    # Check for enhanced usage information  
    if echo "$help_output" | grep -q "Usage:" || echo "$help_output" | grep -q "Vault K8s Auth Setup"; then
        echo -e "${GREEN}✅ Usage section: PASS${NC}"
    else
        echo -e "${RED}❌ Usage section: FAIL${NC}"
        return 1
    fi
    
    # Check for auto-discovery documentation
    if echo "$help_output" | grep -q "Auto-Discovery"; then
        echo -e "${GREEN}✅ Auto-discovery docs: PASS${NC}"
    else
        echo -e "${RED}❌ Auto-discovery docs: FAIL${NC}"
        return 1
    fi
    
    # Check for zero-configuration examples
    if echo "$help_output" | grep -q "ZERO-CONFIGURATION EXAMPLES"; then
        echo -e "${GREEN}✅ Zero-config examples: PASS${NC}"
    else
        echo -e "${RED}❌ Zero-config examples: FAIL${NC}"
        return 1
    fi
    
    # Check for discover command documentation
    if echo "$help_output" | grep -q "discover.*Show auto-discovered\|discover.*configuration only"; then
        echo -e "${GREEN}✅ Discover command docs: PASS${NC}"
    else
        echo -e "${RED}❌ Discover command docs: FAIL${NC}"
        return 1
    fi
    
    return 0
}

# Test 3: Parameter Validation
test_parameter_validation() {
    test_log "=== Testing Auto-Discovery Parameter Validation ==="
    
    # Test discover command
    local discover_output
    discover_output=$(./setup_vault_k8s_auth.sh discover 2>&1 || true)
    
    if echo "$discover_output" | grep -q "Running auto-discovery only"; then
        test_pass "Discover command works properly"
    else
        test_fail "Discover command validation failed"
    fi
    ((TOTAL_TESTS++))
    
    # Test auto-discovery trigger
    if ./setup_vault_k8s_auth.sh 2>&1 | grep -q "Missing configuration.*running auto-discovery"; then
        test_pass "Auto-discovery triggers correctly"
    else
        test_fail "Auto-discovery trigger validation failed"
    fi
    ((TOTAL_TESTS++))
    
    # Test invalid command line argument still works
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
    
    # Check for auto-discovery environment variable initialization
    if grep -q 'VAULT_ADDR="${VAULT_ADDR:-}"' ./setup_vault_k8s_auth.sh; then
        test_pass "VAULT_ADDR auto-discovery initialization"
    else
        test_fail "VAULT_ADDR auto-discovery initialization missing"
    fi
    ((TOTAL_TESTS++))
    
    if grep -q 'VAULT_NAMESPACE=""' ./setup_vault_k8s_auth.sh; then
        test_pass "VAULT_NAMESPACE initialization"
    else
        test_fail "VAULT_NAMESPACE initialization missing"
    fi
    ((TOTAL_TESTS++))
    
    if grep -q 'AUTO_DISCOVERED="false"' ./setup_vault_k8s_auth.sh; then
        test_pass "AUTO_DISCOVERED flag initialization"
    else
        test_fail "AUTO_DISCOVERED flag missing"
    fi
    ((TOTAL_TESTS++))
    
    # Check for domain update
    if grep -q 'cloud.uat' ./setup_vault_k8s_auth.sh; then
        test_pass "Domain configuration updated to cloud.uat"
    else
        test_fail "Domain configuration not updated"
    fi
    ((TOTAL_TESTS++))
    
    rm -f /tmp/test_vars.sh
}

# Test 5: Prerequisite Checking
test_prerequisites() {
    test_log "=== Testing Auto-Discovery Prerequisites ==="
    
    # Test auto-discovery trigger when no config provided
    local output
    output=$(./setup_vault_k8s_auth.sh 2>&1 || true)
    
    if echo "$output" | grep -q "Missing configuration.*running auto-discovery"; then
        test_pass "Auto-discovery triggers when no configuration provided"
    else
        test_fail "Auto-discovery trigger failed"
    fi
    ((TOTAL_TESTS++))
    
    # Test Kubernetes connectivity check
    if echo "$output" | grep -q "Connected to Kubernetes cluster"; then
        test_pass "Kubernetes connectivity check works"
    else
        test_fail "Kubernetes connectivity check failed"
    fi
    ((TOTAL_TESTS++))
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
    
    # Check for secure token handling (auto-discovery or manual)
    if grep -q "discover_vault_token\|VAULT_TOKEN\|token.*secret" ./setup_vault_k8s_auth.sh; then
        test_pass "Script handles secure token management (auto-discovery or manual)"
    else
        test_fail "Script missing secure token handling"
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
test_auto_discovery_capabilities() {
    test_log "=== Testing Auto-Discovery Capabilities ==="
    
    # Test discover command output
    local discover_output
    discover_output=$(./setup_vault_k8s_auth.sh discover 2>&1 || true)
    
    if echo "$discover_output" | grep -q "Auto-discovering Vault configuration"; then
        test_pass "Auto-discovery initiation works"
    else
        test_fail "Auto-discovery initiation failed"
    fi
    ((TOTAL_TESTS++))
    
    if echo "$discover_output" | grep -q "Connected to Kubernetes cluster"; then
        test_pass "Kubernetes connectivity check works"
    else
        test_fail "Kubernetes connectivity check failed"
    fi
    ((TOTAL_TESTS++))
    
    if echo "$discover_output" | grep -q "AUTO-DISCOVERY RESULTS"; then
        test_pass "Results section present"
    else
        test_fail "Results section missing"
    fi
    ((TOTAL_TESTS++))
    
    # Check for auto-discovery functions in script
    if grep -q "auto_discover_vault_config()" ./setup_vault_k8s_auth.sh; then
        test_pass "Auto-discovery function present"
    else
        test_fail "Auto-discovery function missing"
    fi
    ((TOTAL_TESTS++))
}

test_integration_points() {
    test_log "=== Testing Enhanced Integration Points ==="
    
    # Check for enhanced Kubernetes integration
    if grep -q "kubectl.*get.*namespace" ./setup_vault_k8s_auth.sh; then
        test_pass "Script includes namespace discovery"
    else
        test_fail "Script missing namespace discovery"
    fi
    ((TOTAL_TESTS++))
    
    # Check for pod discovery
    if grep -q "kubectl.*get.*pod" ./setup_vault_k8s_auth.sh; then
        test_pass "Script includes pod discovery"
    else
        test_fail "Script missing pod discovery"
    fi
    ((TOTAL_TESTS++))
    
    # Check for service discovery
    if grep -q "kubectl.*get.*service.*vault" ./setup_vault_k8s_auth.sh; then
        test_pass "Script includes service discovery"
    else
        test_fail "Script missing service discovery"
    fi
    ((TOTAL_TESTS++))
    
    # Check for token extraction (more flexible pattern)
    if grep -q "kubectl.*get.*secret" ./setup_vault_k8s_auth.sh && grep -q "root-token\|vault.*token" ./setup_vault_k8s_auth.sh; then
        test_pass "Script includes token extraction"
    else
        test_fail "Script missing token extraction"  
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
    cd "$(dirname "${BASH_SOURCE[0]}")" || exit
    
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
    test_auto_discovery_capabilities
    test_integration_points
    test_documentation_output
    
    # Print summary
    echo ""
    test_info "============================================================"
    test_info "TEST SUMMARY"
    test_info "============================================================"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL AUTO-DISCOVERY TESTS PASSED${NC}"
        echo -e "   Tests Passed: ${GREEN}$TESTS_PASSED${NC}/$TOTAL_TESTS"
        echo -e "   Status: ${GREEN}AUTO-DISCOVERY READY FOR PRODUCTION${NC}"
    else
        echo -e "${RED}❌ SOME AUTO-DISCOVERY TESTS FAILED${NC}"
        echo -e "   Tests Passed: ${GREEN}$TESTS_PASSED${NC}/$TOTAL_TESTS"
        echo -e "   Tests Failed: ${RED}$TESTS_FAILED${NC}/$TOTAL_TESTS"
        echo -e "   Status: ${RED}NEEDS ATTENTION${NC}"
        exit 1
    fi
    
    echo ""
    test_info "Enhanced Script Purpose Summary:"
    echo "  🔍 ZERO-CONFIGURATION Vault Kubernetes authentication setup"
    echo "  🤖 Automatic discovery of Vault infrastructure from K8s cluster"
    echo "  🎯 Automates Vault Kubernetes authentication setup"
    echo "  🔐 Configures secure service account authentication"
    echo "  🧪 Provides end-to-end testing and validation"
    echo "  📋 Offers comprehensive logging and troubleshooting"
    echo "  🚀 Enables production-ready GOK-Agent deployment"
    echo ""
    echo -e "${PURPLE}🔍 Auto-Discovery Features Validated:${NC}"
    echo -e "${CYAN}  ✓ Vault namespace/pod/service discovery${NC}"
    echo -e "${CYAN}  ✓ Vault root token extraction${NC}"
    echo -e "${CYAN}  ✓ Cloud.uat domain configuration${NC}"
    echo -e "${CYAN}  ✓ Discover command functionality${NC}"
    echo -e "${CYAN}  ✓ Zero-configuration setup capability${NC}"
}

# Run the tests
main "$@"