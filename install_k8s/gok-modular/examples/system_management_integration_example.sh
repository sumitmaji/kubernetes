#!/bin/bash
# examples/system_management_integration_example.sh
# Practical Integration Example for System Management Utilities
# 
# This example demonstrates how to integrate the system management utilities
# (system_update, dependency_manager, ha_validation) in a real component.
#
# Run this example:
#   bash examples/system_management_integration_example.sh
# =============================================================================

# Simulate GOK environment (normally handled by bootstrap)
export GOK_ROOT_DIR="/home/user/gok-modular"
export GOK_LIB_DIR="$GOK_ROOT_DIR/lib"
export GOK_CACHE_DIR="/tmp/gok-cache"
export GOK_UPDATE_CACHE_HOURS=6

# Source required utilities (normally handled by bootstrap)
source "$GOK_LIB_DIR/utils/colors.sh" 2>/dev/null || {
    # Fallback colors if not available
    export COLOR_GREEN="\033[32m"
    export COLOR_RED="\033[31m"
    export COLOR_YELLOW="\033[33m"
    export COLOR_BLUE="\033[34m"
    export COLOR_RESET="\033[0m"
}

source "$GOK_LIB_DIR/utils/logging.sh" 2>/dev/null || {
    # Fallback logging functions
    log_info() { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
    log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; }
    log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
    log_warning() { echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"; }
    log_step() { echo -e "\n${COLOR_BLUE}▶${COLOR_RESET} $1: $2"; }
    log_substep() { echo -e "  ${COLOR_BLUE}•${COLOR_RESET} $*"; }
}

# Load system management utilities
source "$GOK_LIB_DIR/utils/system_update.sh" 2>/dev/null || {
    echo "Warning: Could not load system_update.sh - some functions may not work"
}

source "$GOK_LIB_DIR/utils/dependency_manager.sh" 2>/dev/null || {
    echo "Warning: Could not load dependency_manager.sh - some functions may not work"
}

source "$GOK_LIB_DIR/utils/ha_validation.sh" 2>/dev/null || {
    echo "Warning: Could not load ha_validation.sh - some functions may not work"
}

# =============================================================================
# EXAMPLE COMPONENT: KUBERNETES WITH FULL INTEGRATION
# =============================================================================

install_kubernetes_example() {
    local verbose_mode=false
    local force_update=false
    local skip_deps=false
    local enable_ha=false
    
    # Parse example arguments
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_mode=true
                export GOK_VERBOSE=true
                ;;
            --force-update)
                force_update=true
                ;;
            --skip-deps)
                skip_deps=true
                ;;
            --enable-ha)
                enable_ha=true
                # Set HA environment variables for example
                export API_SERVERS="192.168.1.10:master1,192.168.1.11:master2"
                export HA_PROXY_PORT=6643
                ;;
            --help|-h)
                show_kubernetes_example_help
                return 0
                ;;
        esac
    done
    
    log_step "Kubernetes Example" "Installing Kubernetes with full system management integration"
    
    # =============================================================================
    # 1. SYSTEM UPDATE INTEGRATION
    # =============================================================================
    
    log_step "System Update" "Preparing system repositories"
    
    local update_options=()
    [[ "$verbose_mode" == "true" ]] && update_options+=("--verbose")
    [[ "$force_update" == "true" ]] && update_options+=("--force-update")
    
    # Check cache status first (for demonstration)
    log_substep "Checking system update cache status"
    show_system_update_status 2>/dev/null || {
        log_info "System update utility not available - simulating cache check"
        log_info "Cache Status: No cache found (simulation)"
    }
    
    # Prepare system for installation
    log_substep "Updating system packages"
    if type ensure_system_updated >/dev/null 2>&1; then
        if ! ensure_system_updated "kubernetes" "${update_options[@]}"; then
            log_error "Failed to prepare system for Kubernetes installation"
            return 1
        fi
    else
        log_info "System update utility not available - simulating update"
        simulate_system_update "$verbose_mode"
    fi
    
    # =============================================================================
    # 2. DEPENDENCY MANAGER INTEGRATION
    # =============================================================================
    
    log_step "Dependencies" "Installing Kubernetes dependencies"
    
    local dep_options=()
    [[ "$verbose_mode" == "true" ]] && dep_options+=("--verbose")
    [[ "$skip_deps" == "true" ]] && dep_options+=("--skip-deps")
    
    # Install component-specific dependencies
    log_substep "Installing Kubernetes-specific dependencies"
    if type ensure_dependencies_for_component >/dev/null 2>&1; then
        if ! ensure_dependencies_for_component "kubernetes" "${dep_options[@]}"; then
            log_error "Failed to install dependencies for Kubernetes"
            
            # Try to continue with critical dependencies only
            if type verify_critical_dependencies >/dev/null 2>&1; then
                if verify_critical_dependencies; then
                    log_warning "Continuing with minimal dependencies"
                else
                    log_error "Critical dependencies missing - cannot continue"
                    return 1
                fi
            else
                log_warning "Dependency manager not available - simulating dependency check"
                simulate_dependency_installation "$verbose_mode"
            fi
        fi
    else
        log_info "Dependency manager utility not available - simulating installation"
        simulate_dependency_installation "$verbose_mode"
    fi
    
    # Verify component-specific dependencies
    log_substep "Validating Kubernetes dependencies"
    if type validate_component_dependencies >/dev/null 2>&1; then
        if ! validate_component_dependencies "kubernetes"; then
            log_warning "Some Kubernetes dependencies may be missing"
        fi
    else
        log_info "Simulating Kubernetes dependency validation"
        simulate_kubernetes_dependency_validation
    fi
    
    # =============================================================================
    # 3. HA VALIDATION INTEGRATION (if enabled)
    # =============================================================================
    
    if [[ "$enable_ha" == "true" ]]; then
        log_step "HA Validation" "Validating High Availability configuration"
        
        local ha_options=()
        [[ "$verbose_mode" == "true" ]] && ha_options+=("--verbose")
        
        # Validate HA setup for Kubernetes
        log_substep "Checking HA proxy configuration"
        if type validate_ha_setup_for_component >/dev/null 2>&1; then
            if ! validate_ha_setup_for_component "kubernetes" "${ha_options[@]}"; then
                log_warning "HA validation failed - continuing with single-node setup"
                enable_ha=false
            else
                log_success "HA validation passed - enabling HA features"
            fi
        else
            log_info "HA validation utility not available - simulating validation"
            simulate_ha_validation "$verbose_mode"
        fi
        
        # Quick HA status check
        if [[ "$enable_ha" == "true" ]]; then
            log_substep "Performing HA status check"
            if type check_ha_status >/dev/null 2>&1; then
                if ! check_ha_status; then
                    log_warning "HA status check failed - may need troubleshooting"
                fi
            else
                log_info "Simulating HA status check"
                simulate_ha_status_check
            fi
        fi
    fi
    
    # =============================================================================
    # 4. COMPONENT INSTALLATION (Simulated)
    # =============================================================================
    
    log_step "Kubernetes Installation" "Installing Kubernetes components"
    
    # Simulate actual Kubernetes installation steps
    log_substep "Installing kubeadm, kubectl, kubelet"
    simulate_kubernetes_package_installation "$verbose_mode"
    
    log_substep "Initializing Kubernetes cluster"
    if [[ "$enable_ha" == "true" ]]; then
        simulate_ha_kubernetes_initialization
    else
        simulate_single_node_kubernetes_initialization
    fi
    
    log_substep "Configuring kubectl access"
    simulate_kubectl_configuration
    
    log_substep "Installing CNI network plugin"
    simulate_cni_installation
    
    # =============================================================================
    # 5. POST-INSTALLATION VALIDATION AND GUIDANCE
    # =============================================================================
    
    log_step "Validation" "Verifying Kubernetes installation"
    
    # Validate the installation
    log_substep "Checking cluster status"
    simulate_cluster_status_check
    
    log_substep "Verifying node readiness"
    simulate_node_readiness_check
    
    # Show post-installation guidance
    log_step "Guidance" "Post-installation information"
    show_kubernetes_installation_guidance "$enable_ha"
    
    log_success "Kubernetes installation completed successfully!"
    
    # Show system management summary
    show_system_management_summary
    
    return 0
}

