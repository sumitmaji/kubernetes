#!/bin/bash
# lib/core/config.sh
# Configuration Management System for GOK-New Modular System
# 
# This module provides comprehensive configuration loading and management:
# • Multi-layered configuration loading (system, user, project, component)
# • Dynamic configuration generation based on identity providers
# • Environment variable management and validation
# • Configuration file discovery and sourcing
# • Root configuration generation and management
# • OAuth/OIDC provider configuration handling
#
# Usage:
#   source_gok_module "config"
#   init_gok_configuration
#   load_gok_configuration [--force-reload]
#   generate_root_configuration
# =============================================================================

# Ensure this module is loaded only once
if [[ "${GOK_CONFIG_LOADED:-}" == "true" ]]; then
    return 0
fi

# =============================================================================
# CONFIGURATION CONSTANTS AND DEFAULTS
# =============================================================================

# Default configuration paths and settings
: ${MOUNT_PATH:=/home/sumit/Documents/repository}
: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}
: ${GOK_CONFIG_DIR:=$HOME/.gok}
: ${GOK_ROOT_CONFIG:=$MOUNT_PATH/root_config}
: ${GOK_PROJECT_CONFIG:=$WORKING_DIR/config}

# Default identity provider and authentication settings
: ${IDENTITY_PROVIDER:=keycloak}
: ${AUTHENTICATION_METHOD:=oidc}
: ${GOK_ROOT_DOMAIN:=gokcloud.com}
: ${DEFAULT_SUBDOMAIN:=kube}

# Configuration loading flags
: ${GOK_CONFIG_DEBUG:=false}
: ${GOK_CONFIG_STRICT:=false}

# =============================================================================
# CONFIGURATION FILE DISCOVERY AND LOADING
# =============================================================================

# Initialize GOK configuration system
init_gok_configuration() {
    log_debug "Initializing GOK configuration system"
    
    # Create configuration directories if they don't exist
    mkdir -p "$GOK_CONFIG_DIR"
    
    # Set up configuration paths
    setup_configuration_paths
    
    # Load configuration in proper order
    load_gok_configuration
    
    log_debug "GOK configuration system initialized"
}

# Set up configuration file paths
setup_configuration_paths() {
    # Ensure MOUNT_PATH and WORKING_DIR are set correctly
    export MOUNT_PATH="${MOUNT_PATH:-/home/sumit/Documents/repository}"
    export WORKING_DIR="${WORKING_DIR:-$MOUNT_PATH/kubernetes/install_k8s}"
    
    # Set up derived paths
    export GOK_ROOT_CONFIG="${MOUNT_PATH}/root_config"
    export GOK_PROJECT_CONFIG="${WORKING_DIR}/config"
    export GOK_USER_CONFIG="${GOK_CONFIG_DIR}/config"
    export GOK_VM_CONFIG="${MOUNT_PATH}/kubernetes/install_cluster/vm_config"
    
    log_debug "Configuration paths set up:"
    log_debug "  MOUNT_PATH: $MOUNT_PATH"
    log_debug "  WORKING_DIR: $WORKING_DIR"
    log_debug "  GOK_ROOT_CONFIG: $GOK_ROOT_CONFIG"
    log_debug "  GOK_PROJECT_CONFIG: $GOK_PROJECT_CONFIG"
    log_debug "  GOK_USER_CONFIG: $GOK_USER_CONFIG"
}

# Load GOK configuration from multiple sources
load_gok_configuration() {
    local force_reload=false
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --force-reload|--force)
                force_reload=true
                ;;
        esac
    done
    
    log_substep "Loading GOK configuration from multiple sources"
    
    # Load configuration in hierarchical order (lowest to highest priority)
    
    # 1. Load VM configuration (cluster-level settings)
    load_vm_configuration
    
    # 2. Load system-wide configuration
    load_system_configuration
    
    # 3. Load project configuration  
    load_project_configuration
    
    # 4. Load user configuration
    load_user_configuration
    
    # 5. Generate and load root configuration
    generate_root_configuration
    load_root_configuration
    
    # 6. Validate configuration
    validate_loaded_configuration
    
    # 7. Set derived environment variables for compatibility
    set_derived_environment_variables
    
    log_success "GOK configuration loaded successfully"
}

