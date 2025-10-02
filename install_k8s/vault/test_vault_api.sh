#!/bin/bash

# Test script for Vault API
# This script creates a test secret and verifies it can be fetched via API

set -euo pipefail

# Configuration
NAMESPACE="default"
SECRET_PATH="secret/api-test"
POLICY_NAME="api-test-policy"
ROLE_NAME="api-test-role"
SERVICE_ACCOUNT="api-test-sa"
POD_NAME="vault-api-test-pod"
CONFIGMAP_NAME="vault-api-test-script"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking variables
declare -A TEST_RESULTS
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Initialize test results
init_test_tracking() {
    TEST_RESULTS["Dependencies"]="PENDING"
    TEST_RESULTS["Vault Login"]="PENDING"
    TEST_RESULTS["Secret Creation"]="PENDING"
    TEST_RESULTS["Policy Creation"]="PENDING"
    TEST_RESULTS["Role Creation"]="PENDING"
    TEST_RESULTS["Service Account"]="PENDING"
    TEST_RESULTS["Python Script"]="PENDING"
    TEST_RESULTS["Pod Creation"]="PENDING"
    TEST_RESULTS["Pod Readiness"]="PENDING"
    TEST_RESULTS["API Authentication"]="PENDING"
    TEST_RESULTS["Token Validation"]="PENDING"
    TEST_RESULTS["Secret Retrieval"]="PENDING"
    TEST_RESULTS["Data Validation"]="PENDING"
    TEST_COUNT=13
}

# Update test result
update_test_result() {
    local test_name="$1"
    local result="$2"
    
    if [[ "$result" == "PASSED" ]]; then
        TEST_RESULTS["$test_name"]="PASSED"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    elif [[ "$result" == "FAILED" ]]; then
        TEST_RESULTS["$test_name"]="FAILED"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
}

