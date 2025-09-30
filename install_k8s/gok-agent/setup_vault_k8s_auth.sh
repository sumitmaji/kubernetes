#!/bin/bash

# Vault Kubernetes Authentication Setup Script
# This script configures Vault to authenticate Kubernetes Service Accounts

set -e

# Configuration variables
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
K8S_AUTH_PATH="${K8S_AUTH_PATH:-kubernetes}"
VAULT_ROLE="${VAULT_ROLE:-gok-agent}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-gok-agent}"
SERVICE_ACCOUNT_NAMESPACE="${SERVICE_ACCOUNT_NAMESPACE:-default}"
POLICY_NAME="${POLICY_NAME:-rabbitmq-policy}"
SECRET_PATH="${SECRET_PATH:-secret/data/rabbitmq}"
TOKEN_TTL="${TOKEN_TTL:-24h}"

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

# Check if running in Kubernetes cluster
check_k8s_environment() {
    if [[ -f "/var/run/secrets/kubernetes.io/serviceaccount/token" ]]; then
        log_info "Running inside Kubernetes cluster"
        K8S_HOST="https://kubernetes.default.svc.cluster.local"
        K8S_CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        K8S_JWT_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
        return 0
    else
        log_warning "Not running in Kubernetes cluster"
        return 1
    fi
}

# Get Kubernetes configuration from kubectl
get_k8s_config_from_kubectl() {
    log_info "Getting Kubernetes configuration from kubectl"
    
    # Get the cluster info
    K8S_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.server}')
    
    # Get the CA certificate
    kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > /tmp/k8s-ca.crt
    K8S_CA_CERT="/tmp/k8s-ca.crt"
    
    # Create a service account token (if needed)
    if kubectl get serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" >/dev/null 2>&1; then
        log_info "Service account $SERVICE_ACCOUNT_NAME exists in namespace $SERVICE_ACCOUNT_NAMESPACE"
        # Get token using kubectl (K8s 1.24+)
        if command -v kubectl >/dev/null 2>&1; then
            K8S_JWT_TOKEN=$(kubectl create token "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" --duration=1h 2>/dev/null || echo "")
            if [[ -z "$K8S_JWT_TOKEN" ]]; then
                log_warning "Could not create service account token. Using cluster-admin token for setup."
                K8S_JWT_TOKEN=$(kubectl get secret $(kubectl get serviceaccount default -n default -o jsonpath='{.secrets[0].name}') -n default -o jsonpath='{.data.token}' | base64 --decode 2>/dev/null || echo "")
            fi
        fi
    else
        log_error "Service account $SERVICE_ACCOUNT_NAME not found in namespace $SERVICE_ACCOUNT_NAMESPACE"
        return 1
    fi
    
    if [[ -z "$K8S_JWT_TOKEN" ]]; then
        log_error "Could not obtain Kubernetes JWT token"
        return 1
    fi
    
    log_success "Successfully obtained Kubernetes configuration"
    return 0
}

# Check Vault connection
check_vault_connection() {
    log_info "Checking Vault connection to $VAULT_ADDR"
    
    if ! command -v vault >/dev/null 2>&1; then
        log_error "Vault CLI not found. Please install vault CLI."
        return 1
    fi
    
    export VAULT_ADDR
    export VAULT_TOKEN
    
    if ! vault status >/dev/null 2>&1; then
        log_error "Cannot connect to Vault at $VAULT_ADDR"
        return 1
    fi
    
    log_success "Connected to Vault successfully"
    return 0
}

# Enable Kubernetes auth method
enable_kubernetes_auth() {
    log_info "Enabling Kubernetes auth method"
    
    if vault auth list | grep -q "^${K8S_AUTH_PATH}/"; then
        log_warning "Kubernetes auth method already enabled at path: $K8S_AUTH_PATH"
    else
        vault auth enable -path="$K8S_AUTH_PATH" kubernetes
        log_success "Enabled Kubernetes auth method at path: $K8S_AUTH_PATH"
    fi
}

# Configure Kubernetes auth method
configure_kubernetes_auth() {
    log_info "Configuring Kubernetes auth method"
    
    vault write "auth/${K8S_AUTH_PATH}/config" \
        token_reviewer_jwt="$K8S_JWT_TOKEN" \
        kubernetes_host="$K8S_HOST" \
        kubernetes_ca_cert=@"$K8S_CA_CERT"
    
    log_success "Configured Kubernetes auth method"
}

# Create Vault policy for RabbitMQ access
create_vault_policy() {
    log_info "Creating Vault policy: $POLICY_NAME"
    
    cat > /tmp/rabbitmq-policy.hcl << EOF
# Allow reading RabbitMQ credentials
path "${SECRET_PATH}" {
  capabilities = ["read"]
}

# Allow reading metadata
path "${SECRET_PATH%/data/*}/metadata/*" {
  capabilities = ["read"]
}

# Allow listing secrets (optional)
path "${SECRET_PATH%/data/*}/metadata" {
  capabilities = ["list"]
}
EOF
    
    vault policy write "$POLICY_NAME" /tmp/rabbitmq-policy.hcl
    rm -f /tmp/rabbitmq-policy.hcl
    
    log_success "Created Vault policy: $POLICY_NAME"
}