# Load VM configuration (cluster settings)
load_vm_configuration() {
    local vm_config="$GOK_VM_CONFIG"
    
    if [[ -f "$vm_config" ]]; then
        log_debug "Loading VM configuration from: $vm_config"
        source "$vm_config"
        log_debug "VM configuration loaded successfully"
    else
        log_debug "VM configuration not found: $vm_config (this is optional)"
    fi
}

# Load system-wide configuration
load_system_configuration() {
    local system_configs=(
        "/etc/gok/config"
        "/etc/gok/gok.conf"
        "/usr/local/etc/gok/config"
    )
    
    for config_file in "${system_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_debug "Loading system configuration from: $config_file"
            source "$config_file"
            log_debug "System configuration loaded: $config_file"
            return 0
        fi
    done
    
    log_debug "No system configuration found (this is optional)"
}

# Load project configuration  
load_project_configuration() {
    local project_config="$GOK_PROJECT_CONFIG"
    local default_config="${GOK_ROOT_DIR}/config/default.conf"
    
    # Load default configuration first
    if [[ -f "$default_config" ]]; then
        log_debug "Loading default configuration from: $default_config"
        source "$default_config"
        log_debug "Default configuration loaded"
    else
        log_warning "Default configuration not found: $default_config"
    fi
    
    # Load project-specific configuration (may override defaults)
    if [[ -f "$project_config" ]]; then
        log_debug "Loading project configuration from: $project_config"
        source "$project_config"
        log_success "Project configuration loaded"
    else
        log_warning "Project configuration not found: $project_config"
        if [[ "$GOK_CONFIG_STRICT" == "true" ]]; then
            log_error "Project configuration required in strict mode"
            return 1
        fi
    fi
}

# Load user configuration
load_user_configuration() {
    local user_config="$GOK_USER_CONFIG"
    
    if [[ -f "$user_config" ]]; then
        log_debug "Loading user configuration from: $user_config"
        source "$user_config"
        log_debug "User configuration loaded"
    else
        log_debug "User configuration not found: $user_config (this is optional)"
    fi
}

# Load root configuration
load_root_configuration() {
    local root_config="$GOK_ROOT_CONFIG"
    
    if [[ -f "$root_config" ]]; then
        log_debug "Loading root configuration from: $root_config"
        source "$root_config"
        log_success "Root configuration loaded"
    else
        log_debug "Root configuration not found: $root_config"
    fi
}

# =============================================================================
# OAUTH/OIDC CONFIGURATION PROVIDERS
# =============================================================================

# Get OAuth0 configuration
getOAuth0Config() {
    log_debug "Generating OAuth0 configuration"
    
    IFS='' read -r -d '' OAUTH <<"EOF"
export OIDC_ISSUE_URL=https://skmaji.auth0.com/
export OIDC_CLIENT_ID=C3UHISO3z60iF1JLG8L7VPUSWOASrJfO
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=http://localhost:8080/claims/groups
export AUTH0_DOMAIN=skmaji.auth0.com
export APP_HOST=kube.gokcloud.com
export JWKS_URL=$OIDC_ISSUE_URL/.well-known/jwks.json
EOF
    echo "$OAUTH"
}

# Get Keycloak configuration
getKeycloakConfig() {
    log_debug "Generating Keycloak configuration"
    
    # Source the centralized OAuth/OIDC configuration from keycloak/config
    local keycloak_config_file="${WORKING_DIR}/keycloak/config"
    if [[ -f "$keycloak_config_file" ]]; then
        log_debug "Sourcing Keycloak config from: $keycloak_config_file"
        source "$keycloak_config_file"
    else
        log_warning "Keycloak config file not found: $keycloak_config_file"
    fi
    
    # Export the OAuth/OIDC configuration values
    IFS='' read -r -d '' OAUTH <<"EOF"
export OIDC_ISSUE_URL=$OIDC_ISSUE_URL
export OIDC_CLIENT_ID=$OIDC_CLIENT_ID
export OIDC_USERNAME_CLAIM=$OIDC_USERNAME_CLAIM
export OIDC_GROUPS_CLAIM=$OIDC_GROUPS_CLAIM
export REALM=$REALM
export AUTH0_DOMAIN=$AUTH0_DOMAIN
export APP_HOST=$APP_HOST
export JWKS_URL=$JWKS_URL
EOF
    echo "$OAUTH"
}

