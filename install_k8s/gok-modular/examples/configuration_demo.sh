#!/bin/bash
# examples/configuration_demo.sh
# Configuration System Demonstration for GOK-New
# 
# This example shows how the GOK-new configuration system works
# and replicates the functionality from lines 1-88 of the original GOK file
#
# Run this demo:
#   bash examples/configuration_demo.sh
# =============================================================================

# Setup demo environment
DEMO_DIR="/tmp/gok-config-demo"
mkdir -p "$DEMO_DIR"

# Simulate GOK environment (normally handled by bootstrap)
export GOK_ROOT_DIR="/home/sumit/Documents/repository/kubernetes/install_k8s/gok-modular"
export GOK_LIB_DIR="$GOK_ROOT_DIR/lib"
export MOUNT_PATH="/home/sumit/Documents/repository"
export WORKING_DIR="$MOUNT_PATH/kubernetes/install_k8s"

# Load minimal GOK system for demo
source "$GOK_LIB_DIR/utils/colors.sh" 2>/dev/null || {
    # Fallback colors
    export COLOR_GREEN="\033[32m"
    export COLOR_RED="\033[31m" 
    export COLOR_YELLOW="\033[33m"
    export COLOR_BLUE="\033[34m"
    export COLOR_BOLD="\033[1m"
    export COLOR_DIM="\033[2m"
    export COLOR_RESET="\033[0m"
}

source "$GOK_LIB_DIR/utils/logging.sh" 2>/dev/null || {
    # Fallback logging
    log_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
    log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; }
    log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
    log_warning() { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"; }
    log_step() { echo -e "\n${COLOR_BLUE}▶${COLOR_RESET} $1: $2"; }
    log_substep() { echo -e "  ${COLOR_BLUE}•${COLOR_RESET} $*"; }
    log_debug() { [[ "$GOK_DEBUG" == "true" ]] && echo -e "${COLOR_DIM}[DEBUG]${COLOR_RESET} $*"; }
}

# Load configuration module
if [[ -f "$GOK_LIB_DIR/core/config.sh" ]]; then
    source "$GOK_LIB_DIR/core/config.sh"
    CONFIG_MODULE_AVAILABLE=true
else
    echo "Warning: Configuration module not available - using simulation"
    CONFIG_MODULE_AVAILABLE=false
fi

# =============================================================================
# DEMO FUNCTIONS
# =============================================================================

create_demo_config_files() {
    log_step "Demo Setup" "Creating demo configuration files"
    
    # Create demo VM config
    mkdir -p "$DEMO_DIR/kubernetes/install_cluster"
    cat <<EOF > "$DEMO_DIR/kubernetes/install_cluster/vm_config"
# Demo VM Configuration
export MASTER_HOST_IP=192.168.1.100
export CLUSTER_NAME=demo-cluster.com
export DNS_DOMAIN=demo.local
EOF
    
    # Create demo project config
    mkdir -p "$DEMO_DIR/kubernetes/install_k8s"
    cat <<EOF > "$DEMO_DIR/kubernetes/install_k8s/config"
# Demo Project Configuration
source $DEMO_DIR/kubernetes/install_cluster/vm_config
export NUMBER_OF_HOSTS=1
export CLUSTER_NAME=demo-cluster.com
export DNS_DOMAIN=demo.local
export CERTIFICATE_PATH=/etc/kubernetes/pki
export SERVER_DNS=master.demo-cluster.com,kubernetes.default.svc,localhost
export SERVER_IP="192.168.1.100,127.0.0.1"
export HA_PROXY_PORT=6643
export HA_PROXY_HOSTNAME=192.168.1.100
export LOAD_BALANCER_URL=192.168.1.100:6643
export APP_HOST=master.demo-cluster.com
export GRAFANA_HOST=grafana.demo-cluster.com
export API_SERVERS="192.168.1.100:master.demo-cluster.com"
export IDENTITY_PROVIDER=keycloak
export GOK_ROOT_DOMAIN=demo-cluster.com
EOF
    
    # Create demo Keycloak config
    mkdir -p "$DEMO_DIR/kubernetes/install_k8s/keycloak"
    cat <<EOF > "$DEMO_DIR/kubernetes/install_k8s/keycloak/config"
# Demo Keycloak Configuration
export OIDC_ISSUE_URL=https://keycloak.demo-cluster.com/realms/DemoRealm
export OIDC_CLIENT_ID=demo-client
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=groups
export REALM=DemoRealm
export AUTH0_DOMAIN=keycloak.demo-cluster.com
export APP_HOST=kube.demo-cluster.com
export JWKS_URL=\$OIDC_ISSUE_URL/protocol/openid-connect/certs
EOF
    
    # Create user config directory
    mkdir -p "$HOME/.gok-demo"
    cat <<EOF > "$HOME/.gok-demo/config"
# Demo User Configuration
export GOK_DEBUG=true
export GOK_VERBOSE=true
export USER_PREFERENCE_THEME=dark
EOF
    
    log_success "Demo configuration files created"
}