# =============================================================================
# SIMULATION FUNCTIONS (for when utilities are not available)
# =============================================================================

simulate_system_update() {
    local verbose_mode="$1"
    
    if [[ "$verbose_mode" == "true" ]]; then
        log_info "Simulating verbose system update:"
        log_info "  • Updating package cache from repositories"
        log_info "  • Processing repository metadata"
        log_info "  • Validating package signatures"
        sleep 2
    else
        log_info "Simulating system update with progress indication"
        for i in {1..5}; do
            echo -n "."
            sleep 0.5
        done
        echo " done"
    fi
    
    log_success "System update simulation completed"
}

simulate_dependency_installation() {
    local verbose_mode="$1"
    
    local deps=("curl" "wget" "jq" "python3" "docker.io" "apt-transport-https")
    
    for dep in "${deps[@]}"; do
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "Installing $dep: Command line HTTP client"
        fi
        
        log_substep "✓ $dep installed successfully"
        sleep 0.3
    done
    
    log_success "All dependencies simulation completed"
}

simulate_kubernetes_dependency_validation() {
    log_substep "Checking Docker installation"
    if command -v docker >/dev/null 2>&1; then
        log_substep "✓ Docker is available"
    else
        log_substep "✗ Docker not found (simulated)"
    fi
    
    log_substep "Checking GPG availability"
    if command -v gpg >/dev/null 2>&1; then
        log_substep "✓ GPG is available"
    else
        log_substep "✗ GPG not found (simulated)"
    fi
    
    log_success "Kubernetes dependency validation simulation completed"
}