# Create Vault role for service account
create_vault_role() {
    log_info "Creating Vault role: $VAULT_ROLE"
    
    vault write "auth/${K8S_AUTH_PATH}/role/${VAULT_ROLE}" \
        bound_service_account_names="$SERVICE_ACCOUNT_NAME" \
        bound_service_account_namespaces="$SERVICE_ACCOUNT_NAMESPACE" \
        policies="$POLICY_NAME" \
        ttl="$TOKEN_TTL"
    
    log_success "Created Vault role: $VAULT_ROLE"
}

# Test the authentication setup
test_authentication() {
    log_info "Testing Kubernetes Service Account authentication"
    
    # Get a fresh service account token for testing
    if command -v kubectl >/dev/null 2>&1 && kubectl get serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" >/dev/null 2>&1; then
        local test_token=$(kubectl create token "$SERVICE_ACCOUNT_NAME" -n "$SERVICE_ACCOUNT_NAMESPACE" --duration=1h 2>/dev/null)
        
        if [[ -n "$test_token" ]]; then
            log_info "Testing authentication with fresh service account token"
            
            # Test authentication
            local auth_response=$(vault write -format=json "auth/${K8S_AUTH_PATH}/login" \
                role="$VAULT_ROLE" \
                jwt="$test_token" 2>/dev/null)
            
            if [[ $? -eq 0 ]]; then
                local client_token=$(echo "$auth_response" | jq -r '.auth.client_token')
                local lease_duration=$(echo "$auth_response" | jq -r '.auth.lease_duration')
                
                log_success "Authentication test successful!"
                log_info "  Client token: ${client_token:0:20}..."
                log_info "  Lease duration: ${lease_duration}s"
                
                # Test secret access
                log_info "Testing secret access"
                VAULT_TOKEN="$client_token" vault kv get "$SECRET_PATH" >/dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    log_success "Secret access test successful!"
                else
                    log_warning "Secret access test failed (this is expected if secret doesn't exist yet)"
                fi
            else
                log_error "Authentication test failed"
                return 1
            fi
        else
            log_warning "Could not create test token, skipping authentication test"
        fi
    else
        log_warning "kubectl not available or service account not found, skipping authentication test"
    fi
}

# Display configuration summary
show_summary() {
    log_info "Configuration Summary:"
    echo "  Vault Address: $VAULT_ADDR"
    echo "  Auth Path: $K8S_AUTH_PATH"
    echo "  Vault Role: $VAULT_ROLE"
    echo "  Service Account: $SERVICE_ACCOUNT_NAME"
    echo "  Namespace: $SERVICE_ACCOUNT_NAMESPACE"
    echo "  Policy Name: $POLICY_NAME"
    echo "  Secret Path: $SECRET_PATH"
    echo "  Token TTL: $TOKEN_TTL"
    echo ""
    log_success "Vault Kubernetes authentication setup completed successfully!"
    echo ""
    log_info "Next steps:"
    echo "  1. Ensure the service account exists: kubectl get sa $SERVICE_ACCOUNT_NAME -n $SERVICE_ACCOUNT_NAMESPACE"
    echo "  2. Deploy GOK-Agent with these environment variables:"
    echo "     VAULT_ADDR=$VAULT_ADDR"
    echo "     VAULT_K8S_ROLE=$VAULT_ROLE"
    echo "     VAULT_K8S_AUTH_PATH=$K8S_AUTH_PATH"
    echo "     VAULT_PATH=$SECRET_PATH"
    echo "  3. Store RabbitMQ credentials in Vault:"
    echo "     vault kv put $SECRET_PATH username=<user> password=<pass>"
}

# Main execution
main() {
    log_info "Starting Vault Kubernetes Authentication Setup"
    log_info "=========================================="
    
    # Validate required parameters
    if [[ -z "$VAULT_TOKEN" ]]; then
        log_error "VAULT_TOKEN environment variable is required"
        exit 1
    fi
    
    # Check Vault connection
    if ! check_vault_connection; then
        exit 1
    fi
    
    # Get Kubernetes configuration
    if ! check_k8s_environment; then
        if ! get_k8s_config_from_kubectl; then
            log_error "Could not obtain Kubernetes configuration"
            exit 1
        fi
    fi
    
    # Setup Vault authentication
    enable_kubernetes_auth
    configure_kubernetes_auth
    create_vault_policy
    create_vault_role
    
    # Test the setup
    test_authentication
    
    # Show summary
    show_summary
    
    # Cleanup temporary files
    [[ -f "/tmp/k8s-ca.crt" ]] && rm -f /tmp/k8s-ca.crt
}

# Show usage information
usage() {
    echo "Vault Kubernetes Authentication Setup Script"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Environment Variables:"
    echo "  VAULT_ADDR                 Vault server address (default: http://localhost:8200)"
    echo "  VAULT_TOKEN                Vault root or admin token (required)"
    echo "  K8S_AUTH_PATH              Kubernetes auth path in Vault (default: kubernetes)"
    echo "  VAULT_ROLE                 Vault role name (default: gok-agent)"
    echo "  SERVICE_ACCOUNT_NAME       Kubernetes service account name (default: gok-agent)"
    echo "  SERVICE_ACCOUNT_NAMESPACE  Kubernetes namespace (default: default)"
    echo "  POLICY_NAME                Vault policy name (default: rabbitmq-policy)"
    echo "  SECRET_PATH                Path to RabbitMQ secret (default: secret/data/rabbitmq)"
    echo "  TOKEN_TTL                  Token TTL (default: 24h)"
    echo ""
    echo "Example:"
    echo "  VAULT_TOKEN=s.xyz123 VAULT_ADDR=https://vault.example.com $0"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
esac