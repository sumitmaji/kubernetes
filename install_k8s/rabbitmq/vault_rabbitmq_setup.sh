#!/bin/bash

# HashiCorp Vault RabbitMQ Credential Management Script - Auto-Discovery Version
# This script automatically discovers Vault and RabbitMQ configuration and manages credentials

set -e

# Auto-discovered configuration (will be populated by discovery functions)
VAULT_NAMESPACE=""
VAULT_POD=""
VAULT_SERVICE_IP=""
VAULT_ROOT_TOKEN=""
RABBITMQ_DISCOVERED_NAMESPACE=""
RABBITMQ_DISCOVERED_SECRET=""

# Default configuration (fallbacks)
VAULT_ADDR=${VAULT_ADDR:-""}
VAULT_TOKEN=${VAULT_TOKEN:-""}
VAULT_PATH=${VAULT_PATH:-"secret/rabbitmq"}
RABBITMQ_NAMESPACE=${RABBITMQ_NAMESPACE:-""}
RABBITMQ_SECRET_NAME=${RABBITMQ_SECRET_NAME:-""}
SERVICE_ACCOUNT="gok-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Auto-Discovery Functions
auto_discover_vault_config() {
    log_info "Auto-discovering Vault configuration from Kubernetes cluster..."
    
    # Discover Vault namespace
    VAULT_NAMESPACE=$(kubectl get namespaces -o name 2>/dev/null | grep vault | head -1 | cut -d'/' -f2 || echo "vault")
    if ! kubectl get namespace "$VAULT_NAMESPACE" &> /dev/null; then
        log_error "Vault namespace '$VAULT_NAMESPACE' not found"
        return 1
    fi
    log_success "Found Vault namespace: $VAULT_NAMESPACE"
    
    # Discover Vault pod
    VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" -l "app.kubernetes.io/name=vault" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$VAULT_POD" ]; then
        VAULT_POD=$(kubectl get pods -n "$VAULT_NAMESPACE" 2>/dev/null | grep vault | grep -v agent | grep Running | head -1 | awk '{print $1}')
    fi
    if [ -z "$VAULT_POD" ]; then
        log_error "No running Vault pod found in namespace $VAULT_NAMESPACE"
        return 1
    fi
    log_success "Found Vault pod: $VAULT_POD"
    
    # Discover Vault service IP
    VAULT_SERVICE_IP=$(kubectl get service vault -n "$VAULT_NAMESPACE" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    if [ -z "$VAULT_SERVICE_IP" ]; then
        VAULT_SERVICE_IP=$(kubectl get services -n "$VAULT_NAMESPACE" 2>/dev/null | grep vault | grep -v agent | head -1 | awk '{print $3}')
    fi
    if [ -z "$VAULT_SERVICE_IP" ]; then
        log_error "Could not discover Vault service IP"
        return 1
    fi
    log_success "Found Vault service IP: $VAULT_SERVICE_IP"
    
    # Set Vault address if not provided
    if [ -z "$VAULT_ADDR" ]; then
        VAULT_ADDR="http://$VAULT_SERVICE_IP:8200"
        log_info "Auto-configured Vault address: $VAULT_ADDR"
    fi
    
    return 0
}