# Get identity provider configuration based on IDENTITY_PROVIDER
get_identity_provider_config() {
    local provider="${IDENTITY_PROVIDER:-keycloak}"
    
    log_debug "Getting configuration for identity provider: $provider"
    
    case "$provider" in
        "auth0"|"oauth0")
            getOAuth0Config
            ;;
        "keycloak")
            getKeycloakConfig
            ;;
        *)
            log_error "Unsupported identity provider: $provider"
            log_error "Supported providers: auth0, oauth0, keycloak"
            return 1
            ;;
    esac
}

# =============================================================================
# ROOT CONFIGURATION GENERATION
# =============================================================================

# Generate root configuration file
generate_root_configuration() {
    local root_config="$GOK_ROOT_CONFIG"
    
    log_substep "Generating root configuration"
    
    # Check if MOUNT_PATH is writable
    if [[ ! -w "$(dirname "$root_config")" ]]; then
        log_warning "Cannot write to $(dirname "$root_config") - root configuration will be skipped"
        return 0
    fi
    
    log_debug "Generating root configuration at: $root_config"
    
    # Generate the root configuration file
    cat <<EOF > "$root_config"
# GOK Root Configuration
# Generated automatically by GOK configuration system
# Generated on: $(date)

# Certificate Manager Configuration
export LETS_ENCRYPT_PROD_URL=https://acme-v02.api.letsencrypt.org/directory
export LETS_ENCRYPT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory
# Challenge types: dns, http, selfsigned
export CERTMANAGER_CHALANGE_TYPE=selfsigned
# Environment: staging, prod
export LETS_ENCRYPT_ENV=staging

# Component Service Names
export REGISTRY=registry
export KEYCLOAK=keycloak
export SPINNAKER=spinnaker
export VAULT=vault
export JUPYTERHUB=jupyterhub
export ARGOCD=argocd

# Domain Configuration
export DEFAULT_SUBDOMAIN=${DEFAULT_SUBDOMAIN:-kube}
export GROUP_NAME=${GOK_ROOT_DOMAIN:-gokcloud.com}

# Authentication Configuration
export AUTHENTICATION_METHOD=${AUTHENTICATION_METHOD:-oidc}
export IDENTITY_PROVIDER=${IDENTITY_PROVIDER:-keycloak}

# Identity Provider Specific Configuration
$(get_identity_provider_config)
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "Root configuration generated successfully"
        log_debug "Root configuration written to: $root_config"
    else
        log_error "Failed to generate root configuration"
        return 1
    fi
}

# =============================================================================
# CONFIGURATION VALIDATION AND DIAGNOSTICS
# =============================================================================

# Validate loaded configuration
validate_loaded_configuration() {
    log_substep "Validating configuration"
    
    local validation_errors=()
    
    # Check required variables
    local required_vars=(
        "MOUNT_PATH"
        "WORKING_DIR"
        "IDENTITY_PROVIDER"
        "AUTHENTICATION_METHOD"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            validation_errors+=("Required variable $var is not set")
        fi
    done
    
    # Check paths exist
    local required_paths=(
        "$MOUNT_PATH"
        "$WORKING_DIR"
    )
    
    for path in "${required_paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            validation_errors+=("Required directory does not exist: $path")
        fi
    done
    
    # Validate identity provider
    local supported_providers=("keycloak" "auth0" "oauth0")
    if [[ ! " ${supported_providers[*]} " =~ " ${IDENTITY_PROVIDER} " ]]; then
        validation_errors+=("Unsupported identity provider: $IDENTITY_PROVIDER")
    fi
    
    # Check identity provider specific configuration
    validate_identity_provider_config
    
    # Report validation results
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Configuration validation passed"
    else
        log_error "Configuration validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  • $error"
        done
        
        if [[ "$GOK_CONFIG_STRICT" == "true" ]]; then
            log_error "Configuration validation failed in strict mode"
            return 1
        else
            log_warning "Configuration validation failed but continuing in permissive mode"
        fi
    fi
}

# Validate identity provider specific configuration
validate_identity_provider_config() {
    case "${IDENTITY_PROVIDER:-}" in
        "keycloak")
            validate_keycloak_config
            ;;
        "auth0"|"oauth0")
            validate_oauth0_config
            ;;
    esac
}

# Validate Keycloak configuration
validate_keycloak_config() {
    local keycloak_vars=(
        "OIDC_ISSUE_URL"
        "OIDC_CLIENT_ID"
        "REALM"
    )
    
    for var in "${keycloak_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warning "Keycloak variable $var is not set"
        fi
    done
}

# Validate OAuth0 configuration
validate_oauth0_config() {
    local oauth0_vars=(
        "OIDC_ISSUE_URL"
        "OIDC_CLIENT_ID"
        "AUTH0_DOMAIN"
    )
    
    for var in "${oauth0_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_warning "OAuth0 variable $var is not set"
        fi
    done
}

# =============================================================================
# CONFIGURATION UTILITIES AND HELPERS
# =============================================================================

# Show configuration status and information
show_configuration_status() {
    echo -e "\n${COLOR_BOLD}${COLOR_BRIGHT_BLUE}GOK CONFIGURATION STATUS${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    # Basic configuration info
    echo -e "${COLOR_BLUE}Paths:${COLOR_RESET}"
    echo -e "  Mount Path: ${COLOR_DIM}${MOUNT_PATH}${COLOR_RESET}"
    echo -e "  Working Dir: ${COLOR_DIM}${WORKING_DIR}${COLOR_RESET}"
    echo -e "  Config Dir: ${COLOR_DIM}${GOK_CONFIG_DIR}${COLOR_RESET}"
    
    # Configuration files status
    echo -e "\n${COLOR_BLUE}Configuration Files:${COLOR_RESET}"
    check_config_file_status "$GOK_PROJECT_CONFIG" "Project Config"
    check_config_file_status "$GOK_USER_CONFIG" "User Config"
    check_config_file_status "$GOK_ROOT_CONFIG" "Root Config"
    check_config_file_status "$GOK_VM_CONFIG" "VM Config"
    
    # Identity provider info
    echo -e "\n${COLOR_BLUE}Authentication:${COLOR_RESET}"
    echo -e "  Identity Provider: ${COLOR_DIM}${IDENTITY_PROVIDER:-not set}${COLOR_RESET}"
    echo -e "  Authentication Method: ${COLOR_DIM}${AUTHENTICATION_METHOD:-not set}${COLOR_RESET}"
    echo -e "  Root Domain: ${COLOR_DIM}${GOK_ROOT_DOMAIN:-not set}${COLOR_RESET}"
    
    # OIDC configuration (if available)
    if [[ -n "${OIDC_ISSUE_URL:-}" ]]; then
        echo -e "\n${COLOR_BLUE}OIDC Configuration:${COLOR_RESET}"
        echo -e "  Issue URL: ${COLOR_DIM}${OIDC_ISSUE_URL}${COLOR_RESET}"
        echo -e "  Client ID: ${COLOR_DIM}${OIDC_CLIENT_ID:-not set}${COLOR_RESET}"
        echo -e "  App Host: ${COLOR_DIM}${APP_HOST:-not set}${COLOR_RESET}"
    fi
    
    echo
}

# Check configuration file status
check_config_file_status() {
    local file_path="$1"
    local file_name="$2"
    
    if [[ -f "$file_path" ]]; then
        local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "unknown")
        local file_mtime=$(stat -f%Sm "$file_path" 2>/dev/null || stat -c%y "$file_path" 2>/dev/null || echo "unknown")
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $file_name: ${COLOR_DIM}$file_path${COLOR_RESET} (${file_size} bytes)"
    else
        echo -e "  ${COLOR_YELLOW}✗${COLOR_RESET} $file_name: ${COLOR_DIM}$file_path${COLOR_RESET} (not found)"
    fi
}

# Reload configuration
reload_configuration() {
    log_info "Reloading GOK configuration"
    load_gok_configuration --force-reload
    log_success "Configuration reloaded successfully"
}

# Export configuration variables for components
export_configuration_variables() {
    # Export all configuration-related variables so they're available to components
    
    # Paths
    export MOUNT_PATH WORKING_DIR GOK_CONFIG_DIR
    export GOK_ROOT_CONFIG GOK_PROJECT_CONFIG GOK_USER_CONFIG GOK_VM_CONFIG
    
    # Authentication and identity
    export IDENTITY_PROVIDER AUTHENTICATION_METHOD GOK_ROOT_DOMAIN DEFAULT_SUBDOMAIN
    
    # OIDC/OAuth variables (if set)
    export OIDC_ISSUE_URL OIDC_CLIENT_ID OIDC_USERNAME_CLAIM OIDC_GROUPS_CLAIM
    export REALM AUTH0_DOMAIN APP_HOST JWKS_URL
    
    # Certificate manager variables
    export LETS_ENCRYPT_PROD_URL LETS_ENCRYPT_STAGING_URL CERTMANAGER_CHALANGE_TYPE LETS_ENCRYPT_ENV
    
    # Component service names
    export REGISTRY KEYCLOAK SPINNAKER VAULT JUPYTERHUB ARGOCD
    
    log_debug "Configuration variables exported for components"
}

# Get configuration value with fallback
get_config_value() {
    local var_name="$1"
    local default_value="${2:-}"
    
    local value="${!var_name:-$default_value}"
    echo "$value"
}

# Set configuration value
set_config_value() {
    local var_name="$1"
    local value="$2"
    
    export "$var_name"="$value"
    log_debug "Configuration variable set: $var_name=$value"
}

# =============================================================================
# COMPONENT INTEGRATION HELPERS
# =============================================================================

# Get component-specific configuration
get_component_config() {
    local component_name="$1"
    local component_config_dir="${WORKING_DIR}/${component_name}"
    
    # Try to source component-specific configuration
    local component_configs=(
        "${component_config_dir}/config"
        "${component_config_dir}/configuration"
        "${component_config_dir}/.env"
    )
    
    for config_file in "${component_configs[@]}"; do
        if [[ -f "$config_file" ]]; then
            log_debug "Loading component configuration: $config_file"
            source "$config_file"
            return 0
        fi
    done
    
    log_debug "No component configuration found for: $component_name"
    return 1
}

# Ensure configuration is loaded for component
ensure_configuration_for_component() {
    local component_name="$1"
    
    log_substep "Ensuring configuration for $component_name"
    
    # Load main configuration if not already loaded
    if [[ "${GOK_CONFIG_LOADED:-}" != "true" ]]; then
        init_gok_configuration
    fi
    
    # Load component-specific configuration
    get_component_config "$component_name"
    
    # Export variables for component usage
    export_configuration_variables
    
    log_debug "Configuration ensured for component: $component_name"
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize configuration module
init_config_module() {
    log_debug "Configuration module initializing"
    
    # Set up configuration debugging
    if [[ "$GOK_CONFIG_DEBUG" == "true" ]]; then
        log_debug "Configuration debugging enabled"
    fi
    
    # Set up configuration paths
    setup_configuration_paths
    
    log_debug "Configuration module initialized"
}

# Set derived environment variables for backward compatibility
set_derived_environment_variables() {
    # Set domain variables from GOK configuration
    export ROOT_DOMAIN="${ROOT_DOMAIN:-${GOK_ROOT_DOMAIN:-gokcloud.com}}"
    export REGISTRY_SUBDOMAIN="${REGISTRY_SUBDOMAIN:-${REGISTRY_SUBDOMAIN:-registry}}"
    export DEFAULT_SUBDOMAIN="${DEFAULT_SUBDOMAIN:-${DEFAULT_SUBDOMAIN:-kube}}"
    export KEYCLOAK_SUBDOMAIN="${KEYCLOAK_SUBDOMAIN:-${KEYCLOAK_SUBDOMAIN:-keycloak}}"
    export ARGOCD_SUBDOMAIN="${ARGOCD_SUBDOMAIN:-${ARGOCD_SUBDOMAIN:-argocd}}"
    export JUPYTERHUB_SUBDOMAIN="${JUPYTERHUB_SUBDOMAIN:-${JUPYTERHUB_SUBDOMAIN:-jupyter}}"
    
    log_debug "Derived environment variables set:"
    log_debug "  ROOT_DOMAIN: $ROOT_DOMAIN"
    log_debug "  REGISTRY_SUBDOMAIN: $REGISTRY_SUBDOMAIN"
    log_debug "  DEFAULT_SUBDOMAIN: $DEFAULT_SUBDOMAIN"
}

# Initialize the module when sourced
init_config_module

# Mark module as loaded
export GOK_CONFIG_LOADED="true"

log_debug "Configuration management module loaded successfully"