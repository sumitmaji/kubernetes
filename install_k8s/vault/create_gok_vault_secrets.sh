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
#   --rabbitmq-user USER    RabbitMQ username (default: gok-admin)
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
RABBITMQ_USER="gok-admin"
RABBITMQ_PASSWORD=""  # Will be generated if empty
RABBITMQ_HOST="rabbitmq.rabbitmq"
RABBITMQ_PORT="5672"
RABBITMQ_VHOST="/"
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
    Creates Vault secrets required for gok-cloud/agent and gok-cloud/controller 
    components. This script reads the configurations from values.yaml files and 
    creates the corresponding secrets in Vault.

SECRETS CREATED:
    secret/rabbitmq              - Shared RabbitMQ credentials
    secret/gok-agent/config      - Agent-specific configuration  
    secret/gok-controller/config - Controller-specific configuration

USAGE:
    ./create_gok_vault_secrets.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -n, --namespace NAME    Vault namespace (default: vault)
    -v, --vault-pod NAME    Vault pod name (default: vault-0)
    --rabbitmq-user USER    RabbitMQ username (default: gok-admin)
    --rabbitmq-pass PASS    RabbitMQ password (default: auto-generated)
    --rabbitmq-host HOST    RabbitMQ host (default: rabbitmq.rabbitmq)
    --rabbitmq-port PORT    RabbitMQ port (default: 5672)
    --rabbitmq-vhost VHOST  RabbitMQ virtual host (default: /)
    --dry-run              Show what would be created without executing
    --update               Update existing secrets (default: skip if exists)
    --delete               Delete existing secrets and recreate

EXAMPLES:
    # Create secrets with default values
    ./create_gok_vault_secrets.sh

    # Create secrets with custom RabbitMQ credentials  
    ./create_gok_vault_secrets.sh --rabbitmq-user myuser --rabbitmq-pass mypass

    # Update existing secrets
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

# Create RabbitMQ secret
create_rabbitmq_secret() {
    log_header "Creating RabbitMQ Secret"
    
    # Generate password if not provided
    if [[ -z "$RABBITMQ_PASSWORD" ]]; then
        RABBITMQ_PASSWORD=$(generate_password)
        log_info "Generated secure password for RabbitMQ user: $RABBITMQ_USER"
    fi
    
    # Create the secret
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
}

# Show configuration summary
show_configuration() {
    log_header "Configuration Summary"
    
    echo -e "${BOLD}Vault Configuration:${NC}"
    echo "  Namespace: $VAULT_NAMESPACE"
    echo "  Pod: $VAULT_POD"
    echo
    echo -e "${BOLD}RabbitMQ Configuration:${NC}"
    echo "  Username: $RABBITMQ_USER"
    echo "  Password: ${RABBITMQ_PASSWORD:+***PROVIDED***}${RABBITMQ_PASSWORD:-***WILL BE GENERATED***}"
    echo "  Host: $RABBITMQ_HOST"
    echo "  Port: $RABBITMQ_PORT"
    echo "  Virtual Host: $RABBITMQ_VHOST"
    echo
    echo -e "${BOLD}Operation Mode:${NC}"
    echo "  Dry Run: $DRY_RUN"
    echo "  Update Existing: $UPDATE_EXISTING"
    echo "  Delete Existing: $DELETE_EXISTING"
    echo
    echo -e "${BOLD}Secrets to be created:${NC}"
    echo "  • secret/rabbitmq - Shared RabbitMQ credentials"
    echo "  • secret/gok-agent/config - Agent configuration"
    echo "  • secret/gok-controller/config - Controller configuration"
}

# Show execution summary
show_summary() {
    log_header "Execution Summary"
    
    echo -e "${BOLD}Results:${NC}"
    echo "  Total Secrets: $TOTAL_SECRETS"
    echo -e "  Created: ${GREEN}$CREATED_SECRETS${NC}"
    echo -e "  Updated: ${YELLOW}$UPDATED_SECRETS${NC}"
    echo -e "  Skipped: ${CYAN}$SKIPPED_SECRETS${NC}"
    echo -e "  Failed: ${RED}$FAILED_SECRETS${NC}"
    echo -e "  Validated: ${GREEN}$VALIDATED_SECRETS${NC}"
    
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
            log_info "Secrets are now available for gok-cloud components:"
            echo "  • Agent: Can access secret/rabbitmq and secret/gok-agent/config"
            echo "  • Controller: Can access secret/rabbitmq and secret/gok-controller/config"
            echo
            if [[ "$VALIDATED_SECRETS" -eq "$TOTAL_SECRETS" ]]; then
                log_success "✓ All secrets validated successfully with correct keys!"
            else
                log_warning "⚠ Some secrets failed validation - check logs above"
            fi
            echo
            log_info "Make sure your Vault policies allow access to these secrets!"
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
    
    # Create secrets
    create_rabbitmq_secret
    create_agent_config_secret
    create_controller_config_secret
    
    show_summary
}

# Execute main function with all arguments
main "$@"