simulate_ha_validation() {
    local verbose_mode="$1"
    
    log_substep "Checking HA proxy container status"
    log_substep "✗ HA proxy container 'master-proxy' not found (expected in demo)"
    
    log_substep "Testing HA proxy connectivity"
    log_substep "✗ HA proxy port 6643 not accessible (expected in demo)"
    
    if [[ "$verbose_mode" == "true" ]]; then
        log_info "HA validation details (simulated):"
        log_info "  • API_SERVERS: ${API_SERVERS:-not set}"
        log_info "  • HA_PROXY_PORT: ${HA_PROXY_PORT:-not set}"
        log_info "  • Docker status: Available"
    fi
    
    log_warning "HA validation failed (expected in demo environment)"
}

simulate_ha_status_check() {
    log_substep "Docker daemon: Running"
    log_substep "HA proxy container: Not found (expected)"
    log_substep "Port accessibility: Failed (expected)"
    log_info "HA status check completed (demo mode)"
}

simulate_kubernetes_package_installation() {
    local verbose_mode="$1"
    
    local packages=("kubeadm" "kubectl" "kubelet")
    
    for package in "${packages[@]}"; do
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "Installing $package with detailed output"
        fi
        log_substep "✓ $package installed successfully"
        sleep 0.4
    done
}

simulate_ha_kubernetes_initialization() {
    log_info "Initializing HA Kubernetes cluster:"
    log_substep "• Generating cluster certificates"
    log_substep "• Configuring HA control plane endpoints"
    log_substep "• Setting up etcd cluster"
    log_substep "• Starting API server with load balancer"
    sleep 1
    log_success "HA Kubernetes cluster initialized"
}

simulate_single_node_kubernetes_initialization() {
    log_info "Initializing single-node Kubernetes cluster:"
    log_substep "• Generating cluster certificates" 
    log_substep "• Starting control plane components"
    log_substep "• Configuring single-node etcd"
    sleep 1
    log_success "Single-node Kubernetes cluster initialized"
}

simulate_kubectl_configuration() {
    log_substep "Creating kubectl configuration directory"
    log_substep "Copying admin kubeconfig"
    log_substep "Setting appropriate permissions"
    log_success "kubectl access configured"
}

simulate_cni_installation() {
    log_substep "Installing Calico CNI plugin"
    log_substep "Applying CNI configuration manifests"
    log_substep "Waiting for CNI pods to be ready"
    sleep 1
    log_success "CNI network plugin installed"
}

simulate_cluster_status_check() {
    log_substep "API server: Healthy"
    log_substep "etcd: Healthy" 
    log_substep "Controller manager: Healthy"
    log_substep "Scheduler: Healthy"
    log_success "Cluster status check passed"
}

simulate_node_readiness_check() {
    log_substep "Checking node status"
    log_substep "• master-node: Ready"
    log_substep "• CNI: Running"
    log_substep "• kube-proxy: Running"
    log_success "All nodes ready"
}

# =============================================================================
# GUIDANCE AND HELP FUNCTIONS
# =============================================================================