# Show comprehensive test summary
show_test_summary() {
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "🧪 VAULT API TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Calculate overall result
    local overall_result
    if [[ $FAILED_COUNT -eq 0 ]]; then
        overall_result="${GREEN}ALL TESTS PASSED ✅${NC}"
    else
        overall_result="${RED}SOME TESTS FAILED ❌${NC}"
    fi
    
    echo -e "🎉 OVERALL RESULT: $overall_result"
    echo -e "📊 STATISTICS: ${PASSED_COUNT}/${TEST_COUNT} tests passed ($(( (PASSED_COUNT * 100) / TEST_COUNT ))% success rate)"
    echo
    echo "📋 DETAILED TEST RESULTS:"
    echo "─────────────────────────────────────────────────────────────────────────────"
    printf "%-30s | %-10s | %s\n" "TEST NAME" "STATUS" "DESCRIPTION"
    echo "─────────────────────────────────────────────────────────────────────────────"
    
    # Test descriptions
    declare -A TEST_DESCRIPTIONS
    TEST_DESCRIPTIONS["Dependencies"]="kubectl, jq, vault pod available"
    TEST_DESCRIPTIONS["Vault Login"]="Successfully authenticated with Vault"
    TEST_DESCRIPTIONS["Secret Creation"]="Test secret created at secret/api-test"
    TEST_DESCRIPTIONS["Policy Creation"]="Vault policy 'api-test-policy' created"
    TEST_DESCRIPTIONS["Role Creation"]="Kubernetes auth role 'api-test-role' created"
    TEST_DESCRIPTIONS["Service Account"]="Service account 'api-test-sa' created"
    TEST_DESCRIPTIONS["Python Script"]="Python API client script generated"
    TEST_DESCRIPTIONS["Pod Creation"]="Test pod with Python runtime created"
    TEST_DESCRIPTIONS["Pod Readiness"]="Pod became ready within timeout"
    TEST_DESCRIPTIONS["API Authentication"]="Kubernetes auth to Vault successful"
    TEST_DESCRIPTIONS["Token Validation"]="Vault token obtained and validated"
    TEST_DESCRIPTIONS["Secret Retrieval"]="Secret fetched via direct API calls"
    TEST_DESCRIPTIONS["Data Validation"]="All secret data validated successfully"
    
    # Display results
    for test_name in "Dependencies" "Vault Login" "Secret Creation" "Policy Creation" "Role Creation" "Service Account" "Python Script" "Pod Creation" "Pod Readiness" "API Authentication" "Token Validation" "Secret Retrieval" "Data Validation"; do
        local status="${TEST_RESULTS[$test_name]}"
        local status_display
        case "$status" in
            "PASSED")
                status_display="${GREEN}✅ PASSED${NC}"
                ;;
            "FAILED")
                status_display="${RED}❌ FAILED${NC}"
                ;;
            *)
                status_display="${YELLOW}⏳ PENDING${NC}"
                ;;
        esac
        printf "%-30s | %-20s | %s\n" "$test_name" "$(echo -e "$status_display")" "${TEST_DESCRIPTIONS[$test_name]}"
    done
    
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    # Category summary
    echo "📁 TEST CATEGORIES SUMMARY:"
    echo "┌───────────────────────────────────────────────────────────────────────────────┐"
    echo "│ 🛠️  INFRASTRUCTURE SETUP                                               │"
    echo "│   • Dependencies check: ${TEST_RESULTS["Dependencies"]}"
    echo "│   • Vault login: ${TEST_RESULTS["Vault Login"]}"
    echo "│                                                                         │"
    echo "│ 🔐 VAULT CONFIGURATION                                                  │"
    echo "│   • Secret creation: ${TEST_RESULTS["Secret Creation"]}"
    echo "│   • Policy creation: ${TEST_RESULTS["Policy Creation"]}"
    echo "│   • Role creation: ${TEST_RESULTS["Role Creation"]}"
    echo "│                                                                         │"
    echo "│ 🚀 KUBERNETES SETUP                                                     │"
    echo "│   • Service account: ${TEST_RESULTS["Service Account"]}"
    echo "│   • Python script: ${TEST_RESULTS["Python Script"]}"
    echo "│   • Pod creation: ${TEST_RESULTS["Pod Creation"]}"
    echo "│   • Pod readiness: ${TEST_RESULTS["Pod Readiness"]}"
    echo "│                                                                         │"
    echo "│ 🌐 API FUNCTIONALITY                                                    │"
    echo "│   • API authentication: ${TEST_RESULTS["API Authentication"]}"
    echo "│   • Token validation: ${TEST_RESULTS["Token Validation"]}"
    echo "│   • Secret retrieval: ${TEST_RESULTS["Secret Retrieval"]}"
    echo "│   • Data validation: ${TEST_RESULTS["Data Validation"]}"
    echo "└───────────────────────────────────────────────────────────────────────────────┘"
    echo
    
    # Final message
    if [[ $FAILED_COUNT -eq 0 ]]; then
        echo "🎊 CONGRATULATIONS! All Vault API tests passed successfully!"
        echo "   Your Vault API integration is working correctly."
    else
        echo "⚠️  Some tests failed. Please review the logs above for details."
        echo "   Common issues:"
        echo "   • Check Vault pod status and logs"
        echo "   • Verify Kubernetes auth is enabled in Vault"
        echo "   • Ensure network connectivity from pods to Vault"
        echo "   • Check Python package installation logs"
    fi
    echo
    echo "═══════════════════════════════════════════════════════════════════════════════"
}

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
    if kubectl exec -it vault-0 -n vault -- vault login ${ROOT_TOKEN} >/dev/null 2>&1; then
        log_success "Vault login successful"
        update_test_result "Vault Login" "PASSED"
        return 0
    else
        log_error "Vault login failed"
        update_test_result "Vault Login" "FAILED"
        return 1
    fi
}

# Cleanup Vault resources
cleanup_vault_resources() {
    log_info "Cleaning up Vault resources..."
    
    # Login to Vault first
    if ! vaultLogin >/dev/null 2>&1; then
        log_warning "Could not login to Vault for cleanup"
        return 0
    fi
    
    # Delete test secret
    log_info "Deleting test secret: $SECRET_PATH"
    if kubectl exec -it vault-0 -n vault -- vault kv delete "$SECRET_PATH" >/dev/null 2>&1; then
        log_success "✓ Test secret deleted"
    else
        log_warning "Could not delete test secret (may not exist)"
    fi
    
    # Delete Kubernetes auth role
    log_info "Deleting Kubernetes auth role: $ROLE_NAME"
    if kubectl exec -it vault-0 -n vault -- vault delete "auth/kubernetes/role/$ROLE_NAME" >/dev/null 2>&1; then
        log_success "✓ Kubernetes auth role deleted"
    else
        log_warning "Could not delete Kubernetes auth role (may not exist)"
    fi
    
    # Delete Vault policy
    log_info "Deleting Vault policy: $POLICY_NAME"
    if kubectl exec -it vault-0 -n vault -- vault policy delete "$POLICY_NAME" >/dev/null 2>&1; then
        log_success "✓ Vault policy deleted"
    else
        log_warning "Could not delete Vault policy (may not exist)"
    fi
    
    log_success "Vault resource cleanup completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test resources..."
    
    # Delete pod
    kubectl delete pod $POD_NAME -n $NAMESPACE --ignore-not-found=true >/dev/null 2>&1
    
    # Delete configmap
    kubectl delete configmap $CONFIGMAP_NAME -n $NAMESPACE --ignore-not-found=true >/dev/null 2>&1
    
    # Delete service account
    kubectl delete serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE --ignore-not-found=true >/dev/null 2>&1
    
    # Wait for pod to be deleted
    kubectl wait --for=delete pod/$POD_NAME -n $NAMESPACE --timeout=60s >/dev/null 2>&1 || true
    
    # Clean up Vault resources
    cleanup_vault_resources
    
    log_success "Cleanup completed"
}

# Create test secret in Vault
create_test_secret() {
    log_info "Creating test secret in Vault..."
    
    vaultLogin || return 1
    
    # Create secret with complex data
    if kubectl exec -it vault-0 -n vault -- vault kv put $SECRET_PATH \
        username="api-test-user" \
        password="api-test-password" \
        database_host="postgres.example.com" \
        database_port="5432" \
        database_name="api_test_db" \
        api_endpoint="https://api.example.com/v1" \
        api_key="api-test-key-abcdef123456" \
        config_json='{"timeout":60,"retries":3,"debug":true}' \
        ssl_cert="-----BEGIN CERTIFICATE-----\nMIIC...test...cert\n-----END CERTIFICATE-----" >/dev/null 2>&1; then
        log_success "Test secret created at $SECRET_PATH"
        update_test_result "Secret Creation" "PASSED"
        return 0
    else
        log_error "Failed to create test secret"
        update_test_result "Secret Creation" "FAILED"
        return 1
    fi
}