discover_vault_token() {
    log_info "Auto-discovering Vault root token..."
    
    # Try to find token in vault-init-keys secret (JSON format)
    local vault_init_json
    vault_init_json=$(kubectl get secret vault-init-keys -n "$VAULT_NAMESPACE" -o jsonpath='{.data.vault-init\.json}' 2>/dev/null | base64 -d 2>/dev/null)
    if [[ -n "$vault_init_json" ]]; then
        VAULT_ROOT_TOKEN=$(echo "$vault_init_json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('root_token', ''))" 2>/dev/null)
        if [[ -n "$VAULT_ROOT_TOKEN" && "$VAULT_ROOT_TOKEN" =~ ^hvs\. ]]; then
            log_success "Root token discovered from vault-init-keys"
            VAULT_TOKEN="$VAULT_ROOT_TOKEN"
            return 0
        fi
    fi
    
    # Try other secret locations
    local secret_candidates=("vault-init-keys" "vault-keys" "vault-root-token" "vault-token")
    local token_keys=("root-token" "root_token" "token" "vault-root" "vault-token")
    
    for secret_name in "${secret_candidates[@]}"; do
        if kubectl get secret "$secret_name" -n "$VAULT_NAMESPACE" &> /dev/null; then
            for token_key in "${token_keys[@]}"; do
                local token_value
                token_value=$(kubectl get secret "$secret_name" -n "$VAULT_NAMESPACE" -o jsonpath="{.data.$token_key}" 2>/dev/null | base64 -d 2>/dev/null | tr -d '\n')
                if [ -n "$token_value" ] && [[ "$token_value" =~ ^[a-zA-Z0-9._-]+$ ]] && [ ${#token_value} -gt 10 ]; then
                    log_success "Vault token discovered from $secret_name.$token_key"
                    VAULT_ROOT_TOKEN="$token_value"
                    VAULT_TOKEN="$token_value"
                    return 0
                fi
            done
        fi
    done
    
    log_warning "Could not auto-discover Vault root token"
    return 1
}

auto_discover_rabbitmq_config() {
    log_info "Auto-discovering RabbitMQ configuration..."
    
    # Discover RabbitMQ namespace
    if [ -z "$RABBITMQ_NAMESPACE" ]; then
        RABBITMQ_DISCOVERED_NAMESPACE=$(kubectl get namespaces -o name 2>/dev/null | grep rabbitmq | head -1 | cut -d'/' -f2 || echo "rabbitmq")
        if kubectl get namespace "$RABBITMQ_DISCOVERED_NAMESPACE" &> /dev/null; then
            RABBITMQ_NAMESPACE="$RABBITMQ_DISCOVERED_NAMESPACE"
            log_success "Found RabbitMQ namespace: $RABBITMQ_NAMESPACE"
        else
            RABBITMQ_NAMESPACE="rabbitmq"  # fallback
            log_warning "Using default RabbitMQ namespace: $RABBITMQ_NAMESPACE"
        fi
    fi
    
    # Discover RabbitMQ secret name
    if [ -z "$RABBITMQ_SECRET_NAME" ]; then
        # Try to find RabbitMQ-related secrets
        local secret_candidates=("rabbitmq-default-user" "rabbitmq-auth" "rabbitmq-secret" "rabbitmq")
        for secret_name in "${secret_candidates[@]}"; do
            if kubectl get secret "$secret_name" -n "$RABBITMQ_NAMESPACE" &> /dev/null; then
                RABBITMQ_DISCOVERED_SECRET="$secret_name"
                RABBITMQ_SECRET_NAME="$secret_name"
                log_success "Found RabbitMQ secret: $secret_name"
                break
            fi
        done
        
        if [ -z "$RABBITMQ_SECRET_NAME" ]; then
            # List all secrets in RabbitMQ namespace and try to find one with credentials
            local all_secrets
            all_secrets=$(kubectl get secrets -n "$RABBITMQ_NAMESPACE" --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep -E "(rabbitmq|rabbit|auth|user)" | head -1)
            if [ -n "$all_secrets" ]; then
                RABBITMQ_SECRET_NAME="$all_secrets"
                log_success "Found RabbitMQ-related secret: $RABBITMQ_SECRET_NAME"
            else
                RABBITMQ_SECRET_NAME="rabbitmq-default-user"  # fallback
                log_warning "Using default RabbitMQ secret name: $RABBITMQ_SECRET_NAME"
            fi
        fi
    fi
    
    return 0
}

run_auto_discovery() {
    log_info "Running complete auto-discovery process..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Auto-discovery requires kubectl access to Kubernetes cluster."
        return 1
    fi
    
    # Test kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check kubectl configuration."
        return 1
    fi
    log_success "Connected to Kubernetes cluster"
    
    # Run discovery functions
    if ! auto_discover_vault_config; then
        log_error "Failed to discover Vault configuration"
        return 1
    fi
    
    if ! discover_vault_token; then
        log_warning "Could not auto-discover Vault token - manual token may be required"
    fi
    
    if ! auto_discover_rabbitmq_config; then
        log_error "Failed to discover RabbitMQ configuration"
        return 1
    fi
    
    # Display discovered configuration
    echo ""
    log_info "=== AUTO-DISCOVERY RESULTS ==="
    log_info "Vault Namespace: $VAULT_NAMESPACE"
    log_info "Vault Pod: $VAULT_POD"
    log_info "Vault Address: $VAULT_ADDR"
    log_info "Vault Token: $([ -n "$VAULT_TOKEN" ] && echo "[DISCOVERED]" || echo "[NOT FOUND]")"
    log_info "RabbitMQ Namespace: $RABBITMQ_NAMESPACE"
    log_info "RabbitMQ Secret: $RABBITMQ_SECRET_NAME"
    log_info "Storage Path: $VAULT_PATH"
    echo ""
    
    return 0
}

# Function to check if Vault is accessible
check_vault_status() {
    log_info "Checking Vault status with auto-discovered configuration..."
    
    # Run auto-discovery first if not already done
    if [ -z "$VAULT_NAMESPACE" ] || [ -z "$VAULT_ADDR" ]; then
        log_info "Running auto-discovery..."
        if ! run_auto_discovery; then
            log_error "Auto-discovery failed. Cannot proceed without Vault configuration."
            exit 1
        fi
    fi
    
    if ! command -v vault &> /dev/null; then
        log_warning "Vault CLI not found. Attempting to use curl for API access..."
        
        # Test Vault connectivity using curl
        if curl -s --connect-timeout 5 "$VAULT_ADDR/v1/sys/health" > /dev/null; then
            log_success "Vault is accessible at $VAULT_ADDR (using curl)"
            VAULT_CLI_AVAILABLE=false
            return 0
        else
            log_error "Cannot connect to Vault at $VAULT_ADDR"
            log_info "Either install Vault CLI or ensure Vault is accessible"
            exit 1
        fi
    fi
    
    export VAULT_ADDR
    
    if [ -z "$VAULT_TOKEN" ]; then
        log_error "No Vault token available after auto-discovery."
        log_info "Please set VAULT_TOKEN manually or ensure token is available in cluster:"
        log_info "export VAULT_TOKEN=<your-vault-token>"
        exit 1
    fi
    
    export VAULT_TOKEN
    VAULT_CLI_AVAILABLE=true
    
    if ! vault status &> /dev/null; then
        log_warning "Vault CLI cannot connect, trying curl..."
        if curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" > /dev/null; then
            log_success "Vault is accessible at $VAULT_ADDR (using curl)"
            VAULT_CLI_AVAILABLE=false
        else
            log_error "Cannot connect to Vault at $VAULT_ADDR"
            log_info "Please ensure Vault is running and accessible."
            exit 1
        fi
    else
        log_success "Vault is accessible at $VAULT_ADDR (using CLI)"
    fi
}

# Function to enable KV secrets engine if not already enabled
enable_kv_engine() {
    log_info "Checking KV secrets engine..."
    
    # Extract the mount path from VAULT_PATH (e.g., "secret" from "secret/rabbitmq")
    MOUNT_PATH=$(echo "$VAULT_PATH" | cut -d'/' -f1)
    
    if [ "$VAULT_CLI_AVAILABLE" = "true" ]; then
        if ! vault secrets list | grep -q "^${MOUNT_PATH}/"; then
            log_info "Enabling KV secrets engine at path: $MOUNT_PATH"
            vault secrets enable -path="$MOUNT_PATH" kv-v2
            log_success "KV secrets engine enabled at $MOUNT_PATH"
        else
            log_success "KV secrets engine already enabled at $MOUNT_PATH"
        fi
    else
        # Using curl - check if mount exists
        local mounts_response
        mounts_response=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/mounts" 2>/dev/null)
        if echo "$mounts_response" | grep -q "\"${MOUNT_PATH}/\""; then
            log_success "KV secrets engine already enabled at $MOUNT_PATH"
        else
            log_info "Enabling KV secrets engine at path: $MOUNT_PATH (using curl)"
            curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"type":"kv-v2"}' \
                "$VAULT_ADDR/v1/sys/mounts/$MOUNT_PATH" > /dev/null
            if [ $? -eq 0 ]; then
                log_success "KV secrets engine enabled at $MOUNT_PATH"
            else
                log_warning "Failed to enable KV engine via curl - it may already exist"
            fi
        fi
    fi
}

# Function to extract RabbitMQ credentials from Kubernetes
extract_k8s_credentials() {
    log_info "Extracting RabbitMQ credentials from auto-discovered Kubernetes configuration..."
    
    # Ensure auto-discovery has run
    if [ -z "$RABBITMQ_NAMESPACE" ] || [ -z "$RABBITMQ_SECRET_NAME" ]; then
        log_info "Running RabbitMQ auto-discovery..."
        if ! auto_discover_rabbitmq_config; then
            log_error "Failed to discover RabbitMQ configuration"
            return 1
        fi
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Cannot extract credentials from Kubernetes."
        return 1
    fi
    
    # Check if the secret exists
    if ! kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" &> /dev/null; then
        log_error "Secret $RABBITMQ_SECRET_NAME not found in namespace $RABBITMQ_NAMESPACE"
        log_info "Available secrets in namespace $RABBITMQ_NAMESPACE:"
        kubectl get secrets -n "$RABBITMQ_NAMESPACE" --no-headers -o custom-columns=":metadata.name" 2>/dev/null | head -10
        return 1
    fi
    
    log_success "Found secret: $RABBITMQ_SECRET_NAME in namespace: $RABBITMQ_NAMESPACE"
    
    # Extract credentials with better error handling
    USERNAME=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null)
    PASSWORD=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        log_warning "Failed to extract username/password with standard keys. Trying alternative keys..."
        
        # Try alternative key names
        local alt_keys=("user" "default_user" "admin" "auth_user")
        for key in "${alt_keys[@]}"; do
            USERNAME=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null)
            if [ -n "$USERNAME" ]; then
                log_info "Found username with key: $key"
                break
            fi
        done
        
        local alt_pass_keys=("pass" "default_pass" "auth_password" "secret")
        for key in "${alt_pass_keys[@]}"; do
            PASSWORD=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null)
            if [ -n "$PASSWORD" ]; then
                log_info "Found password with key: $key"
                break
            fi
        done
    fi
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        log_error "Failed to extract username or password from Kubernetes secret"
        log_info "Available keys in secret:"
        kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "Could not list keys"
        return 1
    fi
    
    log_success "Successfully extracted credentials from Kubernetes"
    log_info "Username: $USERNAME"
    log_info "Password length: ${#PASSWORD} characters"
    return 0
}