show_kubernetes_installation_guidance() {
    local ha_enabled="$1"
    
    echo -e "\n${COLOR_GREEN}${COLOR_BOLD}🎉 KUBERNETES INSTALLATION COMPLETED${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    echo -e "${COLOR_BLUE}Next Steps:${COLOR_RESET}"
    echo -e "  1. Verify cluster status: ${COLOR_DIM}kubectl get nodes${COLOR_RESET}"
    echo -e "  2. Deploy a test application: ${COLOR_DIM}kubectl create deployment nginx --image=nginx${COLOR_RESET}"
    echo -e "  3. Check pod status: ${COLOR_DIM}kubectl get pods${COLOR_RESET}"
    
    if [[ "$ha_enabled" == "true" ]]; then
        echo -e "\n${COLOR_BLUE}HA Configuration:${COLOR_RESET}"
        echo -e "  • HA proxy endpoint: ${COLOR_DIM}${HA_PROXY_HOSTNAME}:${HA_PROXY_PORT}${COLOR_RESET}"
        echo -e "  • API servers: ${COLOR_DIM}${API_SERVERS}${COLOR_RESET}"
        echo -e "  • Cluster mode: ${COLOR_DIM}High Availability${COLOR_RESET}"
    else
        echo -e "\n${COLOR_BLUE}Cluster Configuration:${COLOR_RESET}"
        echo -e "  • Cluster mode: ${COLOR_DIM}Single Node${COLOR_RESET}"
        echo -e "  • API endpoint: ${COLOR_DIM}https://$(hostname -I | awk '{print $1}'):6443${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_BLUE}Useful Commands:${COLOR_RESET}"
    echo -e "  • Get cluster info: ${COLOR_DIM}kubectl cluster-info${COLOR_RESET}"
    echo -e "  • View all resources: ${COLOR_DIM}kubectl get all --all-namespaces${COLOR_RESET}"
    echo -e "  • Access dashboard: ${COLOR_DIM}kubectl proxy${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}Configuration Files:${COLOR_RESET}"
    echo -e "  • kubeconfig: ${COLOR_DIM}~/.kube/config${COLOR_RESET}"
    echo -e "  • Cluster config: ${COLOR_DIM}/etc/kubernetes/admin.conf${COLOR_RESET}"
    
    echo
}

show_system_management_summary() {
    echo -e "\n${COLOR_BLUE}${COLOR_BOLD}📋 SYSTEM MANAGEMENT SUMMARY${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    # System update summary
    if type get_system_update_cache_status >/dev/null 2>&1; then
        local cache_status=$(get_system_update_cache_status)
        echo -e "${COLOR_BLUE}System Update:${COLOR_RESET} Cache status: $cache_status"
    else
        echo -e "${COLOR_BLUE}System Update:${COLOR_RESET} Simulated (utility not available)"
    fi
    
    # Dependencies summary
    echo -e "${COLOR_BLUE}Dependencies:${COLOR_RESET} Essential and Kubernetes-specific packages installed"
    
    # HA summary
    if [[ -n "${API_SERVERS:-}" ]]; then
        echo -e "${COLOR_BLUE}HA Configuration:${COLOR_RESET} Validated (simulated in demo)"
    else
        echo -e "${COLOR_BLUE}HA Configuration:${COLOR_RESET} Single-node setup"
    fi
    
    echo -e "${COLOR_BLUE}Cache Directory:${COLOR_RESET} $GOK_CACHE_DIR"
    echo -e "${COLOR_BLUE}Cache Timeout:${COLOR_RESET} ${GOK_UPDATE_CACHE_HOURS}h"
    
    echo
}

show_kubernetes_example_help() {
    echo "Kubernetes Installation Example with System Management Integration"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --verbose, -v         Enable verbose output and detailed logging"
    echo "  --force-update        Force system update (bypass cache)"
    echo "  --skip-deps           Skip dependency installation"
    echo "  --enable-ha           Enable HA validation and configuration"
    echo "  --help, -h            Show this help message"
    echo
    echo "This example demonstrates integration of:"
    echo "  • System Update Utility (smart caching, progress tracking)"
    echo "  • Dependency Manager (component-specific dependencies)" 
    echo "  • HA Validation Utility (high availability validation)"
    echo
    echo "Examples:"
    echo "  $0                    # Basic installation"
    echo "  $0 --verbose          # Verbose mode with detailed output"
    echo "  $0 --enable-ha        # Enable HA mode with validation"
    echo "  $0 --force-update     # Force system update regardless of cache"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo -e "${COLOR_BLUE}${COLOR_BOLD}GOK System Management Integration Example${COLOR_RESET}"
    echo -e "${COLOR_DIM}Demonstrates integration of system_update, dependency_manager, and ha_validation utilities${COLOR_RESET}"
    echo
    
    # Check if help was requested
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_kubernetes_example_help
            exit 0
        fi
    done
    
    # Run the Kubernetes installation example
    if install_kubernetes_example "$@"; then
        echo -e "\n${COLOR_GREEN}Example completed successfully!${COLOR_RESET}"
        echo -e "This demonstrates how components can integrate system management utilities."
        exit 0
    else
        echo -e "\n${COLOR_RED}Example failed!${COLOR_RESET}"
        echo -e "This shows how error handling works in the integration."
        exit 1
    fi
}

# Run the example if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi