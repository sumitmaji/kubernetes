#!/bin/bash

# HashiCorp Vault RabbitMQ Credential Management Script
# This script stores and manages RabbitMQ credentials in Vault

set -e

# Default configuration
VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-""}
VAULT_PATH=${VAULT_PATH:-"secret/rabbitmq"}
RABBITMQ_NAMESPACE=${RABBITMQ_NAMESPACE:-"rabbitmq"}
RABBITMQ_SECRET_NAME=${RABBITMQ_SECRET_NAME:-"rabbitmq-default-user"}

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

# Function to check if Vault is accessible
check_vault_status() {
    log_info "Checking Vault status..."
    
    if ! command -v vault &> /dev/null; then
        log_error "Vault CLI not found. Please install HashiCorp Vault."
        exit 1
    fi
    
    export VAULT_ADDR
    
    if [ -z "$VAULT_TOKEN" ]; then
        log_error "VAULT_TOKEN environment variable not set."
        log_info "Please set VAULT_TOKEN or login to Vault:"
        log_info "export VAULT_TOKEN=\$(vault auth -method=userpass username=myuser password=mypass)"
        exit 1
    fi
    
    export VAULT_TOKEN
    
    if ! vault status &> /dev/null; then
        log_error "Cannot connect to Vault at $VAULT_ADDR"
        log_info "Please ensure Vault is running and accessible."
        exit 1
    fi
    
    log_success "Vault is accessible at $VAULT_ADDR"
}

# Function to enable KV secrets engine if not already enabled
enable_kv_engine() {
    log_info "Checking KV secrets engine..."
    
    # Extract the mount path from VAULT_PATH (e.g., "secret" from "secret/rabbitmq")
    MOUNT_PATH=$(echo "$VAULT_PATH" | cut -d'/' -f1)
    
    if ! vault secrets list | grep -q "^${MOUNT_PATH}/"; then
        log_info "Enabling KV secrets engine at path: $MOUNT_PATH"
        vault secrets enable -path="$MOUNT_PATH" kv-v2
        log_success "KV secrets engine enabled at $MOUNT_PATH"
    else
        log_success "KV secrets engine already enabled at $MOUNT_PATH"
    fi
}

# Function to extract RabbitMQ credentials from Kubernetes
extract_k8s_credentials() {
    log_info "Extracting RabbitMQ credentials from Kubernetes..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Cannot extract credentials from Kubernetes."
        return 1
    fi
    
    # Check if the secret exists
    if ! kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" &> /dev/null; then
        log_error "Secret $RABBITMQ_SECRET_NAME not found in namespace $RABBITMQ_NAMESPACE"
        return 1
    fi
    
    # Extract credentials
    USERNAME=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
    PASSWORD=$(kubectl get secret "$RABBITMQ_SECRET_NAME" -n "$RABBITMQ_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        log_error "Failed to extract username or password from Kubernetes secret"
        return 1
    fi
    
    log_success "Successfully extracted credentials from Kubernetes"
    return 0
}

# Function to store credentials in Vault
store_credentials() {
    local username="$1"
    local password="$2"
    
    log_info "Storing RabbitMQ credentials in Vault at path: $VAULT_PATH"
    
    # Store credentials with additional metadata
    vault kv put "$VAULT_PATH" \
        username="$username" \
        password="$password" \
        created_at="$(date -Iseconds)" \
        source="kubernetes_secret" \
        namespace="$RABBITMQ_NAMESPACE"
    
    if [ $? -eq 0 ]; then
        log_success "Credentials stored successfully in Vault"
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
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  store-from-k8s    Extract credentials from Kubernetes and store in Vault"
    echo "  store             Store custom credentials in Vault (interactive)"
    echo "  retrieve          Retrieve and display credentials from Vault"
    echo "  test-connection   Test RabbitMQ connection using Vault credentials"
    echo "  rotate            Rotate RabbitMQ credentials in Vault"
    echo "  status            Check Vault status and configuration"
    echo "  help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  VAULT_ADDR                Vault server address (default: http://localhost:8200)"
    echo "  VAULT_TOKEN               Vault authentication token"
    echo "  VAULT_PATH                Path to store credentials (default: secret/rabbitmq)"
    echo "  RABBITMQ_NAMESPACE        Kubernetes namespace (default: rabbitmq)"
    echo "  RABBITMQ_SECRET_NAME      Kubernetes secret name (default: rabbitmq-default-user)"
    echo ""
    echo "Examples:"
    echo "  export VAULT_TOKEN=hvs.xyz..."
    echo "  $0 store-from-k8s"
    echo "  $0 test-connection"
    echo "  VAULT_PATH=secret/prod/rabbitmq $0 retrieve"
}

# Main execution
case "${1:-help}" in
    "store-from-k8s")
        check_vault_status
        enable_kv_engine
        if extract_k8s_credentials; then
            store_credentials "$USERNAME" "$PASSWORD"
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
    
    "help"|*)
        show_usage
        ;;
esac