# Function to store credentials in Vault
store_credentials() {
    local username="$1"
    local password="$2"
    
    log_info "Storing RabbitMQ credentials in Vault at path: $VAULT_PATH"
    
    if [ "$VAULT_CLI_AVAILABLE" = "true" ]; then
        # Store credentials with additional metadata using Vault CLI
        vault kv put "$VAULT_PATH" \
            username="$username" \
            password="$password" \
            created_at="$(date -Iseconds)" \
            source="kubernetes_secret" \
            namespace="$RABBITMQ_NAMESPACE" \
            vault_namespace="$VAULT_NAMESPACE" \
            discovered_by="auto_discovery"
    else
        # Store credentials using curl API
        local json_data
        json_data=$(cat <<EOF
{
  "data": {
    "username": "$username",
    "password": "$password",
    "created_at": "$(date -Iseconds)",
    "source": "kubernetes_secret",
    "namespace": "$RABBITMQ_NAMESPACE",
    "vault_namespace": "$VAULT_NAMESPACE",
    "discovered_by": "auto_discovery"
  }
}
EOF
        )
        
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$json_data" \
            "$VAULT_ADDR/v1/$VAULT_PATH" > /dev/null
    fi
    
    if [ $? -eq 0 ]; then
        log_success "Credentials stored successfully in Vault"
        log_info "Storage details:"
        log_info "  Path: $VAULT_PATH"
        log_info "  Username: $username"
        log_info "  Source: kubernetes_secret ($RABBITMQ_NAMESPACE/$RABBITMQ_SECRET_NAME)"
        log_info "  Method: $([ "$VAULT_CLI_AVAILABLE" = "true" ] && echo "Vault CLI" || echo "Vault API")"
    else
        log_error "Failed to store credentials in Vault"
        exit 1
    fi
}

# Function to retrieve credentials from Vault
retrieve_credentials() {
    log_info "Retrieving RabbitMQ credentials from Vault..."
    
    # Get the secret
    SECRET_JSON=$(vault kv get -format=json "$VAULT_PATH" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to retrieve credentials from Vault path: $VAULT_PATH"
        return 1
    fi
    
    # Extract username and password
    VAULT_USERNAME=$(echo "$SECRET_JSON" | jq -r '.data.data.username')
    VAULT_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.data.data.password')
    CREATED_AT=$(echo "$SECRET_JSON" | jq -r '.data.data.created_at // "unknown"')
    
    if [ "$VAULT_USERNAME" = "null" ] || [ "$VAULT_PASSWORD" = "null" ]; then
        log_error "Invalid credentials retrieved from Vault"
        return 1
    fi
    
    log_success "Successfully retrieved credentials from Vault"
    log_info "Username: $VAULT_USERNAME"
    log_info "Created at: $CREATED_AT"
    
    return 0
}

# Function to test RabbitMQ connection using Vault credentials
test_rabbitmq_connection() {
    log_info "Testing RabbitMQ connection using Vault credentials..."
    
    if ! retrieve_credentials; then
        return 1
    fi
    
    # Test connection using Python (requires pika)
    python3 -c "
import pika
import sys

try:
    credentials = pika.PlainCredentials('$VAULT_USERNAME', '$VAULT_PASSWORD')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host='rabbitmq.rabbitmq', credentials=credentials)
    )
    connection.close()
    print('✓ RabbitMQ connection test successful')
    sys.exit(0)
except Exception as e:
    print(f'✗ RabbitMQ connection test failed: {e}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        log_success "RabbitMQ connection test passed"
        return 0
    else
        log_error "RabbitMQ connection test failed"
        return 1
    fi
}

# Function to rotate credentials
rotate_credentials() {
    log_info "Rotating RabbitMQ credentials..."
    
    # Generate new password
    NEW_PASSWORD=$(openssl rand -base64 32)
    
    # For this example, we'll keep the same username but generate new password
    if retrieve_credentials; then
        NEW_USERNAME="$VAULT_USERNAME"
    else
        log_error "Cannot retrieve current credentials for rotation"
        return 1
    fi
    
    # Store new credentials with rotation metadata
    vault kv put "$VAULT_PATH" \
        username="$NEW_USERNAME" \
        password="$NEW_PASSWORD" \
        created_at="$(date -Iseconds)" \
        source="credential_rotation" \
        previous_rotation="$(date -Iseconds)" \
        namespace="$RABBITMQ_NAMESPACE"
    
    log_success "Credentials rotated successfully"
    log_warning "Note: You may need to update the RabbitMQ server with new credentials"
}

# Function to display usage
show_usage() {
    echo "========================================="
    echo "🔐 Vault RabbitMQ Setup - Auto-Discovery"
    echo "========================================="
    echo "This script automatically discovers Vault and RabbitMQ configuration"
    echo "from your Kubernetes cluster and manages credentials seamlessly."
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "🚀 AUTOMATED COMMANDS (No configuration required):"
    echo "  discover          Auto-discover all Vault and RabbitMQ configuration"
    echo "  store-from-k8s    Auto-discover and migrate credentials K8s → Vault" 
    echo "  test-connection   Auto-discover and test RabbitMQ connectivity"
    echo "  status            Auto-discover and show complete configuration"
    echo ""
    echo "🔧 MANUAL COMMANDS:"
    echo "  store             Store custom credentials in Vault (interactive)"
    echo "  retrieve          Retrieve and display credentials from Vault"
    echo "  rotate            Rotate RabbitMQ credentials in Vault"
    echo "  help              Show this help message"
    echo ""
    echo "🔍 AUTO-DISCOVERY FEATURES:"
    echo "  ✅ Vault namespace, pod, and service IP detection"
    echo "  ✅ Vault root token extraction from cluster secrets"
    echo "  ✅ RabbitMQ namespace and secret auto-detection"
    echo "  ✅ Credential key name discovery and validation"
    echo "  ✅ Works with or without Vault CLI installed"
    echo ""
    echo "🌍 Environment Variables (Optional - Auto-discovered if not set):"
    echo "  VAULT_ADDR                Vault server address"
    echo "  VAULT_TOKEN               Vault authentication token"
    echo "  VAULT_PATH                Vault storage path (default: secret/rabbitmq)"
    echo "  RABBITMQ_NAMESPACE        Kubernetes namespace"
    echo "  RABBITMQ_SECRET_NAME      Kubernetes secret name"
    echo ""
    echo "📋 ZERO-CONFIGURATION EXAMPLES:"
    echo "  $0 discover                    # Discover all configuration"
    echo "  $0 store-from-k8s             # Auto-migrate credentials"
    echo "  $0 test-connection            # Auto-test connectivity"
    echo ""
    echo "🔧 MANUAL CONFIGURATION EXAMPLES:"
    echo "  export VAULT_TOKEN=hvs.xyz..."
    echo "  VAULT_PATH=secret/prod/rabbitmq $0 store-from-k8s"
    echo ""
    echo "💡 Pro Tips:"
    echo "  • No manual configuration needed - just run the commands!"
    echo "  • Script auto-discovers Vault and RabbitMQ from your cluster"
    echo "  • Works from outside cluster (requires kubectl access)"
    echo "  • Supports both Vault CLI and direct API access"
}

# Main execution
case "${1:-help}" in
    "store-from-k8s")
        log_info "Starting automated credential migration from Kubernetes to Vault..."
        echo ""
        
        # Run complete auto-discovery
        if ! run_auto_discovery; then
            log_error "Auto-discovery failed. Cannot proceed."
            exit 1
        fi
        
        check_vault_status
        enable_kv_engine
        
        if extract_k8s_credentials; then
            store_credentials "$USERNAME" "$PASSWORD"
            log_success "✅ Credential migration completed successfully!"
            echo ""
            log_info "📋 Summary:"
            log_info "  Source: Kubernetes secret $RABBITMQ_SECRET_NAME in namespace $RABBITMQ_NAMESPACE"
            log_info "  Destination: Vault path $VAULT_PATH at $VAULT_ADDR"
            log_info "  Username: $USERNAME"
            log_info "  Discovery: Fully automated"
        else
            log_error "Failed to extract credentials from Kubernetes"
            exit 1
        fi
        ;;
    
    "store")
        check_vault_status
        enable_kv_engine
        
        echo -n "Enter RabbitMQ username: "
        read -r USERNAME
        echo -n "Enter RabbitMQ password: "
        read -s PASSWORD
        echo
        
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            store_credentials "$USERNAME" "$PASSWORD"
        else
            log_error "Username and password cannot be empty"
            exit 1
        fi
        ;;
    
    "retrieve")
        check_vault_status
        retrieve_credentials
        ;;
    
    "test-connection")
        check_vault_status
        test_rabbitmq_connection
        ;;
    
    "rotate")
        check_vault_status
        rotate_credentials
        ;;
    
    "status")
        check_vault_status
        log_info "Vault Address: $VAULT_ADDR"
        log_info "Vault Path: $VAULT_PATH"
        log_info "RabbitMQ Namespace: $RABBITMQ_NAMESPACE"
        log_info "RabbitMQ Secret Name: $RABBITMQ_SECRET_NAME"
        ;;
    
    "discover"|"auto-discover")
        log_info "Running auto-discovery to detect Vault and RabbitMQ configuration..."
        if run_auto_discovery; then
            log_success "✅ Auto-discovery completed successfully!"
            echo ""
            log_info "💡 Next steps:"
            log_info "  1. Run: $0 store-from-k8s    # Migrate credentials to Vault"
            log_info "  2. Run: $0 test-connection   # Test RabbitMQ connectivity"
        else
            log_error "❌ Auto-discovery failed"
            exit 1
        fi
        ;;
    
    "help"|*)
        show_usage
        ;;
esac