#!/bin/bash

# GOK Component Tracking Module - Enhanced installation status and progress tracking
# This module provides comprehensive component lifecycle tracking

# Ensure this module is loaded only once
# Temporarily disabled guard to fix bootstrap issues
# if [[ "${GOK_TRACKING_LOADED:-}" == "true" ]]; then
#     return 0
# fi
# export GOK_TRACKING_LOADED=true

# Component status tracking
declare -A GOK_COMPONENT_STATUS
declare -A GOK_COMPONENT_START_TIME
declare -A GOK_COMPONENT_END_TIME
declare -A GOK_COMPONENT_DESCRIPTION
declare -A GOK_COMPONENT_VERSION
declare -A GOK_COMPONENT_NAMESPACE
declare -A GOK_COMPONENT_ERROR_COUNT

# Component description maps
declare -A GOK_COMPONENT_INSTALL_DESCRIPTIONS
declare -A GOK_COMPONENT_UNINSTALL_DESCRIPTIONS

# Initialize component description maps
_init_component_descriptions() {
    # Infrastructure components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["docker"]="Installing Docker container runtime"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["docker"]="Uninstalling Docker container runtime"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["kubernetes"]="Installing Kubernetes cluster with HA support"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["kubernetes"]="Uninstalling Kubernetes cluster"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["kubernetes-worker"]="Installing Kubernetes worker node"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["kubernetes-worker"]="Uninstalling Kubernetes worker node"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["helm"]="Installing Helm package manager"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["helm"]="Uninstalling Helm package manager"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["haproxy"]="Installing HA proxy for load balancing"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["haproxy"]="Uninstalling HA proxy"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["ha-proxy"]="Installing HA proxy for load balancing"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["ha-proxy"]="Uninstalling HA proxy"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["ha"]="Installing HA proxy for load balancing"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["ha"]="Uninstalling HA proxy"

    # Security components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["cert-manager"]="Installing certificate management and TLS automation"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["cert-manager"]="Uninstalling certificate management"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["keycloak"]="Installing Keycloak identity and access management"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["keycloak"]="Uninstalling Keycloak identity management"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["oauth2"]="Installing OAuth2 proxy for authentication"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["oauth2"]="Uninstalling OAuth2 proxy"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["vault"]="Installing HashiCorp Vault secrets management"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["vault"]="Uninstalling HashiCorp Vault"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["ldap"]="Installing LDAP directory service"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["ldap"]="Uninstalling LDAP directory service"

    # Monitoring components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["monitoring"]="Installing Prometheus and Grafana monitoring stack"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["monitoring"]="Uninstalling monitoring stack"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["prometheus"]="Installing Prometheus monitoring system"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["prometheus"]="Uninstalling Prometheus monitoring"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["grafana"]="Installing Grafana visualization dashboard"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["grafana"]="Uninstalling Grafana dashboard"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["fluentd"]="Installing Fluentd log collection and forwarding"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["fluentd"]="Uninstalling Fluentd logging"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["opensearch"]="Installing OpenSearch analytics engine with dashboard"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["opensearch"]="Uninstalling OpenSearch analytics"

    # Development components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["dashboard"]="Installing Kubernetes web dashboard"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["dashboard"]="Uninstalling Kubernetes dashboard"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["jupyter"]="Installing JupyterHub for data science"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["jupyter"]="Uninstalling JupyterHub"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["devworkspace"]="Installing developer workspace (legacy)"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["devworkspace"]="Uninstalling developer workspace"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["workspace"]="Installing enhanced developer workspace"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["workspace"]="Uninstalling developer workspace"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["che"]="Installing Eclipse Che IDE"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["che"]="Uninstalling Eclipse Che IDE"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["ttyd"]="Installing terminal over HTTP"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["ttyd"]="Uninstalling terminal over HTTP"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["cloudshell"]="Installing cloud-based terminal"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["cloudshell"]="Uninstalling cloud-based terminal"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["console"]="Installing web-based console"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["console"]="Uninstalling web-based console"

    # CI/CD components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["argocd"]="Installing ArgoCD GitOps continuous delivery"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["argocd"]="Uninstalling ArgoCD GitOps"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["jenkins"]="Installing Jenkins CI/CD automation server"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["jenkins"]="Uninstalling Jenkins CI/CD server"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["spinnaker"]="Installing Spinnaker multi-cloud deployment platform"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["spinnaker"]="Uninstalling Spinnaker deployment platform"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["registry"]="Installing container image registry"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["registry"]="Uninstalling container registry"

    # GOK Platform components
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["gok-agent"]="Installing GOK distributed system agent"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["gok-agent"]="Uninstalling GOK agent"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["gok-controller"]="Installing GOK distributed system controller"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["gok-controller"]="Uninstalling GOK controller"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["controller"]="Installing GOK agent and controller"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["controller"]="Uninstalling GOK agent and controller"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["gok-login"]="Installing GOK authentication service"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["gok-login"]="Uninstalling GOK authentication service"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["chart"]="Installing Helm chart repository"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["chart"]="Uninstalling Helm chart repository"

    # Service Mesh and Networking
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["istio"]="Installing Istio service mesh"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["istio"]="Uninstalling Istio service mesh"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["rabbitmq"]="Installing RabbitMQ message broker"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["rabbitmq"]="Uninstalling RabbitMQ message broker"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["calico"]="Installing Calico network plugin"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["calico"]="Uninstalling Calico network plugin"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["ingress"]="Installing NGINX ingress controller"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["ingress"]="Uninstalling ingress controller"

    # Governance and Policy
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["kyverno"]="Installing Kyverno Kubernetes policy engine"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["kyverno"]="Uninstalling Kyverno policy engine"

    # Solution bundles
    GOK_COMPONENT_INSTALL_DESCRIPTIONS["base"]="Installing base platform with Docker images and caching"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["base"]="Uninstalling base platform"

    GOK_COMPONENT_INSTALL_DESCRIPTIONS["base-services"]="Installing complete base services stack"
    GOK_COMPONENT_UNINSTALL_DESCRIPTIONS["base-services"]="Uninstalling base services stack"
}

# Initialize descriptions on module load
_init_component_descriptions

# Status constants
readonly STATUS_IDLE="idle"
readonly STATUS_STARTING="starting"
readonly STATUS_IN_PROGRESS="in_progress"
readonly STATUS_SUCCESS="success"
readonly STATUS_FAILED="failed"
readonly STATUS_SKIPPED="skipped"
readonly STATUS_PARTIAL="partial"

# Initialize component tracking system
init_component_tracking() {
    local component="$1"
    local description="$2"
    local version="${3:-latest}"
    local namespace="${4:-default}"
    
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    [[ ! -f "$tracking_file" ]] && touch "$tracking_file"
    
    GOK_COMPONENT_STATUS["$component"]="$STATUS_IDLE"
    GOK_COMPONENT_DESCRIPTION["$component"]="$description"
    GOK_COMPONENT_VERSION["$component"]="$version"
    GOK_COMPONENT_NAMESPACE["$component"]="$namespace"
    GOK_COMPONENT_ERROR_COUNT["$component"]="0"
    
    log_debug "Initialized tracking for component: $component"
}

# Start tracking a component installation
start_component() {
    local component="$1"
    local description="${2:-}"
    
    # Use predefined install description if no description provided
    if [[ -z "$description" ]]; then
        description=$(get_install_description "$component")
    fi
    
    GOK_COMPONENT_STATUS["$component"]="$STATUS_STARTING"
    GOK_COMPONENT_START_TIME["$component"]=$(date +%s)
    
    # Update tracking file
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    echo "${component}:${STATUS_IN_PROGRESS}:$(date +%s):$description" >> "$tracking_file"
    
    log_component_start "$component" "$description"
    GOK_COMPONENT_STATUS["$component"]="$STATUS_IN_PROGRESS"
    
    # Create component-specific log file
    local log_dir="${GOK_LOG_DIR:-${GOK_ROOT}/logs}/components"
    mkdir -p "$log_dir"
    export GOK_COMPONENT_LOG="$log_dir/${component}_$(date +%Y%m%d_%H%M%S).log"
    
    echo "=== Component Installation Started: $component ===" >> "$GOK_COMPONENT_LOG"
    echo "Description: $description" >> "$GOK_COMPONENT_LOG"
    echo "Start Time: $(date)" >> "$GOK_COMPONENT_LOG"
    echo "Version: ${GOK_COMPONENT_VERSION[$component]:-unknown}" >> "$GOK_COMPONENT_LOG"
    echo "Namespace: ${GOK_COMPONENT_NAMESPACE[$component]:-default}" >> "$GOK_COMPONENT_LOG"
    echo "===========================================" >> "$GOK_COMPONENT_LOG"
}

# Mark component installation as completed
complete_component() {
    local component="$1"
    local message="${2:-Installation completed successfully}"
    local details="${3:-}"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    # Update status to completed
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    
    echo "${component}:completed:$(date +%s)" >> "$tracking_file"
    
    log_success "Component installation completed: $component"
}

# Mark component installation as failed
fail_component() {
    local component="$1"
    local reason="${2:-Installation failed}"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    # Update status to failed
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    
    echo "${component}:failed:$(date +%s):$reason" >> "$tracking_file"
    
    log_error "Component installation failed: $component - $reason"
}

