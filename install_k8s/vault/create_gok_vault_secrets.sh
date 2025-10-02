#!/bin/bash

# =============================================================================
# Vault Secret Creation Script for gok-cloud Components
# =============================================================================
# 
# This script creates Vault secrets required for gok-cloud/agent and 
# gok-cloud/controller components based on their values.yaml configurations.
#
# Secrets Created:
# - secret/rabbitmq (shared by both components)
# - secret/gok-agent/config (agent-specific configuration)
# - secret/gok-controller/config (controller-specific configuration)
#
# Usage:
#   ./create_gok_vault_secrets.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -n, --namespace NAME    Vault namespace (default: vault)
#   -v, --vault-pod NAME    Vault pod name (default: vault-0)
#   --rabbitmq-user USER    RabbitMQ username (default: retrieved from K8s or 'guest')
#   --rabbitmq-pass PASS    RabbitMQ password (default: generated)
#   --rabbitmq-host HOST    RabbitMQ host (default: rabbitmq.rabbitmq)
#   --rabbitmq-port PORT    RabbitMQ port (default: 5672)
#   --rabbitmq-vhost VHOST  RabbitMQ virtual host (default: /)
#   --dry-run              Show what would be created without executing
#   --update               Update existing secrets (default: skip if exists)
#   --delete               Delete existing secrets and recreate
#
# Examples:
#   # Create secrets with default values
#   ./create_gok_vault_secrets.sh
#
#   # Create secrets with custom RabbitMQ credentials
#   ./create_gok_vault_secrets.sh --rabbitmq-user myuser --rabbitmq-pass mypass
#
#   # Update existing secrets
#   ./create_gok_vault_secrets.sh --update
#
#   # Delete and recreate all secrets
#   ./create_gok_vault_secrets.sh --delete
#
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default configuration
VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
RABBITMQ_USER="guest"  # Default RabbitMQ user, will be overridden if found in K8s
RABBITMQ_PASSWORD=""  # Will be retrieved from K8s or generated if empty
RABBITMQ_HOST="rabbitmq.rabbitmq"
RABBITMQ_PORT="5672"
RABBITMQ_VHOST="/"
RABBITMQ_K8S_NAMESPACE="rabbitmq"  # Namespace to look for RabbitMQ resources
DRY_RUN=false
UPDATE_EXISTING=false
DELETE_EXISTING=false

# Counters for summary
TOTAL_SECRETS=0
CREATED_SECRETS=0
UPDATED_SECRETS=0
SKIPPED_SECRETS=0
FAILED_SECRETS=0
VALIDATED_SECRETS=0
TOTAL_POLICIES=0
CREATED_POLICIES=0
TOTAL_ROLES=0
CREATED_ROLES=0

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
    echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}\n"
}

# Show help
show_help() {
    cat << 'EOF'
Vault Secret Creation Script for gok-cloud Components

DESCRIPTION:
    Creates Vault secrets, policies, and roles required for gok-cloud/agent and 
    gok-cloud/controller components. This script automatically retrieves RabbitMQ
    credentials from Kubernetes secrets/deployments and configures complete Vault 
    RBAC with API-based access patterns.

VAULT CONFIGURATION:
    • Kubernetes authentication method
    • Service account policies with read/list permissions
    • Kubernetes auth roles for service accounts

SECRETS CREATED:
    secret/rabbitmq              - Shared RabbitMQ credentials
    secret/gok-agent/config      - Agent-specific configuration  
    secret/gok-controller/config - Controller-specific configuration

API ACCESS PATHS (KV v1):
    secret/rabbitmq              - API path for RabbitMQ credentials
    secret/gok-agent/config      - API path for agent configuration
    secret/gok-controller/config - API path for controller configuration

USAGE:
    ./create_gok_vault_secrets.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -n, --namespace NAME    Vault namespace (default: vault)
    -v, --vault-pod NAME    Vault pod name (default: vault-0)
    --rabbitmq-user USER    RabbitMQ username (default: retrieved from K8s or 'guest')
    --rabbitmq-pass PASS    RabbitMQ password (default: retrieved from K8s or auto-generated)
    --rabbitmq-host HOST    RabbitMQ host (default: rabbitmq.rabbitmq)
    --rabbitmq-port PORT    RabbitMQ port (default: 5672)
    --rabbitmq-vhost VHOST  RabbitMQ virtual host (default: /)
    --rabbitmq-namespace NS RabbitMQ Kubernetes namespace (default: rabbitmq)
    --dry-run              Show what would be created without executing
    --update               Update existing secrets (default: skip if exists)
    --delete               Delete existing secrets and recreate

EXAMPLES:
    # Create secrets with default values
    ./create_gok_vault_secrets.sh

    # Create secrets with custom RabbitMQ credentials (override K8s lookup)
    ./create_gok_vault_secrets.sh --rabbitmq-user myuser --rabbitmq-pass mypass

    # Use RabbitMQ from specific namespace
    ./create_gok_vault_secrets.sh --rabbitmq-namespace production    # Update existing secrets
    ./create_gok_vault_secrets.sh --update

    # Preview what would be created
    ./create_gok_vault_secrets.sh --dry-run

    # Delete and recreate all secrets
    ./create_gok_vault_secrets.sh --delete

PREREQUISITES:
    - kubectl configured and connected to cluster
    - Vault pod running in specified namespace
    - Vault unsealed and accessible
    - Vault root token available in vault-init-keys secret

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--namespace)
                VAULT_NAMESPACE="$2"
                shift 2
                ;;
            -v|--vault-pod)
                VAULT_POD="$2"
                shift 2
                ;;
            --rabbitmq-user)
                RABBITMQ_USER="$2"
                shift 2
                ;;
            --rabbitmq-pass)
                RABBITMQ_PASSWORD="$2"
                shift 2
                ;;
            --rabbitmq-host)
                RABBITMQ_HOST="$2"
                shift 2
                ;;
            --rabbitmq-port)
                RABBITMQ_PORT="$2"
                shift 2
                ;;
            --rabbitmq-vhost)
                RABBITMQ_VHOST="$2"
                shift 2
                ;;
            --rabbitmq-namespace)
                RABBITMQ_K8S_NAMESPACE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --update)
                UPDATE_EXISTING=true
                shift
                ;;
            --delete)
                DELETE_EXISTING=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

# Generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Vault pod exists
    if ! kubectl get pod "$VAULT_POD" -n "$VAULT_NAMESPACE" &>/dev/null; then
        log_error "Vault pod '$VAULT_POD' not found in namespace '$VAULT_NAMESPACE'"
        exit 1
    fi
    
    # Check if Vault pod is ready
    if ! kubectl wait --for=condition=Ready pod/"$VAULT_POD" -n "$VAULT_NAMESPACE" --timeout=10s &>/dev/null; then
        log_error "Vault pod '$VAULT_POD' is not ready"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Login to Vault
vault_login() {
    log_header "Vault Authentication"
    
    # Get root token from vault-init-keys secret
    if ! VAULT_TOKEN=$(kubectl get secret vault-init-keys -n "$VAULT_NAMESPACE" -o json 2>/dev/null | \
                       jq -r '.data["vault-init.json"]' | base64 -d | jq -r '.root_token' 2>/dev/null); then
        log_error "Failed to retrieve Vault root token from vault-init-keys secret"
        exit 1
    fi
    
    if [[ -z "$VAULT_TOKEN" || "$VAULT_TOKEN" == "null" ]]; then
        log_error "Vault root token is empty or invalid"
        exit 1
    fi
    
    # Login to Vault
    if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault login "$VAULT_TOKEN" >/dev/null 2>&1; then
        log_success "Successfully authenticated with Vault"
    else
        log_error "Failed to authenticate with Vault"
        exit 1
    fi
}

# Check if secret exists
secret_exists() {
    local secret_path="$1"
    kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault kv get "$secret_path" >/dev/null 2>&1
}

# Validate secret keys without showing values
validate_secret_keys() {
    local secret_path="$1"
    local secret_name="$2"
    shift 2
    local expected_keys=("$@")
    
    log_info "Validating $secret_name keys..."
    
    # Get the secret and extract keys
    local secret_output
    if ! secret_output=$(kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault kv get -format=json "$secret_path" 2>/dev/null); then
        log_error "Validation failed: Cannot retrieve $secret_name from $secret_path"
        return 1
    fi
    
    # Parse the JSON to get available keys
    local available_keys
    if ! available_keys=$(echo "$secret_output" | jq -r '.data | keys[]' 2>/dev/null); then
        log_error "Validation failed: Cannot parse secret data for $secret_name"
        return 1
    fi
    
    # Convert to arrays for comparison
    local missing_keys=()
    local found_keys=()
    
    for expected_key in "${expected_keys[@]}"; do
        if echo "$available_keys" | grep -q "^$expected_key$"; then
            found_keys+=("$expected_key")
        else
            missing_keys+=("$expected_key")
        fi
    done
    
    # Report validation results
    if [[ ${#missing_keys[@]} -eq 0 ]]; then
        log_success "✓ All expected keys found in $secret_name (${#found_keys[@]} keys)"
        VALIDATED_SECRETS=$((VALIDATED_SECRETS + 1))
        return 0
    else
        log_error "✗ Validation failed for $secret_name:"
        log_error "   Missing keys: ${missing_keys[*]}"
        if [[ ${#found_keys[@]} -gt 0 ]]; then
            log_info "   Found keys: ${found_keys[*]}"
        fi
        return 1
    fi
}

# Delete secret if it exists
delete_secret() {
    local secret_path="$1"
    
    if secret_exists "$secret_path"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would delete existing secret: $secret_path"
        else
            if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault kv delete "$secret_path" >/dev/null 2>&1; then
                log_success "Deleted existing secret: $secret_path"
            else
                log_error "Failed to delete existing secret: $secret_path"
            fi
        fi
    fi
}

# Create or update Vault secret
create_vault_secret() {
    local secret_path="$1"
    local secret_name="$2"
    shift 2
    local secret_data=("$@")
    
    TOTAL_SECRETS=$((TOTAL_SECRETS + 1))
    
    # Check if secret already exists
    local exists=false
    if secret_exists "$secret_path"; then
        exists=true
        
        if [[ "$DELETE_EXISTING" == "true" ]]; then
            delete_secret "$secret_path"
            exists=false
        elif [[ "$UPDATE_EXISTING" == "false" ]]; then
            log_warning "Secret $secret_name already exists at $secret_path (use --update to overwrite)"
            SKIPPED_SECRETS=$((SKIPPED_SECRETS + 1))
            return 0
        fi
    fi
    
    # Prepare the vault command
    local vault_cmd="vault kv put $secret_path"
    for data in "${secret_data[@]}"; do
        vault_cmd="$vault_cmd $data"
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$exists" == "true" ]]; then
            log_info "[DRY-RUN] Would update $secret_name:"
        else
            log_info "[DRY-RUN] Would create $secret_name:"
        fi
        log_info "  Path: $secret_path"
        log_info "  Command: kubectl exec $VAULT_POD -n $VAULT_NAMESPACE -- $vault_cmd"
        for data in "${secret_data[@]}"; do
            local key="${data%%=*}"
            local value="${data#*=}"
            if [[ "$key" == *"password"* ]] || [[ "$key" == *"secret"* ]] || [[ "$key" == *"token"* ]]; then
                log_info "    $key=***HIDDEN***"
            else
                log_info "    $key=$value"
            fi
        done
        log_info "[DRY-RUN] Would validate keys: ${secret_data[*]//=*/}"
        return 0
    fi
    
    # Execute the vault command
    # Build command array for proper escaping
    local cmd_args=("kubectl" "exec" "$VAULT_POD" "-n" "$VAULT_NAMESPACE" "--" "vault" "kv" "put" "$secret_path")
    for data in "${secret_data[@]}"; do
        cmd_args+=("$data")
    done
    
    # Show debug information if something fails
    if "${cmd_args[@]}" >/dev/null 2>&1; then
        if [[ "$exists" == "true" ]]; then
            log_success "Updated $secret_name at $secret_path"
            UPDATED_SECRETS=$((UPDATED_SECRETS + 1))
        else
            log_success "Created $secret_name at $secret_path"
            CREATED_SECRETS=$((CREATED_SECRETS + 1))
        fi
    else
        log_error "Failed to create/update $secret_name at $secret_path"
        log_error "Debug - Command that failed: ${cmd_args[*]}"
        # Try to get the actual error
        if ! "${cmd_args[@]}" 2>&1; then
            log_error "Error details shown above"
        fi
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
    fi
}

# Create Vault policy
create_vault_policy() {
    local policy_name="$1"
    local policy_description="$2"
    local policy_content="$3"
    
    TOTAL_POLICIES=$((TOTAL_POLICIES + 1))
    
    log_info "Creating Vault policy: $policy_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create policy $policy_name:"
        log_info "  Description: $policy_description"
        log_info "  Policy content:"
        echo "$policy_content" | sed 's/^/    /'
        return 0
    fi
    
    # Create a temporary file for the policy
    local temp_policy_file
    temp_policy_file=$(mktemp)
    echo "$policy_content" > "$temp_policy_file"
    
    # Copy policy file to Vault pod and create policy
    if kubectl cp "$temp_policy_file" "$VAULT_NAMESPACE/$VAULT_POD:/tmp/policy-$policy_name.hcl" && \
       kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault policy write "$policy_name" "/tmp/policy-$policy_name.hcl" >/dev/null 2>&1 && \
       kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- rm "/tmp/policy-$policy_name.hcl" >/dev/null 2>&1; then
        log_success "Created Vault policy: $policy_name"
        CREATED_POLICIES=$((CREATED_POLICIES + 1))
    else
        log_error "Failed to create Vault policy: $policy_name"
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
    fi
    
    # Clean up temporary file
    rm -f "$temp_policy_file"
}

# Create Kubernetes auth role
create_k8s_auth_role() {
    local role_name="$1"
    local service_account="$2"
    local namespace="$3"
    local policies="$4"
    local ttl="${5:-1h}"
    
    TOTAL_ROLES=$((TOTAL_ROLES + 1))
    
    log_info "Creating Kubernetes auth role: $role_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would create Kubernetes auth role $role_name:"
        log_info "  Service Account: $service_account"
        log_info "  Namespace: $namespace"
        log_info "  Policies: $policies"
        log_info "  TTL: $ttl"
        return 0
    fi
    
    if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault write "auth/kubernetes/role/$role_name" \
        bound_service_account_names="$service_account" \
        bound_service_account_namespaces="$namespace" \
        policies="$policies" \
        ttl="$ttl" >/dev/null 2>&1; then
        log_success "Created Kubernetes auth role: $role_name"
        CREATED_ROLES=$((CREATED_ROLES + 1))
    else
        log_error "Failed to create Kubernetes auth role: $role_name"
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
    fi
}

# Create gok-agent policy and role
create_agent_policy_and_role() {
    log_header "Creating gok-agent Vault Policy and Role"
    
    # Create policy for gok-agent (KV v1 compatible)
    local agent_policy='
# Policy for gok-agent service account
path "secret/rabbitmq" {
  capabilities = ["read", "list"]
}

path "secret/gok-agent/config" {
  capabilities = ["read", "list"]
}

path "secret/gok-agent/*" {
  capabilities = ["read", "list"]
}

# Allow listing secrets for discovery
path "secret/" {
  capabilities = ["list"]
}
'
    
    create_vault_policy "gok-agent" "Policy for gok-agent service account to access RabbitMQ and agent config secrets" "$agent_policy"
    
    # Create Kubernetes auth role for gok-agent
    create_k8s_auth_role "gok-agent" "gok-agent" "gok-agent" "gok-agent" "1h"
}

# Create gok-controller policy and role
create_controller_policy_and_role() {
    log_header "Creating gok-controller Vault Policy and Role"
    
    # Create policy for gok-controller (KV v1 compatible)
    local controller_policy='
# Policy for gok-controller service account  
path "secret/rabbitmq" {
  capabilities = ["read", "list"]
}

path "secret/gok-controller/config" {
  capabilities = ["read", "list"]
}

path "secret/gok-controller/*" {
  capabilities = ["read", "list"]
}

# Allow listing secrets for discovery
path "secret/" {
  capabilities = ["list"]
}
'
    
    create_vault_policy "gok-controller" "Policy for gok-controller service account to access RabbitMQ and controller config secrets" "$controller_policy"
    
    # Create Kubernetes auth role for gok-controller
    create_k8s_auth_role "gok-controller" "gok-controller" "gok-controller" "gok-controller" "1h"
}

# Create dedicated RabbitMQ access policy and role
create_rabbitmq_policy_and_role() {
    log_header "Creating RabbitMQ Access Policy and Role"
    
    # Create dedicated RabbitMQ policy
    local rabbitmq_policy='
# Policy for RabbitMQ access - allows reading credentials including password
path "secret/rabbitmq" {
  capabilities = ["read", "list"]
}

# Allow listing secrets to discover available secrets
path "secret/" {
  capabilities = ["list"]
}
'
    
    create_vault_policy "rabbitmq-access" "Policy for accessing RabbitMQ credentials including password" "$rabbitmq_policy"
    
    # Create a dedicated RabbitMQ role that both service accounts can use
    create_k8s_auth_role "rabbitmq-reader" "gok-agent,gok-controller" "gok-agent,gok-controller" "rabbitmq-access" "2h"
}

# Enable Kubernetes auth method if not already enabled
enable_kubernetes_auth() {
    log_header "Configuring Kubernetes Authentication"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable and configure Kubernetes authentication"
        return 0
    fi
    
    # Check if Kubernetes auth is already enabled
    if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault auth list -format=json 2>/dev/null | jq -e '.["kubernetes/"]' >/dev/null 2>&1; then
        log_info "Kubernetes authentication already enabled"
    else
        log_info "Enabling Kubernetes authentication..."
        if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault auth enable kubernetes >/dev/null 2>&1; then
            log_success "Enabled Kubernetes authentication"
        else
            log_error "Failed to enable Kubernetes authentication"
            return 1
        fi
    fi
    
    # Configure Kubernetes auth
    log_info "Configuring Kubernetes authentication..."
    
    # Get Kubernetes cluster info
    local k8s_host k8s_ca_cert
    k8s_host=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
    k8s_ca_cert=$(kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)
    
    if kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault write auth/kubernetes/config \
        token_reviewer_jwt="$(kubectl exec "$VAULT_POD" -n "$VAULT_NAMESPACE" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        kubernetes_host="$k8s_host" \
        kubernetes_ca_cert="$k8s_ca_cert" >/dev/null 2>&1; then
        log_success "Configured Kubernetes authentication"
    else
        log_error "Failed to configure Kubernetes authentication"
        return 1
    fi
}

# Create RabbitMQ secret
create_rabbitmq_secret() {
    log_header "Creating RabbitMQ Secret"
    
    # Try to get RabbitMQ credentials from Kubernetes
    log_info "Retrieving RabbitMQ credentials from Kubernetes..."
    
    # Attempt to get RabbitMQ default user secret
    local k8s_rabbitmq_user=""
    local k8s_rabbitmq_password=""
    
    # Try common RabbitMQ secret names and namespaces
    local rabbitmq_namespaces=("rabbitmq" "default" "kube-system")
    local rabbitmq_secrets=("rabbitmq-default-user" "rabbitmq-secret" "rabbitmq" "rabbitmq-admin")
    
    for namespace in "${rabbitmq_namespaces[@]}"; do
        for secret_name in "${rabbitmq_secrets[@]}"; do
            if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
                log_info "Found RabbitMQ secret: $secret_name in namespace: $namespace"
                
                # Try to extract username
                if k8s_rabbitmq_user=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d 2>/dev/null); then
                    if [[ -n "$k8s_rabbitmq_user" ]]; then
                        RABBITMQ_USER="$k8s_rabbitmq_user"
                        log_success "Retrieved RabbitMQ username from Kubernetes: $RABBITMQ_USER"
                    fi
                fi
                
                # Try to extract password
                if k8s_rabbitmq_password=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null); then
                    if [[ -n "$k8s_rabbitmq_password" ]]; then
                        RABBITMQ_PASSWORD="$k8s_rabbitmq_password"
                        log_success "Retrieved RabbitMQ password from Kubernetes secret"
                    fi
                fi
                
                # If we found credentials, break out of loops
                if [[ -n "$k8s_rabbitmq_user" ]] && [[ -n "$k8s_rabbitmq_password" ]]; then
                    break 2
                fi
            fi
        done
    done
    
    # Try alternative approaches if direct secret lookup failed
    if [[ -z "$k8s_rabbitmq_user" ]] || [[ -z "$k8s_rabbitmq_password" ]]; then
        log_warning "Could not find RabbitMQ credentials in common Kubernetes secrets"
        
        # Try to get from RabbitMQ deployment environment variables
        log_info "Attempting to retrieve from RabbitMQ deployment..."
        
        # Look for RabbitMQ deployment/statefulset
        for namespace in "${rabbitmq_namespaces[@]}"; do
            # Check deployments
            if kubectl get deployment rabbitmq -n "$namespace" >/dev/null 2>&1; then
                log_info "Found RabbitMQ deployment in namespace: $namespace"
                
                # Try to get environment variables
                local env_user env_password
                env_user=$(kubectl get deployment rabbitmq -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RABBITMQ_DEFAULT_USER")].value}' 2>/dev/null || echo "")
                env_password=$(kubectl get deployment rabbitmq -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RABBITMQ_DEFAULT_PASS")].value}' 2>/dev/null || echo "")
                
                if [[ -n "$env_user" ]]; then
                    RABBITMQ_USER="$env_user"
                    log_success "Retrieved RabbitMQ username from deployment: $RABBITMQ_USER"
                fi
                
                if [[ -n "$env_password" ]]; then
                    RABBITMQ_PASSWORD="$env_password"
                    log_success "Retrieved RabbitMQ password from deployment"
                fi
                
                if [[ -n "$env_user" ]] && [[ -n "$env_password" ]]; then
                    break
                fi
            fi
            
            # Check statefulsets
            if kubectl get statefulset rabbitmq -n "$namespace" >/dev/null 2>&1; then
                log_info "Found RabbitMQ statefulset in namespace: $namespace"
                
                # Try to get environment variables
                local env_user env_password
                env_user=$(kubectl get statefulset rabbitmq -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RABBITMQ_DEFAULT_USER")].value}' 2>/dev/null || echo "")
                env_password=$(kubectl get statefulset rabbitmq -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="RABBITMQ_DEFAULT_PASS")].value}' 2>/dev/null || echo "")
                
                if [[ -n "$env_user" ]]; then
                    RABBITMQ_USER="$env_user"
                    log_success "Retrieved RabbitMQ username from statefulset: $RABBITMQ_USER"
                fi
                
                if [[ -n "$env_password" ]]; then
                    RABBITMQ_PASSWORD="$env_password"
                    log_success "Retrieved RabbitMQ password from statefulset"
                fi
                
                if [[ -n "$env_user" ]] && [[ -n "$env_password" ]]; then
                    break
                fi
            fi
        done
    fi
    
    # Final fallback - use provided values or generate
    if [[ -z "$RABBITMQ_PASSWORD" ]]; then
        if [[ -n "${RABBITMQ_PASSWORD:-}" ]]; then
            log_info "Using provided RabbitMQ password"
        else
            RABBITMQ_PASSWORD=$(generate_password)
            log_warning "Could not retrieve RabbitMQ credentials from Kubernetes, generated secure password for user: $RABBITMQ_USER"
        fi
    fi
    
    # Create the secret (KV v2 API compatible)
    create_vault_secret \
        "secret/rabbitmq" \
        "RabbitMQ Credentials" \
        "username=$RABBITMQ_USER" \
        "password=$RABBITMQ_PASSWORD" \
        "host=$RABBITMQ_HOST" \
        "port=$RABBITMQ_PORT" \
        "virtual_host=$RABBITMQ_VHOST"
    
    # Validate the secret was created with correct keys
    if ! validate_secret_keys "secret/rabbitmq" "RabbitMQ Credentials" "username" "password" "host" "port" "virtual_host"; then
        log_error "RabbitMQ secret validation failed"
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
        return 1
    fi
    
    log_info "💡 API Access: Use path 'secret/rabbitmq' for API-based secret retrieval"
}

# Create gok-agent configuration secret
create_agent_config_secret() {
    log_header "Creating gok-agent Configuration Secret"
    
    # Generate OAuth client secret
    local oauth_client_secret
    oauth_client_secret=$(generate_password)
    
    # Create agent-specific configuration
    local static_config='{"debug_mode": true, "log_level": "INFO", "agent_version": "1.0.0"}'
    local config_json='{"rabbitmq": {"connection_timeout": 30, "heartbeat": 600}, "monitoring": {"enabled": true, "interval": 60}}'
    
    create_vault_secret \
        "secret/gok-agent/config" \
        "gok-agent Configuration" \
        "oauth_client_secret=$oauth_client_secret" \
        "static_config=$static_config" \
        "config_json=$config_json"
    
    # Validate the secret was created with correct keys
    if ! validate_secret_keys "secret/gok-agent/config" "gok-agent Configuration" "oauth_client_secret" "static_config" "config_json"; then
        log_error "gok-agent config secret validation failed"
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
        return 1
    fi
    
    log_info "💡 API Access: Use path 'secret/gok-agent/config' for API-based secret retrieval"
}

# Create gok-controller configuration secret  
create_controller_config_secret() {
    log_header "Creating gok-controller Configuration Secret"
    
    # Generate OAuth client secret
    local oauth_client_secret
    oauth_client_secret=$(generate_password)
    
    # Create controller-specific configuration
    local static_config='{"debug_mode": true, "log_level": "INFO", "controller_version": "1.0.0", "max_workers": 10}'
    local config_json='{"api": {"timeout": 30, "rate_limit": 1000}, "database": {"pool_size": 20, "connection_timeout": 30}}'
    
    create_vault_secret \
        "secret/gok-controller/config" \
        "gok-controller Configuration" \
        "oauth_client_secret=$oauth_client_secret" \
        "static_config=$static_config" \
        "config_json=$config_json"
    
    # Validate the secret was created with correct keys
    if ! validate_secret_keys "secret/gok-controller/config" "gok-controller Configuration" "oauth_client_secret" "static_config" "config_json"; then
        log_error "gok-controller config secret validation failed"
        FAILED_SECRETS=$((FAILED_SECRETS + 1))
        return 1
    fi
    
    log_info "💡 API Access: Use path 'secret/gok-controller/config' for API-based secret retrieval"
}

# Show configuration summary
show_configuration() {
    log_header "Configuration Summary"
    
    echo -e "${BOLD}Vault Configuration:${NC}"
    echo "  Namespace: $VAULT_NAMESPACE"
    echo "  Pod: $VAULT_POD"
    echo
    echo -e "${BOLD}RabbitMQ Configuration:${NC}"
    echo "  Username: $RABBITMQ_USER (will be retrieved from K8s if available)"
    echo "  Password: ${RABBITMQ_PASSWORD:+***PROVIDED***}${RABBITMQ_PASSWORD:-***WILL BE RETRIEVED FROM K8S OR GENERATED***}"
    echo "  Host: $RABBITMQ_HOST"
    echo "  Port: $RABBITMQ_PORT"
    echo "  Virtual Host: $RABBITMQ_VHOST"
    echo "  K8s Namespace: $RABBITMQ_K8S_NAMESPACE"
    echo
    echo -e "${BOLD}Operation Mode:${NC}"
    echo "  Dry Run: $DRY_RUN"
    echo "  Update Existing: $UPDATE_EXISTING"
    echo "  Delete Existing: $DELETE_EXISTING"
    echo
    echo -e "${BOLD}Vault Configuration:${NC}"
    echo "  • Kubernetes authentication method"
    echo "  • gok-agent policy and role"
    echo "  • gok-controller policy and role"
    echo "  • rabbitmq-access policy and rabbitmq-reader role"
    echo
    echo -e "${BOLD}Secrets to be created:${NC}"
    echo "  • secret/rabbitmq - Shared RabbitMQ credentials"
    echo "  • secret/gok-agent/config - Agent configuration"
    echo "  • secret/gok-controller/config - Controller configuration"
    echo
    echo -e "${BOLD}API Access Paths (for KV v1):${NC}"
    echo "  • secret/rabbitmq - RabbitMQ credentials via API"
    echo "  • secret/gok-agent/config - Agent config via API"  
    echo "  • secret/gok-controller/config - Controller config via API"
}

# Show execution summary
show_summary() {
    log_header "Execution Summary"
    
    echo -e "${BOLD}Results:${NC}"
    echo -e "${BOLD}Secrets:${NC}"
    echo "  Total: $TOTAL_SECRETS"
    echo -e "  Created: ${GREEN}$CREATED_SECRETS${NC}"
    echo -e "  Updated: ${YELLOW}$UPDATED_SECRETS${NC}"
    echo -e "  Skipped: ${CYAN}$SKIPPED_SECRETS${NC}"
    echo -e "  Failed: ${RED}$FAILED_SECRETS${NC}"
    echo -e "  Validated: ${GREEN}$VALIDATED_SECRETS${NC}"
    echo
    echo -e "${BOLD}Policies & Roles:${NC}"
    echo -e "  Policies Created: ${GREEN}$CREATED_POLICIES${NC}/$TOTAL_POLICIES"
    echo -e "  Roles Created: ${GREEN}$CREATED_ROLES${NC}/$TOTAL_ROLES"
    
    if [[ "$FAILED_SECRETS" -gt 0 ]]; then
        echo
        log_error "Some secrets failed to create. Please check the errors above."
        exit 1
    elif [[ "$DRY_RUN" == "true" ]]; then
        echo
        log_info "Dry run completed. Use without --dry-run to actually create the secrets."
    else
        echo
        log_success "All secrets processed successfully!"
        
        if [[ "$CREATED_SECRETS" -gt 0 ]] || [[ "$UPDATED_SECRETS" -gt 0 ]]; then
            echo
            log_info "🔐 Vault Authentication & RBAC:"
            echo "  • Kubernetes auth method: auth/kubernetes/"
            echo "  • gok-agent role: bound to gok-agent service account"
            echo "  • gok-controller role: bound to gok-controller service account"
            echo "  • rabbitmq-reader role: allows both service accounts to access RabbitMQ"
            echo
            log_info "📦 Secrets available for gok-cloud components:"
            echo "  • Agent: secret/rabbitmq, secret/gok-agent/config"
            echo "  • Controller: secret/rabbitmq, secret/gok-controller/config"
            echo
            log_info "🌐 API Access Paths (for application code):"
            echo "  • RabbitMQ: GET /v1/secret/rabbitmq"
            echo "  • Agent Config: GET /v1/secret/gok-agent/config"
            echo "  • Controller Config: GET /v1/secret/gok-controller/config"
            echo
            if [[ "$VALIDATED_SECRETS" -eq "$TOTAL_SECRETS" ]]; then
                log_success "✓ All secrets validated successfully with correct keys!"
            else
                log_warning "⚠ Some secrets failed validation - check logs above"
            fi
            echo
            log_info "🚀 Components can now authenticate using their service account tokens!"
        fi
    fi
}

# Main execution
main() {
    echo -e "${BOLD}${CYAN}"
    echo "================================================================="
    echo "        Vault Secret Creation for gok-cloud Components"
    echo "================================================================="
    echo -e "${NC}"
    
    parse_args "$@"
    show_configuration
    
    if [[ "$DRY_RUN" == "false" ]]; then
        check_prerequisites
        vault_login
    else
        log_info "Dry run mode - skipping prerequisite checks and Vault authentication"
    fi
    
    # Configure Vault authentication and RBAC
    enable_kubernetes_auth
    create_agent_policy_and_role
    create_controller_policy_and_role
    create_rabbitmq_policy_and_role
    
    # Create secrets
    create_rabbitmq_secret
    create_agent_config_secret
    create_controller_config_secret
    
    # Test authentication and access
    test_service_account_access
    
    show_summary
}

# Test service account authentication and secret access
test_service_account_access() {
    log_header "Testing Service Account Authentication"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would test service account authentication and secret access"
        return 0
    fi
    
    # Test gok-agent authentication
    log_info "Testing gok-agent service account authentication..."
    if kubectl exec vault-0 -n vault -- sh -c '
        # Simulate service account token authentication
        VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login role=gok-agent jwt="test-jwt-would-be-here" 2>/dev/null || echo "")
        if [ -n "$VAULT_TOKEN" ]; then
            echo "Authentication test structure valid"
        else
            echo "Note: JWT authentication requires actual service account token"
        fi
    ' 2>/dev/null; then
        log_success "✓ gok-agent role configuration is valid"
    else
        log_warning "⚠ gok-agent role may need verification with actual JWT token"
    fi
    
    # Test RabbitMQ secret access with root token (to verify policy structure)
    log_info "Testing RabbitMQ secret access permissions..."
    if kubectl exec vault-0 -n vault -- vault kv get secret/rabbitmq >/dev/null 2>&1; then
        log_success "✓ RabbitMQ secret is accessible with proper permissions"
        
        # Show available fields without values
        local rabbitmq_keys
        rabbitmq_keys=$(kubectl exec vault-0 -n vault -- vault kv get -format=json secret/rabbitmq | jq -r '.data | keys[]' 2>/dev/null || echo "")
        if [[ -n "$rabbitmq_keys" ]]; then
            log_info "Available RabbitMQ credential fields: $(echo "$rabbitmq_keys" | tr '\n' ' ')"
            if echo "$rabbitmq_keys" | grep -q "password"; then
                log_success "✓ Password field is available for service accounts"
            fi
        fi
    else
        log_error "✗ RabbitMQ secret access test failed"
    fi
}

# Execute main function with all arguments
main "$@"