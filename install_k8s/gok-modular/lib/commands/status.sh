#!/bin/bash

# GOK Status Command Module - System and component status checking

# Main status command handler
statusCmd() {
    local component="${1:-}"
    
    if [[ "$component" == "help" || "$component" == "--help" ]]; then
        show_status_help
        return 0
    fi
    
    log_header "System Status Check"
    
    if [[ -n "$component" ]]; then
        check_component_status "$component"
    else
        check_overall_status
    fi
}

# Show status command help
show_status_help() {
    echo "gok status - Check system and component status"
    echo ""
    echo "Usage: gok status [component]"
    echo ""
    echo "Examples:"
    echo "  gok status                    # Overall system status"
    echo "  gok status kubernetes         # Kubernetes cluster status"
    echo "  gok status monitoring         # Monitoring stack status"
}

# Check overall system status
check_overall_status() {
    log_section "System Overview"
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        log_warning "Docker: Not installed"
    fi
    
    # Check Kubernetes
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl cluster-info >/dev/null 2>&1; then
            log_success "Kubernetes: Cluster is running"
            local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
            log_info "Nodes: $nodes"
        else
            log_warning "Kubernetes: Cluster not accessible"
        fi
    else
        log_warning "Kubernetes: Not installed"
    fi
    
    # Check Helm
    if command -v helm >/dev/null 2>&1; then
        log_success "Helm: $(helm version --short)"
        local releases=$(helm list -A --short 2>/dev/null | wc -l)
        log_info "Helm releases: $releases"
    else
        log_warning "Helm: Not installed"
    fi
    
    # Check installed components
    log_section "Installed Components"
    local installed_file="${GOK_CACHE_DIR}/installed_components"
    if [[ -f "$installed_file" ]]; then
        while IFS=':' read -r component timestamp; do
            local install_date=$(date -d "@$timestamp" 2>/dev/null || echo "Unknown")
            log_info "$component: Installed on $install_date"
        done < "$installed_file"
    else
        log_info "No tracked component installations found"
    fi
}

# Check specific component status  
check_component_status() {
    local component="$1"
    
    log_section "Component Status: $component"
    
    case "$component" in
        "kubernetes")
            check_kubernetes_status
            ;;
        "docker")
            check_docker_status
            ;;
        "helm")
            check_helm_status
            ;;
        *)
            log_info "Checking generic component: $component"
            check_generic_component_status "$component"
            ;;
    esac
}

# Check Kubernetes status
check_kubernetes_status() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found"
        return 1
    fi
    
    # Cluster info
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster is accessible"
        
        # Node status
        log_substep "Nodes:"
        kubectl get nodes --no-headers 2>/dev/null | while read line; do
            local node_name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $2}')
            if [[ "$status" == "Ready" ]]; then
                log_info "  $node_name: $status"
            else
                log_warning "  $node_name: $status"  
            fi
        done
        
        # System pods
        log_substep "System pods:"
        local total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
        local running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep "Running" | wc -l)
        log_info "  Running: $running_pods/$total_pods"
        
    else
        log_error "Cluster is not accessible"
        return 1
    fi
}

# Check Docker status
check_docker_status() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found"
        return 1
    fi
    
    log_success "Docker version: $(docker --version)"
    
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon is running"
        
        # Container stats
        local running=$(docker ps -q 2>/dev/null | wc -l)
        local total=$(docker ps -aq 2>/dev/null | wc -l)
        log_info "Containers: $running running, $total total"
        
        # Image stats  
        local images=$(docker images -q 2>/dev/null | wc -l)
        log_info "Images: $images"
    else
        log_error "Docker daemon is not running"
        return 1
    fi
}

# Check Helm status
check_helm_status() {
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm not found"
        return 1
    fi
    
    log_success "Helm version: $(helm version --short)"
    
    # List releases
    log_substep "Helm releases:"
    if helm list -A --short 2>/dev/null | head -10 | while read release; do
        if [[ -n "$release" ]]; then
            log_info "  $release"
        fi
    done
    then
        local total_releases=$(helm list -A --short 2>/dev/null | wc -l)
        if [[ $total_releases -gt 10 ]]; then
            log_info "  ... and $((total_releases - 10)) more"
        fi
    else
        log_info "  No releases found"
    fi
}

# Check generic component status
check_generic_component_status() {
    local component="$1"
    
    # Check if it's a Helm release
    local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -i "$component" || true)
    
    if [[ -n "$namespaces" ]]; then
        for ns in $namespaces; do
            log_info "Namespace: $ns"
            local pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            local running=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "Running" | wc -l)
            log_substep "Pods in $ns: $running/$pods running"
        done
    else
        log_warning "No namespace found for component: $component"
    fi
}