# Skip component installation
skip_component() {
    local component="$1"
    local reason="${2:-Skipped by user}"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    echo "${component}:skipped:$(date +%s):$reason" >> "$tracking_file"
    
    log_warning "Component installation skipped: $component - $reason"
}

# Get component status
get_component_status() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    if [[ -f "$tracking_file" ]]; then
        grep "^${component}:" "$tracking_file" | tail -1 | cut -d: -f2 2>/dev/null || echo "not-found"
    else
        echo "not-found"
    fi
}

# Check if component installation was successful
is_component_successful() {
    local component="$1"
    local status=$(get_component_status "$component")
    [[ "$status" == "completed" ]]
}

# Get component installation time
get_component_time() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    if [[ -f "$tracking_file" ]]; then
        local entry=$(grep "^${component}:" "$tracking_file" | tail -1)
        local timestamp=$(echo "$entry" | cut -d: -f3 2>/dev/null)
        if [[ -n "$timestamp" && "$timestamp" != "" ]]; then
            date -d "@$timestamp" 2>/dev/null || echo "Unknown"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

# Show installation summary for all components
show_installation_summary() {
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    log_header "Installation Summary"
    
    if [[ ! -f "$tracking_file" ]]; then
        log_info "No component installations tracked yet"
        return 0
    fi
    
    # Group components by status
    local completed=()
    local failed=()
    local in_progress=()
    local skipped=()
    
    while IFS=':' read -r component status timestamp reason; do
        case "$status" in
            "completed")
                completed+=("$component")
                ;;
            "failed")
                failed+=("$component")
                ;;
            "in-progress")
                in_progress+=("$component")
                ;;
            "skipped")
                skipped+=("$component")
                ;;
        esac
    done < "$tracking_file"
    
    # Display summary
    if [[ ${#completed[@]} -gt 0 ]]; then
        log_success "Completed (${#completed[@]}): ${completed[*]}"
    fi
    
    if [[ ${#in_progress[@]} -gt 0 ]]; then
        log_warning "In Progress (${#in_progress[@]}): ${in_progress[*]}"
    fi
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed (${#failed[@]}): ${failed[*]}"
    fi
    
    if [[ ${#skipped[@]} -gt 0 ]]; then
        log_info "Skipped (${#skipped[@]}): ${skipped[*]}"
    fi
    
    if [[ ${#completed[@]} -eq 0 && ${#failed[@]} -eq 0 && ${#in_progress[@]} -eq 0 && ${#skipped[@]} -eq 0 ]]; then
        log_info "No component installations found"
    fi
}

# Get component description
get_component_description() {
    local component="$1"
    
    if [[ -n "${GOK_COMPONENT_DESCRIPTION[$component]:-}" ]]; then
        echo "${GOK_COMPONENT_DESCRIPTION[$component]}"
    else
        echo "No description available for component: $component"
        return 1
    fi
}

# Set component description
set_component_description() {
    local component="$1"
    local description="$2"
    
    if [[ -z "$description" ]]; then
        log_error "Description cannot be empty"
        return 1
    fi
    
    GOK_COMPONENT_DESCRIPTION["$component"]="$description"
    log_debug "Updated description for component $component: $description"
}

# Reset component description to default
reset_component_description() {
    local component="$1"
    local default_description="Installing $component component"
    
    GOK_COMPONENT_DESCRIPTION["$component"]="$default_description"
    log_debug "Reset description for component $component to: $default_description"
}

# Get install description from predefined map
get_install_description() {
    local component="$1"
    
    if [[ -n "${GOK_COMPONENT_INSTALL_DESCRIPTIONS[$component]:-}" ]]; then
        echo "${GOK_COMPONENT_INSTALL_DESCRIPTIONS[$component]}"
    else
        echo "Installing $component component"
    fi
}

# Get uninstall description from predefined map
get_uninstall_description() {
    local component="$1"
    
    if [[ -n "${GOK_COMPONENT_UNINSTALL_DESCRIPTIONS[$component]:-}" ]]; then
        echo "${GOK_COMPONENT_UNINSTALL_DESCRIPTIONS[$component]}"
    else
        echo "Uninstalling $component component"
    fi
}

# Reset component description to uninstall description
reset_component_description_to_uninstall() {
    local component="$1"
    local uninstall_description=$(get_uninstall_description "$component")
    
    GOK_COMPONENT_DESCRIPTION["$component"]="$uninstall_description"
    log_debug "Reset description for component $component to uninstall: $uninstall_description"
}

# Export tracking functions
export -f init_component_tracking start_component complete_component
export -f fail_component skip_component get_component_status
export -f is_component_successful get_component_time show_installation_summary
export -f get_component_description set_component_description reset_component_description
export -f get_install_description get_uninstall_description reset_component_description_to_uninstall