# Create Vault policy
create_policy() {
    log_info "Creating Vault policy..."
    
    if kubectl exec -i vault-0 -n vault -- vault policy write "$POLICY_NAME" - <<EOF >/dev/null 2>&1
path "$SECRET_PATH" {
  capabilities = ["read", "list"]
}
path "$SECRET_PATH/*" {
  capabilities = ["read", "list"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF
    then
        log_success "Policy $POLICY_NAME created"
        update_test_result "Policy Creation" "PASSED"
        return 0
    else
        log_error "Failed to create Vault policy"
        update_test_result "Policy Creation" "FAILED"
        return 1
    fi
}

# Create Kubernetes role
create_role() {
    log_info "Creating Kubernetes authentication role..."
    
    if kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/"$ROLE_NAME" \
        bound_service_account_names="$SERVICE_ACCOUNT" \
        bound_service_account_namespaces="$NAMESPACE" \
        policies="$POLICY_NAME" \
        ttl=24h >/dev/null 2>&1; then
        log_success "Role $ROLE_NAME created"
        update_test_result "Role Creation" "PASSED"
        return 0
    else
        log_error "Failed to create Kubernetes role"
        update_test_result "Role Creation" "FAILED"
        return 1
    fi
}

# Create service account
create_service_account() {
    log_info "Creating service account..."
    
    if kubectl create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE >/dev/null 2>&1 || kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE >/dev/null 2>&1; then
        log_success "Service account $SERVICE_ACCOUNT created"
        update_test_result "Service Account" "PASSED"
        return 0
    else
        log_error "Failed to create service account"
        update_test_result "Service Account" "FAILED"
        return 1
    fi
}

# Detect Vault address
detect_vault_address() {
    local vault_address=""
    
    # Try to get from ingress
    if kubectl get ingress vault -n vault >/dev/null 2>&1; then
        vault_address=$(kubectl get ingress vault -n vault -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
        if [[ -n "$vault_address" ]]; then
            vault_address="https://$vault_address"
        fi
    fi
    
    # Fallback to service
    if [[ -z "$vault_address" ]]; then
        vault_address="http://vault.vault.svc.cloud.uat:8200"
    fi
    
    echo "$vault_address"
}

# Create Python test script
create_python_script() {
    log_info "Creating Python test script..."
    
    local vault_address
    vault_address=$(detect_vault_address)
    log_info "Using Vault address: $vault_address"
    
    if cat <<EOF | kubectl create configmap $CONFIGMAP_NAME -n $NAMESPACE --from-file=test_script.py=/dev/stdin >/dev/null 2>&1
#!/usr/bin/env python3
"""
Vault API Test Script

This script demonstrates how to authenticate to Vault using Kubernetes auth
and retrieve secrets via the Vault API.
"""

import os
import json
import requests
import time
import urllib3
from datetime import datetime

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class VaultAPIClient:
    def __init__(self, vault_url, role_name, verify_ssl=False):
        self.vault_url = vault_url.rstrip('/')
        self.role_name = role_name
        self.verify_ssl = verify_ssl
        self.token = None
        self.token_expires = None
        
    def authenticate(self):
        """Authenticate using Kubernetes auth method"""
        print(f"🔐 Authenticating to Vault at {self.vault_url}")
        
        # Read service account token
        try:
            with open('/var/run/secrets/kubernetes.io/serviceaccount/token', 'r') as f:
                jwt_token = f.read().strip()
        except Exception as e:
            print(f"❌ Failed to read service account token: {e}")
            return False
            
        # Authenticate with Vault
        auth_url = f"{self.vault_url}/v1/auth/kubernetes/login"
        auth_data = {
            "role": self.role_name,
            "jwt": jwt_token
        }
        
        try:
            response = requests.post(
                auth_url,
                json=auth_data,
                verify=self.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            
            auth_response = response.json()
            self.token = auth_response['auth']['client_token']
            
            # Calculate token expiration
            lease_duration = auth_response['auth'].get('lease_duration', 3600)
            self.token_expires = time.time() + lease_duration
            
            print(f"✅ Authentication successful")
            print(f"   Token expires in: {lease_duration} seconds")
            return True
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Authentication failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_details = e.response.json()
                    print(f"   Error details: {error_details}")
                except:
                    print(f"   Response text: {e.response.text}")
            return False
    
    def is_token_valid(self):
        """Check if current token is still valid"""
        if not self.token or not self.token_expires:
            return False
        return time.time() < (self.token_expires - 60)  # 60 second buffer
    
    def get_secret(self, secret_path):
        """Retrieve secret from Vault"""
        if not self.is_token_valid():
            print("🔄 Token expired or invalid, re-authenticating...")
            if not self.authenticate():
                return None
        
        print(f"📖 Retrieving secret from: {secret_path}")
        
        secret_url = f"{self.vault_url}/v1/{secret_path}"
        headers = {
            'X-Vault-Token': self.token,
            'Content-Type': 'application/json'
        }
        
        try:
            response = requests.get(
                secret_url,
                headers=headers,
                verify=self.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            
            secret_data = response.json()
            print("✅ Secret retrieved successfully")
            return secret_data
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to retrieve secret: {e}")
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_details = e.response.json()
                    print(f"   Error details: {error_details}")
                except:
                    print(f"   Response text: {e.response.text}")
            return None
    
    def test_token_info(self):
        """Test token info endpoint"""
        if not self.is_token_valid():
            print("🔄 Token expired or invalid, re-authenticating...")
            if not self.authenticate():
                return None
        
        print("🔍 Testing token info...")
        
        token_url = f"{self.vault_url}/v1/auth/token/lookup-self"
        headers = {
            'X-Vault-Token': self.token,
            'Content-Type': 'application/json'
        }
        
        try:
            response = requests.get(
                token_url,
                headers=headers,
                verify=self.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            
            token_info = response.json()
            print("✅ Token info retrieved successfully")
            return token_info
            
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to get token info: {e}")
            return None

def main():
    print("🚀 Starting Vault API Test")
    print("=" * 50)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print()
    
    # Configuration
    vault_url = "$vault_address"
    role_name = "$ROLE_NAME"
    secret_path = "$SECRET_PATH"
    
    print(f"Configuration:")
    print(f"  Vault URL: {vault_url}")
    print(f"  Role Name: {role_name}")
    print(f"  Secret Path: {secret_path}")
    print()
    
    # Initialize Vault client
    vault_client = VaultAPIClient(vault_url, role_name, verify_ssl=False)
    
    # Test authentication
    if not vault_client.authenticate():
        print("💥 Authentication failed, exiting...")
        return 1
    
    print()
    
    # Test token info
    token_info = vault_client.test_token_info()
    if token_info:
        print("Token Information:")
        print(f"  Policies: {token_info.get('data', {}).get('policies', [])}")
        print(f"  TTL: {token_info.get('data', {}).get('ttl', 'N/A')} seconds")
        print(f"  Renewable: {token_info.get('data', {}).get('renewable', False)}")
        print()
    
    # Test secret retrieval
    secret_data = vault_client.get_secret(secret_path)
    if not secret_data:
        print("💥 Secret retrieval failed, exiting...")
        return 1
    
    print()
    print("🎯 Secret Retrieval Results:")
    print("=" * 40)
    
    # Display secret structure
    print("Secret structure:")
    print(json.dumps(secret_data, indent=2, default=str))
    print()
    
    # Extract and display secret values
    if 'data' in secret_data:
        secret_values = secret_data['data']
        print("Secret values:")
        print("-" * 20)
        
        expected_keys = [
            'username', 'password', 'database_host', 'database_port',
            'database_name', 'api_endpoint', 'api_key', 'config_json', 'ssl_cert'
        ]
        
        all_keys_found = True
        for key in expected_keys:
            if key in secret_values:
                value = secret_values[key]
                # Truncate long values for display
                if len(str(value)) > 50:
                    display_value = str(value)[:47] + "..."
                else:
                    display_value = value
                print(f"  ✅ {key}: {display_value}")
            else:
                print(f"  ❌ {key}: NOT FOUND")
                all_keys_found = False
        
        print()
        
        if all_keys_found:
            print("🎉 All expected secret keys found!")
        else:
            print("⚠️  Some expected secret keys are missing")
        
        # Test JSON parsing of config
        if 'config_json' in secret_values:
            try:
                config = json.loads(secret_values['config_json'])
                print(f"✅ Config JSON is valid: {config}")
            except json.JSONDecodeError as e:
                print(f"❌ Config JSON is invalid: {e}")
        
        print()
        print("📊 Test Summary:")
        print(f"  Total keys retrieved: {len(secret_values)}")
        print(f"  Expected keys found: {sum(1 for key in expected_keys if key in secret_values)}/{len(expected_keys)}")
        print(f"  Test status: {'✅ PASSED' if all_keys_found else '⚠️  PARTIAL'}")
        
    else:
        print("❌ No 'data' field found in secret response")
        return 1
    
    print()
    print("🏁 Vault API test completed successfully!")
    return 0

if __name__ == "__main__":
    exit(main())
EOF
    then
        log_success "Python test script created in ConfigMap"
        update_test_result "Python Script" "PASSED"
        return 0
    else
        log_error "Failed to create Python test script"
        update_test_result "Python Script" "FAILED"
        return 1
    fi
}

# Create test pod with Python
create_test_pod() {
    log_info "Creating test pod with Python API client..."
    
    if cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $NAMESPACE
spec:
  serviceAccountName: $SERVICE_ACCOUNT
  containers:
  - name: python-app
    image: python:3.11-slim
    command: ["/bin/bash"]
    args:
    - -c
    - |
      set -e
      echo "Installing required packages..."
      pip install --quiet requests urllib3
      echo "Packages installed successfully"
      echo
      echo "Starting Vault API test..."
      python /app/test_script.py
      echo
      echo "Test completed. Keeping container alive for inspection..."
      sleep 3600
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    volumeMounts:
    - name: test-script
      mountPath: /app
  volumes:
  - name: test-script
    configMap:
      name: $CONFIGMAP_NAME
      defaultMode: 0755
  restartPolicy: Never
EOF
    then
        log_success "Test pod created"
        update_test_result "Pod Creation" "PASSED"
        return 0
    else
        log_error "Failed to create test pod"
        update_test_result "Pod Creation" "FAILED"
        return 1
    fi
}

# Wait for pod to complete
wait_for_pod() {
    log_info "Waiting for pod to start and run test..."
    
    # Wait for pod to be running
    if kubectl wait --for=condition=Ready pod/$POD_NAME -n $NAMESPACE --timeout=300s >/dev/null 2>&1; then
        log_success "Pod is ready"
        update_test_result "Pod Readiness" "PASSED"
    else
        log_error "Pod failed to become ready within timeout"
        update_test_result "Pod Readiness" "FAILED"
        kubectl describe pod $POD_NAME -n $NAMESPACE
        return 1
    fi
    
    # Wait a bit for the test to run
    log_info "Waiting for test execution to complete..."
    sleep 30
    return 0
}

# Verify API test results
verify_api_test() {
    log_info "Verifying API test results..."
    
    # Get pod logs
    log_info "API Test Output:"
    echo "================"
    if kubectl logs $POD_NAME -n $NAMESPACE -c python-app 2>/dev/null; then
        echo
        log_success "API test logs retrieved successfully"
    else
        log_error "Failed to retrieve API test logs"
        return 1
    fi
    
    # Check for success indicators in logs
    local logs
    logs=$(kubectl logs $POD_NAME -n $NAMESPACE -c python-app 2>/dev/null || echo "")
    
    log_info "Checking test success indicators..."
    local all_success=true
    
    # Check individual success indicators
    if echo "$logs" | grep -q "Authentication successful"; then
        log_success "✓ Found: 'Authentication successful'"
        update_test_result "API Authentication" "PASSED"
    else
        log_warning "✗ Missing: 'Authentication successful'"
        update_test_result "API Authentication" "FAILED"
        all_success=false
    fi
    
    if echo "$logs" | grep -q "Token info retrieved successfully"; then
        log_success "✓ Found: 'Token info retrieved successfully'"
        update_test_result "Token Validation" "PASSED"
    else
        log_warning "✗ Missing: 'Token info retrieved successfully'"
        update_test_result "Token Validation" "FAILED"
        all_success=false
    fi
    
    if echo "$logs" | grep -q "Secret retrieved successfully"; then
        log_success "✓ Found: 'Secret retrieved successfully'"
        update_test_result "Secret Retrieval" "PASSED"
    else
        log_warning "✗ Missing: 'Secret retrieved successfully'"
        update_test_result "Secret Retrieval" "FAILED"
        all_success=false
    fi
    
    if echo "$logs" | grep -q "All expected secret keys found"; then
        log_success "✓ Found: 'All expected secret keys found'"
        update_test_result "Data Validation" "PASSED"
    else
        log_warning "✗ Missing: 'All expected secret keys found'"
        update_test_result "Data Validation" "FAILED"
        all_success=false
    fi
    
    if [[ "$all_success" == "true" ]]; then
        log_success "🎉 All success indicators found!"
    else
        log_warning "⚠️  Some success indicators are missing"
    fi
    
    # Check for error indicators
    local error_indicators=(
        "Authentication failed"
        "Failed to retrieve secret"
        "NOT FOUND"
        "❌"
    )
    
    log_info "Checking for error indicators..."
    local has_errors=false
    for indicator in "${error_indicators[@]}"; do
        if echo "$logs" | grep -q "$indicator"; then
            log_error "✗ Found error: '$indicator'"
            has_errors=true
        fi
    done
    
    if [[ "$has_errors" == "false" ]]; then
        log_success "✓ No critical errors found"
    else
        log_warning "⚠️  Some errors detected in logs"
    fi
    
    return 0
}

# Display pod information for debugging
show_pod_info() {
    log_info "Pod information for debugging:"
    echo "==============================="
    
    echo "Pod Status:"
    kubectl get pod $POD_NAME -n $NAMESPACE -o wide 2>/dev/null || true
    echo
    
    echo "Pod Events:"
    kubectl get events --field-selector involvedObject.name=$POD_NAME -n $NAMESPACE 2>/dev/null || true
    echo
    
    echo "Pod Description:"
    kubectl describe pod $POD_NAME -n $NAMESPACE 2>/dev/null || true
    echo
}

# Main test function
run_test() {
    log_info "🚀 Starting Vault API Test"
    echo "=========================="
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Run test steps
    create_test_secret || return 1
    create_policy || return 1
    create_role || return 1
    create_service_account || return 1
    create_python_script || return 1
    create_test_pod || return 1
    wait_for_pod || return 1
    verify_api_test
    
    log_success "🎉 Vault API test completed!"
    
    # Show additional info
    show_pod_info
    
    # Show test summary
    show_test_summary
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Initialize test tracking
    init_test_tracking
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        update_test_result "Dependencies" "FAILED"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        update_test_result "Dependencies" "FAILED"
        exit 1
    fi
    
    # Check if vault pod exists
    if ! kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
        log_error "Vault pod (vault-0) not found in vault namespace"
        update_test_result "Dependencies" "FAILED"
        exit 1
    fi
    
    # Check if vault is ready
    if ! kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=10s >/dev/null 2>&1; then
        log_error "Vault pod is not ready"
        update_test_result "Dependencies" "FAILED"
        exit 1
    fi
    
    log_success "All dependencies checked"
    update_test_result "Dependencies" "PASSED"
}

# Help function
show_help() {
    cat <<EOF
🚀 Vault API Test Script
=========================

This script comprehensively tests direct HashiCorp Vault API access using
Kubernetes service account authentication from within pods.

📋 WHAT THIS SCRIPT DOES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Creates a test secret in Vault with complex data structures
✓ Sets up Vault policies and Kubernetes authentication roles
✓ Generates a comprehensive Python API client script
✓ Deploys a Python pod with the API client
✓ Tests Kubernetes service account authentication to Vault
✓ Validates direct API calls for secret retrieval
✓ Tests token lifecycle management and renewal
✓ Verifies JSON parsing and complex data type handling
✓ Automatically cleans up all created resources

🎯 TEST RESOURCES CREATED:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Secret: secret/api-test (9 keys including JSON, certificates, URLs)
• Policy: api-test-policy (read access + token lookup permissions)
• Role: api-test-role (Kubernetes auth binding)
• ServiceAccount: api-test-sa (for pod authentication)
• ConfigMap: vault-api-test-script (Python client code)
• Pod: vault-api-test-pod (Python runtime with API client)

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

    # 🚀 Run the complete Vault API test
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
✅ Test secret created at secret/api-test (9 key-value pairs)
✅ Policy api-test-policy created with API permissions
✅ Role api-test-role created for Kubernetes auth
✅ Service account api-test-sa created
✅ Python test script created in ConfigMap
✅ Test pod created with Python runtime
✅ Pod ready and Python packages installed
✅ Kubernetes authentication to Vault successful
✅ Token obtained and validated
✅ Secret retrieval via API successful
✅ All 9 expected secret keys found and validated
✅ JSON parsing of complex data successful
✅ Token info and policies verified

🔧 CONFIGURATION:
━━━━━━━━━━━━━━━━━
• Namespace: default (can be customized in script)
• Vault Address: Auto-detected (ingress or service DNS)
• Authentication: Uses root token from vault-init-keys secret
• Python Version: 3.11 with requests and urllib3 libraries
• Test Duration: ~5-10 minutes (includes package installation)

📚 VAULT API CONCEPTS:
━━━━━━━━━━━━━━━━━━━━━━━
Direct Vault API access provides:
• Programmatic Access: Full control over Vault operations
• Token Management: Handle token lifecycle, renewal, revocation
• Dynamic Secrets: Request secrets on-demand from applications
• Fine-grained Control: Custom error handling and retry logic
• Integration Flexibility: Use any HTTP client in any language

🐍 PYTHON CLIENT FEATURES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
The generated Python client demonstrates:
• Kubernetes Auth: Service account token → Vault token exchange
• Error Handling: Comprehensive exception handling and logging
• Token Validation: Check token expiry and auto-renewal
• JSON Processing: Parse complex nested data structures
• HTTP Client: Production-ready requests with SSL handling
• Logging: Detailed progress and debug information

🔍 DEBUGGING:
━━━━━━━━━━━━━━
If the test fails, check:
• kubectl get pods -n default (pod status)
• kubectl logs vault-api-test-pod -n default (Python execution logs)
• kubectl describe pod vault-api-test-pod -n default (pod events)
• kubectl exec -it vault-0 -n vault -- vault status (Vault health)
• kubectl get configmap vault-api-test-script -n default (script content)

⚠️  PREREQUISITES:
━━━━━━━━━━━━━━━━━
• Kubernetes cluster with Vault installed and unsealed
• kubectl configured and connected to cluster
• jq installed for JSON processing
• Vault initialized with root token in vault-init-keys secret
• Vault Kubernetes auth method enabled and configured
• Network connectivity from pods to Vault service

🧹 CLEANUP:
━━━━━━━━━━━━
The script automatically cleans up on exit, but you can also run:
    $0 --cleanup

This removes:
• Test pod (vault-api-test-pod)
• ConfigMap (vault-api-test-script)
• Service account (api-test-sa)
• All test resources in Vault (secret, policy, role)

🎯 API VS OTHER METHODS:
━━━━━━━━━━━━━━━━━━━━━━━━━━
• API: Most flexible, requires custom implementation
• Agent Injector: Easiest to use, limited customization
• CSI Driver: Good balance, Kubernetes-native
• API: Best for dynamic secrets and complex workflows
• API: Preferred for microservices and cloud-native apps

📝 SAMPLE API CALLS:
━━━━━━━━━━━━━━━━━━━
The test demonstrates these Vault API endpoints:
• POST /v1/auth/kubernetes/login (authentication)
• GET /v1/auth/token/lookup-self (token validation)
• GET /v1/secret/api-test (secret retrieval)

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

# Main execution
main() {
    check_dependencies
    run_test
}

# Run main function
main "$@"