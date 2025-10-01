#!/bin/sh

# Simplified Vault K8s Auth Test Script for Vault Pod
# This script tests the setup_vault_k8s_auth.sh functionality from within the vault pod

echo "🧪 Testing setup_vault_k8s_auth.sh inside vault-0 pod"
echo "=================================================="

# Test 1: Check script exists and is executable
echo -n "1. Script exists and executable: "
if [ -f "/tmp/setup_vault_k8s_auth.sh" ] && [ -x "/tmp/setup_vault_k8s_auth.sh" ]; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Script not found or not executable"
    exit 1
fi

# Test 2: Test help functionality
echo -n "2. Help functionality: "
if /tmp/setup_vault_k8s_auth.sh --help 2>/dev/null | grep -q "Usage:"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 3: Test parameter validation (should fail without VAULT_TOKEN)
echo -n "3. Parameter validation: "
if /tmp/setup_vault_k8s_auth.sh 2>&1 | grep -q "VAULT_TOKEN.*required"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 4: Test with invalid argument
echo -n "4. Invalid argument handling: "
if /tmp/setup_vault_k8s_auth.sh invalid-arg 2>&1 | grep -q "Unknown argument"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 5: Check Vault CLI availability
echo -n "5. Vault CLI availability: "
if which vault >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 6: Check Vault status
echo -n "6. Vault server status: "
if vault status >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

# Test 7: Check existing Vault auth methods
echo -n "7. Vault auth methods: "
if vault auth list >/dev/null 2>&1; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Cannot access Vault auth methods"
    exit 1
fi

# Test 8: Check service account token availability
echo -n "8. Service account token: "
if [ -f "/var/run/secrets/kubernetes.io/serviceaccount/token" ]; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
    exit 1
fi

echo ""
echo "🎉 Basic tests passed! Now attempting to run the setup script with a created token..."
echo ""

# Try to create a token for testing (this might fail depending on permissions)
echo "🔐 Attempting to create a test token for validation..."

# Check if we can list existing policies
echo -n "Checking existing policies: "
if vault policy list >/dev/null 2>&1; then
    echo "✅ Can access policies"
    vault policy list | head -5
else
    echo "❌ Cannot access policies - need authentication"
fi

# Check if kubernetes auth is already configured
echo -n "Checking Kubernetes auth configuration: "
if vault read auth/kubernetes/config >/dev/null 2>&1; then
    echo "✅ Kubernetes auth is configured"
else
    echo "⚠️  Kubernetes auth not configured or needs authentication"
fi

# Show existing roles
echo -n "Checking existing roles: "
if vault list auth/kubernetes/role >/dev/null 2>&1; then
    echo "✅ Can list roles:"
    vault list auth/kubernetes/role
else
    echo "⚠️  Cannot list roles - may need authentication"
fi

echo ""
echo "📊 Test Summary:"
echo "================"
echo "• Script structure: ✅ Valid"  
echo "• Vault server: ✅ Running and accessible"
echo "• Service account token: ✅ Available"
echo "• Authentication: ⚠️  Would need valid VAULT_TOKEN for full test"
echo ""
echo "🎯 To fully test the script, you would need to:"
echo "1. Get a valid VAULT_TOKEN (root token or policy-enabled token)"
echo "2. Run: VAULT_TOKEN=your-token /tmp/setup_vault_k8s_auth.sh"
echo ""
echo "🔍 Current Vault Status:"
vault status 2>/dev/null || echo "Could not get vault status"
echo ""
echo "🔍 Current Auth Methods:"
vault auth list 2>/dev/null || echo "Could not list auth methods - need authentication"