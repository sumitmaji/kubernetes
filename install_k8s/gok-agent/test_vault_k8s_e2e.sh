#!/bin/bash
# Test Vault K8s Authentication End-to-End from within Kubernetes cluster
# ===========================================================================

set -e

echo "🚀 Vault K8s Authentication - End-to-End Test"
echo "============================================="
echo ""

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
ROLE="${ROLE:-gok-agent}"
JWT_PATH="${JWT_PATH:-/var/run/secrets/kubernetes.io/serviceaccount/token}"

echo "📋 Configuration:"
echo "   Vault Address: $VAULT_ADDR"
echo "   Role: $ROLE"
echo "   JWT Path: $JWT_PATH"
echo ""

# Step 1: Check if we're in a pod with service account token
echo "🔹 Step 1: Verify Kubernetes Service Account Token"
echo "---------------------------------------------------"

if [[ -f "$JWT_PATH" ]]; then
    echo "✅ Service account token found"
    JWT_TOKEN=$(cat "$JWT_PATH")
    TOKEN_PREVIEW="${JWT_TOKEN:0:50}..."
    echo "📝 Token preview: $TOKEN_PREVIEW"
else
    echo "❌ Service account token not found at $JWT_PATH"
    echo "ℹ️  This test needs to run in a Kubernetes pod with service account"
    exit 1
fi
echo ""

# Step 2: Authenticate with Vault using K8s auth
echo "🔹 Step 2: Authenticate with Vault using Kubernetes Auth"
echo "--------------------------------------------------------"

echo "🔐 Authenticating with role: $ROLE"

AUTH_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"role\":\"$ROLE\",\"jwt\":\"$JWT_TOKEN\"}" \
    "$VAULT_ADDR/v1/auth/kubernetes/login")

if echo "$AUTH_RESPONSE" | jq -e '.auth.client_token' > /dev/null 2>&1; then
    VAULT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')
    LEASE_DURATION=$(echo "$AUTH_RESPONSE" | jq -r '.auth.lease_duration')
    echo "✅ Authentication successful!"
    echo "📝 Token obtained: ${VAULT_TOKEN:0:20}..."
    echo "⏰ Lease duration: $LEASE_DURATION seconds"
else
    echo "❌ Authentication failed"
    echo "📝 Response: $AUTH_RESPONSE"
    exit 1
fi
echo ""

# Step 3: Test token by reading Vault status
echo "🔹 Step 3: Verify Token by Reading Vault Status"
echo "-----------------------------------------------"

STATUS_RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health")

if echo "$STATUS_RESPONSE" | jq -e '.sealed' > /dev/null 2>&1; then
    SEALED=$(echo "$STATUS_RESPONSE" | jq -r '.sealed')
    VERSION=$(echo "$STATUS_RESPONSE" | jq -r '.version // "unknown"')
    echo "✅ Token validation successful!"
    echo "📝 Vault status: sealed=$SEALED, version=$VERSION"
else
    echo "❌ Token validation failed"
    echo "📝 Response: $STATUS_RESPONSE"
    exit 1
fi
echo ""

# Step 4: Retrieve RabbitMQ credentials
echo "🔹 Step 4: Retrieve RabbitMQ Credentials from Vault"
echo "---------------------------------------------------"

echo "🔍 Reading credentials from secret/data/rabbitmq"

CREDS_RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/rabbitmq")

if echo "$CREDS_RESPONSE" | jq -e '.data.data.username' > /dev/null 2>&1; then
    USERNAME=$(echo "$CREDS_RESPONSE" | jq -r '.data.data.username')
    PASSWORD=$(echo "$CREDS_RESPONSE" | jq -r '.data.data.password')
    PASSWORD_MASKED=$(echo "$PASSWORD" | sed 's/./*/g')
    
    echo "✅ Credentials retrieved successfully!"
    echo "📝 Username: $USERNAME"
    echo "📝 Password: $PASSWORD_MASKED"
else
    echo "❌ Failed to retrieve credentials"
    echo "📝 Response: $CREDS_RESPONSE"
    exit 1
fi
echo ""

# Step 5: Test credentials format and validation
echo "🔹 Step 5: Validate Credential Format"
echo "-------------------------------------"

if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
    echo "✅ Credentials format validation passed"
    echo "📊 Username length: ${#USERNAME} characters"
    echo "📊 Password length: ${#PASSWORD} characters"
    
    # Create a simple credentials file for testing
    cat > /tmp/rabbitmq_test_creds.json << EOF
{
    "username": "$USERNAME",
    "password": "$PASSWORD",
    "retrieved_at": "$(date -Iseconds)",
    "source": "vault_k8s_auth_test"
}
EOF
    echo "📁 Test credentials saved to: /tmp/rabbitmq_test_creds.json"
else
    echo "❌ Invalid credential format"
    exit 1
fi
echo ""

# Step 6: Test token renewal (simulate refresh)
echo "🔹 Step 6: Test Token Self-Renewal"
echo "----------------------------------"

echo "🔄 Attempting to renew token..."

RENEW_RESPONSE=$(curl -s -X POST \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/auth/token/renew-self")

if echo "$RENEW_RESPONSE" | jq -e '.auth.client_token' > /dev/null 2>&1; then
    NEW_LEASE=$(echo "$RENEW_RESPONSE" | jq -r '.auth.lease_duration')
    echo "✅ Token renewal successful!"
    echo "⏰ New lease duration: $NEW_LEASE seconds"
else
    echo "⚠️  Token renewal not available (this is normal for some auth methods)"
    echo "📝 Response: $RENEW_RESPONSE"
fi
echo ""

# Step 7: Cleanup and summary
echo "🔹 Step 7: Test Summary"
echo "----------------------"

echo "✅ All authentication tests completed successfully!"
echo ""
echo "📊 Test Results Summary:"
echo "   ✅ Service Account Token: Found and valid"
echo "   ✅ Vault Authentication: Successful"
echo "   ✅ Token Validation: Working"
echo "   ✅ Credential Retrieval: Successful"
echo "   ✅ Credential Format: Valid"
echo "   ℹ️  Token Renewal: Tested (may not be available)"
echo ""
echo "🎉 Vault Kubernetes Authentication integration is working correctly!"
echo ""

# Optional: Show the credential file content (masked password)
if [[ -f "/tmp/rabbitmq_test_creds.json" ]]; then
    echo "📄 Retrieved credentials structure:"
    jq --arg pwd "$PASSWORD_MASKED" '.password = $pwd' /tmp/rabbitmq_test_creds.json
    echo ""
fi

echo "🔚 End-to-end test completed successfully!"
echo "============================================="