demonstrate_original_gok_behavior() {
    log_step "Original GOK" "Demonstrating original GOK configuration loading (lines 1-88)"
    
    # Simulate the original GOK configuration loading
    echo -e "${COLOR_DIM}# Original GOK configuration loading process:${COLOR_RESET}"
    echo -e "${COLOR_DIM}# 1. Set default paths${COLOR_RESET}"
    echo "MOUNT_PATH=${MOUNT_PATH:-/home/sumit/Documents/repository}"
    echo "WORKING_DIR=\$MOUNT_PATH/kubernetes/install_k8s"
    
    echo -e "\n${COLOR_DIM}# 2. Source config file${COLOR_RESET}"
    if [[ -f "$DEMO_DIR/kubernetes/install_k8s/config" ]]; then
        echo "✓ Config file found: $DEMO_DIR/kubernetes/install_k8s/config"
        source "$DEMO_DIR/kubernetes/install_k8s/config"
    else
        echo "✗ Config file not found"
    fi
    
    echo -e "\n${COLOR_DIM}# 3. Get identity provider configuration${COLOR_RESET}"
    case "${IDENTITY_PROVIDER:-keycloak}" in
        "oauth0")
            echo "Using OAuth0 configuration"
            ;;
        "keycloak")
            echo "Using Keycloak configuration"
            if [[ -f "$DEMO_DIR/kubernetes/install_k8s/keycloak/config" ]]; then
                source "$DEMO_DIR/kubernetes/install_k8s/keycloak/config"
                echo "✓ Keycloak config loaded"
            fi
            ;;
    esac
    
    echo -e "\n${COLOR_DIM}# 4. Generate root_config${COLOR_RESET}"
    if [[ -w "$DEMO_DIR" ]]; then
        cat <<EOF > "$DEMO_DIR/root_config"
# Generated root_config (Original GOK style)
export LETS_ENCRYPT_PROD_URL=https://acme-v02.api.letsencrypt.org/directory
export LETS_ENCRYPT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory
export CERTMANAGER_CHALANGE_TYPE=selfsigned
export LETS_ENCRYPT_ENV=staging
export REGISTRY=registry
export KEYCLOAK=keycloak
export SPINNAKER=spinnaker
export VAULT=vault
export JUPYTERHUB=jupyterhub
export ARGOCD=argocd
export DEFAULT_SUBDOMAIN=kube
export GROUP_NAME=$GOK_ROOT_DOMAIN
export AUTHENTICATION_METHOD=oidc
export IDENTITY_PROVIDER=$IDENTITY_PROVIDER
export OIDC_ISSUE_URL=$OIDC_ISSUE_URL
export OIDC_CLIENT_ID=$OIDC_CLIENT_ID
export OIDC_USERNAME_CLAIM=$OIDC_USERNAME_CLAIM
export OIDC_GROUPS_CLAIM=$OIDC_GROUPS_CLAIM
export REALM=$REALM
export AUTH0_DOMAIN=$AUTH0_DOMAIN
export APP_HOST=$APP_HOST
export JWKS_URL=$JWKS_URL
EOF
        echo "✓ root_config generated at $DEMO_DIR/root_config"
    fi
    
    echo -e "\n${COLOR_DIM}# 5. Source root_config${COLOR_RESET}"
    if [[ -f "$DEMO_DIR/root_config" ]]; then
        source "$DEMO_DIR/root_config"
        echo "✓ root_config loaded"
    fi
    
    log_success "Original GOK configuration process completed"
}

demonstrate_gok_new_behavior() {
    log_step "GOK-New" "Demonstrating GOK-new modular configuration system"
    
    if [[ "$CONFIG_MODULE_AVAILABLE" == "true" ]]; then
        # Override paths for demo
        export MOUNT_PATH="$DEMO_DIR"
        export WORKING_DIR="$DEMO_DIR/kubernetes/install_k8s"
        export GOK_CONFIG_DIR="$HOME/.gok-demo"
        
        echo -e "${COLOR_DIM}# GOK-new configuration loading:${COLOR_RESET}"
        
        # Initialize configuration system
        log_substep "Initializing configuration system"
        if init_gok_configuration; then
            log_success "Configuration system initialized"
        else
            log_error "Configuration initialization failed"
        fi
        
        # Show configuration status
        show_configuration_status
        
    else
        # Simulate GOK-new behavior
        echo -e "${COLOR_DIM}# GOK-new configuration system (simulated):${COLOR_RESET}"
        echo -e "  1. ${COLOR_GREEN}✓${COLOR_RESET} Multi-layered configuration loading"
        echo -e "  2. ${COLOR_GREEN}✓${COLOR_RESET} Hierarchical configuration priority"
        echo -e "  3. ${COLOR_GREEN}✓${COLOR_RESET} Component-specific configuration"
        echo -e "  4. ${COLOR_GREEN}✓${COLOR_RESET} Configuration validation"
        echo -e "  5. ${COLOR_GREEN}✓${COLOR_RESET} Identity provider auto-detection"
        echo -e "  6. ${COLOR_GREEN}✓${COLOR_RESET} Environment variable management"
        
        log_info "Configuration module not available - showing simulated behavior"
    fi
}

show_configuration_comparison() {
    log_step "Comparison" "Original GOK vs GOK-new Configuration Features"
    
    echo -e "\n${COLOR_BOLD}Feature Comparison:${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════════════════════${COLOR_RESET}"
    
    # Feature comparison table
    printf "%-35s %-12s %-12s\n" "Feature" "Original GOK" "GOK-new"
    echo -e "${COLOR_DIM}───────────────────────────────────────────────────────────${COLOR_RESET}"
    printf "%-35s %-12s %-12s\n" "Basic config file loading" "✓" "✓"
    printf "%-35s %-12s %-12s\n" "Identity provider support" "✓" "✓" 
    printf "%-35s %-12s %-12s\n" "Root config generation" "✓" "✓"
    printf "%-35s %-12s %-12s\n" "OAuth0/Keycloak support" "✓" "✓"
    printf "%-35s %-12s %-12s\n" "Multi-layered config loading" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "Configuration validation" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "User config support" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "Component-specific config" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "Configuration debugging" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "Error handling" "Basic" "Advanced"
    printf "%-35s %-12s %-12s\n" "Configuration reload" "✗" "✓"
    printf "%-35s %-12s %-12s\n" "Modular design" "✗" "✓"
    
    echo -e "\n${COLOR_BLUE}Key Improvements in GOK-new:${COLOR_RESET}"
    echo -e "  • ${COLOR_GREEN}Hierarchical loading${COLOR_RESET}: System → Project → User → Root"
    echo -e "  • ${COLOR_GREEN}Validation system${COLOR_RESET}: Checks required variables and paths"
    echo -e "  • ${COLOR_GREEN}Component integration${COLOR_RESET}: Components can easily load their configs"
    echo -e "  • ${COLOR_GREEN}Error handling${COLOR_RESET}: Graceful handling of missing configs"
    echo -e "  • ${COLOR_GREEN}Debugging support${COLOR_RESET}: Detailed logging and status information"
    echo -e "  • ${COLOR_GREEN}Modular design${COLOR_RESET}: Configuration system is a reusable module"
}

show_usage_examples() {
    log_step "Usage" "How to use GOK-new configuration in components"
    
    echo -e "\n${COLOR_BLUE}Component Integration Examples:${COLOR_RESET}"
    
    echo -e "\n${COLOR_DIM}# 1. Basic configuration loading in a component${COLOR_RESET}"
    cat <<'EOF'
install_kubernetes() {
    # Ensure configuration is loaded
    ensure_configuration_for_component "kubernetes"
    
    # Use configuration variables
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Identity Provider: $IDENTITY_PROVIDER"
    
    # Continue with installation...
}
EOF
    
    echo -e "\n${COLOR_DIM}# 2. Component-specific configuration${COLOR_RESET}"
    cat <<'EOF'
install_monitoring() {
    # Load monitoring-specific config
    get_component_config "monitoring"
    
    # Use monitoring configuration
    install_prometheus_with_config
}
EOF
    
    echo -e "\n${COLOR_DIM}# 3. Configuration validation${COLOR_RESET}"
    cat <<'EOF'
install_vault() {
    # Validate configuration before installation
    validate_loaded_configuration
    
    # Check required variables
    if [[ -z "$VAULT_ADDR" ]]; then
        log_error "VAULT_ADDR not configured"
        return 1
    fi
}
EOF
    
    echo -e "\n${COLOR_DIM}# 4. Dynamic configuration reload${COLOR_RESET}"
    cat <<'EOF'
# Reload configuration when needed
reload_configuration

# Show configuration status
show_configuration_status
EOF
}

cleanup_demo() {
    log_step "Cleanup" "Cleaning up demo files"
    
    # Remove demo files
    rm -rf "$DEMO_DIR" 2>/dev/null
    rm -rf "$HOME/.gok-demo" 2>/dev/null
    
    log_success "Demo cleanup completed"
}

# =============================================================================
# MAIN DEMO EXECUTION
# =============================================================================

main() {
    echo -e "${COLOR_BOLD}${COLOR_BLUE}GOK Configuration System Demonstration${COLOR_RESET}"
    echo -e "${COLOR_DIM}Comparing original GOK (lines 1-88) with GOK-new modular configuration${COLOR_RESET}"
    echo
    
    # Create demo environment
    create_demo_config_files
    
    # Show original GOK behavior
    demonstrate_original_gok_behavior
    
    # Show GOK-new behavior
    demonstrate_gok_new_behavior
    
    # Compare features
    show_configuration_comparison
    
    # Show usage examples
    show_usage_examples
    
    # Cleanup
    cleanup_demo
    
    echo -e "\n${COLOR_GREEN}${COLOR_BOLD}Configuration Demo Completed!${COLOR_RESET}"
    echo -e "The GOK-new configuration system provides all the functionality"
    echo -e "from the original GOK file (lines 1-88) plus many enhancements."
}

# Run demo if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi