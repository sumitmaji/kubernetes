#!/bin/bash
# =============================================================================
# GOK Modular Installation Validation System
# =============================================================================
# Comprehensive component-specific health checks and verification
# 
# Usage:
#   source lib/utils/validation.sh
#   validate_component_installation "kubernetes" 300
#   validate_kubernetes_cluster 300
#   validate_deployment_readiness "nginx" "default"
#   wait_for_pods_ready "monitoring" 300
# =============================================================================

# Ensure core utilities are available
if [[ -z "${GOK_ROOT}" ]]; then
    echo "Error: GOK_ROOT not set. Source bootstrap.sh first."
    return 1
fi

# Source dependencies
source "${GOK_ROOT}/lib/utils/logging.sh" 2>/dev/null || true
source "${GOK_ROOT}/lib/utils/colors.sh" 2>/dev/null || true

# =============================================================================
# VALIDATION CONFIGURATION
# =============================================================================

# Default timeouts for different components (in seconds)
declare -A COMPONENT_TIMEOUTS
COMPONENT_TIMEOUTS["kubernetes"]="180"
COMPONENT_TIMEOUTS["docker"]="60"
COMPONENT_TIMEOUTS["helm"]="30"
COMPONENT_TIMEOUTS["cert-manager"]="300"
COMPONENT_TIMEOUTS["ingress"]="240"
COMPONENT_TIMEOUTS["monitoring"]="600"
COMPONENT_TIMEOUTS["vault"]="300"
COMPONENT_TIMEOUTS["keycloak"]="480"
COMPONENT_TIMEOUTS["argocd"]="360"
COMPONENT_TIMEOUTS["jupyter"]="420"
COMPONENT_TIMEOUTS["registry"]="240"
COMPONENT_TIMEOUTS["base"]="120"

# Component-specific validation requirements
declare -A COMPONENT_NAMESPACES
COMPONENT_NAMESPACES["cert-manager"]="cert-manager"
COMPONENT_NAMESPACES["ingress"]="ingress-nginx"
COMPONENT_NAMESPACES["monitoring"]="monitoring"
COMPONENT_NAMESPACES["vault"]="vault"
COMPONENT_NAMESPACES["keycloak"]="keycloak"
COMPONENT_NAMESPACES["argocd"]="argocd"
COMPONENT_NAMESPACES["jupyter"]="jupyterhub"
COMPONENT_NAMESPACES["registry"]="registry"

# =============================================================================
# MAIN VALIDATION ENTRY POINT
# =============================================================================

# Validate component installation with comprehensive health checks
validate_component_installation() {
    local component="$1"
    local timeout="${2:-${COMPONENT_TIMEOUTS[$component]:-300}}" # Default 5 minutes timeout
    
    log_header "Component Validation" "Validating $component installation"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔍 VALIDATING $component INSTALLATION${COLOR_RESET}"
    echo
    
    case "$component" in
        "kubernetes")
            validate_kubernetes_cluster "$timeout"
            ;;
        "docker")
            validate_docker_installation "$timeout"
            ;;
        "helm")
            validate_helm_installation "$timeout"
            ;;
        "cert-manager")
            validate_cert_manager "$timeout"
            ;;
        "ingress")
            validate_ingress_controller "$timeout"
            ;;
        "monitoring")
            validate_monitoring_stack "$timeout"
            ;;
        "vault")
            validate_vault_installation "$timeout"
            ;;
        "keycloak")
            validate_keycloak_installation "$timeout"
            ;;
        "argocd")
            validate_argocd_installation "$timeout"
            ;;
        "jupyter")
            validate_jupyter_installation "$timeout"
            ;;
        "registry")
            validate_registry_installation "$timeout"
            ;;
        "base")
            validate_base_installation "$timeout"
            ;;
        "gok-controller"|"controller")
            validate_gok_controller_installation "$timeout"
            ;;
        *)
            validate_generic_component "$component" "$timeout"
            ;;
    esac
}

# =============================================================================
# COMPONENT-SPECIFIC VALIDATION FUNCTIONS
# =============================================================================

# Kubernetes cluster validation with comprehensive checks
validate_kubernetes_cluster() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Kubernetes cluster connectivity"
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Kubernetes cluster is accessible"
        
        # Get cluster info details
        local cluster_info=$(kubectl cluster-info 2>/dev/null)
        echo -e "${COLOR_CYAN}🔗 Cluster Details:${COLOR_RESET}"
        echo "$cluster_info" | head -3 | sed 's/^/   /'
    else
        log_error "Cannot connect to Kubernetes cluster"
        validation_passed=false
    fi
    
    log_step "2" "Checking node status"
    local nodes_info=$(kubectl get nodes --no-headers 2>/dev/null)
    if [[ -n "$nodes_info" ]]; then
        local total_nodes=$(echo "$nodes_info" | wc -l)
        local ready_nodes=$(echo "$nodes_info" | grep -c "Ready" || echo "0")
        
        if [[ "$ready_nodes" -gt 0 ]]; then
            log_success "Nodes: $ready_nodes/$total_nodes Ready"
            
            # Show node details
            echo -e "${COLOR_CYAN}📊 Node Status:${COLOR_RESET}"
            echo "$nodes_info" | while read -r line; do
                echo -e "   ${COLOR_GREEN}✓${COLOR_RESET} $line"
            done
        else
            log_error "No nodes in Ready state"
            validation_passed=false
        fi
    else
        log_error "No nodes found in cluster"
        validation_passed=false
    fi
    
    log_step "3" "Checking system pods"
    if check_system_pods_health; then
        log_success "System pods are healthy"
    else
        log_warning "Some system pods have issues"
    fi
    
    log_step "4" "Checking cluster networking"
    if test_cluster_networking; then
        log_success "Cluster networking is functional"
    else
        log_warning "Cluster networking has issues"
    fi
    
    display_validation_summary "$validation_passed" "Kubernetes Cluster"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Docker installation validation
validate_docker_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Docker daemon"
    if systemctl is-active --quiet docker; then
        log_success "Docker daemon is running"
        
        # Get Docker version and info
        local docker_version=$(docker --version 2>/dev/null | head -1)
        if [[ -n "$docker_version" ]]; then
            echo -e "${COLOR_CYAN}🐳 $docker_version${COLOR_RESET}"
        fi
    else
        log_error "Docker daemon is not running"
        validation_passed=false
    fi
    
    log_step "2" "Testing Docker functionality"
    if docker info >/dev/null 2>&1; then
        log_success "Docker is functional"
        
        # Show basic Docker info
        local docker_info=$(docker info --format "{{.ServerVersion}} | {{.OSType}} | {{.Architecture}}" 2>/dev/null)
        echo -e "${COLOR_CYAN}ℹ️  Info: $docker_info${COLOR_RESET}"
    else
        log_error "Docker is not functional"
        validation_passed=false
    fi
    
    log_step "3" "Testing container operations"
    if docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Container operations working"
    else
        log_warning "Container operations have issues"
    fi
    
    display_validation_summary "$validation_passed" "Docker"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Helm installation validation
validate_helm_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Helm binary"
    if command -v helm >/dev/null 2>&1; then
        local helm_version=$(helm version --short --client 2>/dev/null || echo "unknown")
        log_success "Helm is installed: $helm_version"
    else
        log_error "Helm is not installed"
        validation_passed=false
    fi
    
    log_step "2" "Testing Helm functionality"
    if helm repo list >/dev/null 2>&1; then
        log_success "Helm repositories accessible"
    else
        log_info "No Helm repositories configured yet"
    fi
    
    log_step "3" "Checking Helm permissions"
    if helm list -A >/dev/null 2>&1; then
        log_success "Helm has proper Kubernetes access"
    else
        log_warning "Helm may have permission issues"
    fi
    
    display_validation_summary "$validation_passed" "Helm"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Certificate Manager validation
validate_cert_manager() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking cert-manager namespace"
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        log_success "cert-manager namespace exists"
    else
        log_error "cert-manager namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking cert-manager deployment"
    if check_deployment_readiness "cert-manager" "cert-manager"; then
        log_success "cert-manager deployment is ready"
    else
        log_error "cert-manager deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking cert-manager pods"
    if ! wait_for_pods_ready "cert-manager" "$timeout" "cert-manager"; then
        log_error "cert-manager pods not ready"
        validation_passed=false
    else
        log_success "cert-manager pods are ready"
    fi
    
    log_step "4" "Checking cert-manager webhook"
    if kubectl get validatingwebhookconfiguration cert-manager-webhook >/dev/null 2>&1; then
        log_success "cert-manager webhook is configured"
    else
        log_warning "cert-manager webhook not found"
    fi
    
    display_validation_summary "$validation_passed" "Certificate Manager"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Ingress Controller validation
validate_ingress_controller() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking ingress-nginx namespace"
    if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
        log_success "ingress-nginx namespace exists"
    else
        log_error "ingress-nginx namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking ingress controller deployment"
    if check_deployment_readiness "ingress-nginx-controller" "ingress-nginx"; then
        log_success "Ingress controller deployment is ready"
    else
        log_error "Ingress controller deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking ingress controller pods"
    if ! wait_for_pods_ready "ingress-nginx" "$timeout" "ingress-nginx"; then
        log_error "Ingress controller pods not ready"
        validation_passed=false
    else
        log_success "Ingress controller pods are ready"
    fi
    
    log_step "4" "Checking ingress controller service"
    if check_service_connectivity "ingress-nginx-controller" "ingress-nginx"; then
        log_success "Ingress controller service is accessible"
        
        # Check for external access
        local service_type=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.type}' 2>/dev/null)
        if [[ "$service_type" == "LoadBalancer" ]]; then
            local external_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
                echo -e "${COLOR_CYAN}🌐 External IP: $external_ip${COLOR_RESET}"
            else
                echo -e "${COLOR_YELLOW}⏳ External IP pending...${COLOR_RESET}"
            fi
        elif [[ "$service_type" == "NodePort" ]]; then
            local node_port=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
            echo -e "${COLOR_CYAN}🌐 NodePort: $node_port${COLOR_RESET}"
        fi
    else
        log_error "Ingress controller service not accessible"
        validation_passed=false
    fi
    
    log_step "5" "Checking ingress class"
    if kubectl get ingressclass nginx >/dev/null 2>&1; then
        log_success "Nginx ingress class is available"
    else
        log_warning "Nginx ingress class not found"
    fi
    
    display_validation_summary "$validation_passed" "Ingress Controller"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Monitoring stack validation
validate_monitoring_stack() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking monitoring namespace"
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        log_success "monitoring namespace exists"
    else
        log_error "monitoring namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking monitoring pods"
    if ! wait_for_pods_ready "monitoring" "$timeout" "monitoring"; then
        log_error "Monitoring pods not ready"
        validation_passed=false
    else
        log_success "Monitoring pods are ready"
    fi
    
    log_step "3" "Checking Prometheus"
    if check_statefulset_readiness "prometheus-prometheus" "monitoring"; then
        log_success "Prometheus is deployed and ready"
    else
        log_error "Prometheus not found or not ready"
        validation_passed=false
    fi
    
    log_step "4" "Checking Grafana"
    if check_deployment_readiness "grafana" "monitoring"; then
        log_success "Grafana is deployed and ready"
    else
        log_error "Grafana not found or not ready"
        validation_passed=false
    fi
    
    log_step "5" "Checking monitoring services"
    local monitoring_services=$(kubectl get svc -n monitoring --no-headers 2>/dev/null | wc -l)
    if [[ "$monitoring_services" -gt 0 ]]; then
        log_success "Monitoring services available ($monitoring_services services)"
    else
        log_warning "No monitoring services found"
    fi
    
    display_validation_summary "$validation_passed" "Monitoring Stack"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Vault installation validation
validate_vault_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Vault namespace"
    if kubectl get namespace vault >/dev/null 2>&1; then
        log_success "vault namespace exists"
    else
        log_error "vault namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking Vault StatefulSet"
    if check_statefulset_readiness "vault" "vault"; then
        log_success "Vault StatefulSet is ready"
    else
        log_error "Vault StatefulSet has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking Vault pods"
    if ! wait_for_pods_ready "vault" "$timeout" "vault"; then
        log_error "Vault pods not ready"
        validation_passed=false
    else
        log_success "Vault pods are ready"
    fi
    
    log_step "4" "Checking Vault status"
    local vault_status=""
    if kubectl exec -n vault vault-0 -- vault status -format=json >/dev/null 2>&1; then
        vault_status=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed // "unknown"')
        case "$vault_status" in
            "false")
                log_success "Vault is unsealed and ready"
                ;;
            "true")
                log_warning "Vault is sealed - requires manual unsealing"
                echo -e "${COLOR_CYAN}📝 Unseal with: ${COLOR_BOLD}kubectl exec -n vault vault-0 -- vault operator unseal${COLOR_RESET}"
                ;;
            *)
                log_warning "Could not determine Vault status"
                ;;
        esac
    else
        log_warning "Unable to check Vault status (may still be initializing)"
    fi
    
    display_validation_summary "$validation_passed" "HashiCorp Vault"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Keycloak validation with comprehensive checks
validate_keycloak_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Keycloak namespace"
    if kubectl get namespace keycloak >/dev/null 2>&1; then
        log_success "keycloak namespace exists"
    else
        log_error "keycloak namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking Keycloak StatefulSet"
    if check_statefulset_readiness "keycloak" "keycloak"; then
        log_success "Keycloak StatefulSet is ready"
    else
        log_error "Keycloak StatefulSet has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking Keycloak pods"
    if ! wait_for_pods_ready "keycloak" "$timeout" "keycloak"; then
        log_error "Keycloak pods not ready"
        validation_passed=false
    else
        log_success "Keycloak pods are ready"
    fi
    
    log_step "4" "Checking Keycloak service"
    if check_service_connectivity "keycloak-http" "keycloak"; then
        log_success "Keycloak service is accessible"
    else
        log_warning "Keycloak service connectivity issues detected"
    fi
    
    log_step "5" "Checking Keycloak ingress"
    if kubectl get ingress keycloak -n keycloak >/dev/null 2>&1; then
        if check_ingress_status "keycloak" "keycloak"; then
            log_success "Keycloak ingress is configured and ready"
        else
            log_warning "Keycloak ingress has configuration issues"
        fi
    else
        log_info "Keycloak ingress not configured (using NodePort/LoadBalancer)"
    fi
    
    display_validation_summary "$validation_passed" "Keycloak"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# ArgoCD validation with comprehensive checks
validate_argocd_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking ArgoCD namespace"
    if kubectl get namespace argocd >/dev/null 2>&1; then
        log_success "argocd namespace exists"
    else
        log_error "argocd namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking ArgoCD server deployment"
    if check_deployment_readiness "argocd-server" "argocd"; then
        log_success "ArgoCD server deployment is ready"
    else
        log_error "ArgoCD server deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking ArgoCD pods"
    if ! wait_for_pods_ready "argocd" "$timeout" "argocd"; then
        log_error "ArgoCD pods not ready"
        validation_passed=false
    else
        log_success "ArgoCD pods are ready"
    fi
    
    log_step "4" "Checking ArgoCD services"
    if check_service_connectivity "argocd-server" "argocd"; then
        log_success "ArgoCD server service is accessible"
    else
        log_warning "ArgoCD server service connectivity issues detected"
    fi
    
    display_validation_summary "$validation_passed" "ArgoCD"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# JupyterHub validation with comprehensive checks
validate_jupyter_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking JupyterHub namespace"
    if kubectl get namespace jupyterhub >/dev/null 2>&1; then
        log_success "jupyterhub namespace exists"
    else
        log_error "jupyterhub namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking JupyterHub hub deployment"
    if check_deployment_readiness "hub" "jupyterhub"; then
        log_success "JupyterHub hub deployment is ready"
    else
        log_error "JupyterHub hub deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking JupyterHub pods"
    if ! wait_for_pods_ready "jupyterhub" "$timeout" "jupyterhub"; then
        log_error "JupyterHub pods not ready"
        validation_passed=false
    else
        log_success "JupyterHub pods are ready"
    fi
    
    log_step "4" "Checking JupyterHub proxy service"
    if check_service_connectivity "proxy-public" "jupyterhub"; then
        log_success "JupyterHub proxy service is accessible"
    else
        log_warning "JupyterHub proxy service connectivity issues detected"
    fi
    
    display_validation_summary "$validation_passed" "JupyterHub"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Registry validation with comprehensive checks
validate_registry_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking Registry namespace"
    if kubectl get namespace registry >/dev/null 2>&1; then
        log_success "registry namespace exists"
    else
        log_error "registry namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking Registry deployment"
    if check_deployment_readiness "registry" "registry"; then
        log_success "Registry deployment is ready"
    else
        log_error "Registry deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking Registry pods"
    if ! wait_for_pods_ready "registry" "$timeout" "registry"; then
        log_error "Registry pods not ready"
        validation_passed=false
    else
        log_success "Registry pods are ready"
    fi
    
    log_step "4" "Checking Registry service"
    if check_service_connectivity "registry" "registry"; then
        log_success "Registry service is accessible"
    else
        log_warning "Registry service connectivity issues detected"
    fi
    
    log_step "5" "Checking Registry ingress"
    if kubectl get ingress registry -n registry >/dev/null 2>&1; then
        if check_ingress_status "registry" "registry"; then
            log_success "Registry ingress is configured and ready"
        else
            log_warning "Registry ingress has configuration issues"
        fi
    else
        log_info "Registry ingress not configured (using NodePort/LoadBalancer)"
    fi
    
    display_validation_summary "$validation_passed" "Container Registry"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Base platform services validation
validate_base_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking base installation marker"
    if kubectl get configmap base-config -n kube-system >/dev/null 2>&1; then
        log_success "Base installation marker found"
    else
        log_info "Base installation marker not found (but installation may have succeeded)"
    fi
    
    log_step "2" "Checking base platform directory"
    local base_dir="${GOK_ROOT:-/opt/gok}/kubernetes/install_k8s/base"
    if [[ -d "$base_dir" ]]; then
        log_success "Base platform directory exists: $base_dir"
    else
        log_warning "Base platform directory not found: $base_dir"
    fi
    
    log_step "3" "Checking base services"
    local base_services=$(kubectl get svc -n kube-system --no-headers 2>/dev/null | grep -v "kube-" | wc -l)
    if [[ "$base_services" -gt 0 ]]; then
        log_success "Base services are available ($base_services services)"
    else
        log_info "No additional base services found"
    fi
    
    display_validation_summary "$validation_passed" "Base Platform"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# GOK Controller validation
validate_gok_controller_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1" "Checking GOK system namespace"
    if kubectl get namespace gok-system >/dev/null 2>&1; then
        log_success "gok-system namespace exists"
    else
        log_error "gok-system namespace not found"
        validation_passed=false
    fi
    
    log_step "2" "Checking GOK Controller deployment"
    if check_deployment_readiness "gok-controller" "gok-system"; then
        log_success "GOK Controller deployment is ready"
    else
        log_error "GOK Controller deployment has issues"
        validation_passed=false
    fi
    
    log_step "3" "Checking GOK Agent DaemonSet"
    if check_daemonset_readiness "gok-agent" "gok-system"; then
        log_success "GOK Agent DaemonSet is ready"
    else
        log_error "GOK Agent DaemonSet has issues"
        validation_passed=false
    fi
    
    display_validation_summary "$validation_passed" "GOK Controller"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Generic component validation with enhanced checks
validate_generic_component() {
    local component="$1"
    local timeout="$2"
    local validation_passed=true
    
    log_step "1" "Checking $component deployments"
    local deployments=$(kubectl get deployment -A --no-headers 2>/dev/null | grep "$component" | head -3)
    if [[ -n "$deployments" ]]; then
        echo "$deployments" | while read -r deploy_line; do
            local namespace=$(echo "$deploy_line" | awk '{print $1}')
            local deployment=$(echo "$deploy_line" | awk '{print $2}')
            if check_deployment_readiness "$deployment" "$namespace"; then
                log_success "Deployment $deployment is ready in $namespace"
            else
                log_warning "Deployment $deployment has issues in $namespace"
            fi
        done
    else
        log_info "No deployments found for $component"
    fi
    
    log_step "2" "Checking $component pods"
    if ! wait_for_pods_ready "$component" "$timeout" "$component"; then
        log_error "Pods not ready for $component"
        validation_passed=false
    else
        log_success "All $component pods are ready"
    fi
    
    log_step "3" "Checking $component services"
    local services=$(kubectl get svc -A --no-headers 2>/dev/null | grep "$component" | head -5)
    if [[ -n "$services" ]]; then
        log_success "$component services are available"
        echo "$services" | while read -r svc_line; do
            local namespace=$(echo "$svc_line" | awk '{print $1}')
            local service=$(echo "$svc_line" | awk '{print $2}')
            if check_service_connectivity "$service" "$namespace"; then
                echo -e "${COLOR_GREEN}    ✓ Service $service in $namespace is accessible${COLOR_RESET}"
            else
                echo -e "${COLOR_YELLOW}    ⚠ Service $service in $namespace has connectivity issues${COLOR_RESET}"
            fi
        done
    else
        log_warning "No services found for $component"
    fi
    
    display_validation_summary "$validation_passed" "$component"
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# HELPER FUNCTIONS FOR RESOURCE VALIDATION
# =============================================================================

# Check deployment readiness with detailed status
check_deployment_readiness() {
    local deployment="$1"
    local namespace="$2"
    
    if kubectl get deployment "$deployment" -n "$namespace" >/dev/null 2>&1; then
        local ready=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.replicas}' 2>/dev/null)
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            return 0
        fi
    fi
    return 1
}

# Check StatefulSet readiness
check_statefulset_readiness() {
    local statefulset="$1"
    local namespace="$2"
    
    if kubectl get statefulset "$statefulset" -n "$namespace" >/dev/null 2>&1; then
        local ready=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.replicas}' 2>/dev/null)
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            return 0
        fi
    fi
    return 1
}

# Check DaemonSet readiness
check_daemonset_readiness() {
    local daemonset="$1"
    local namespace="$2"
    
    if kubectl get daemonset "$daemonset" -n "$namespace" >/dev/null 2>&1; then
        local ready=$(kubectl get daemonset "$daemonset" -n "$namespace" -o jsonpath='{.status.numberReady}' 2>/dev/null)
        local desired=$(kubectl get daemonset "$daemonset" -n "$namespace" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            return 0
        fi
    fi
    return 1
}

# Wait for pods to be ready with timeout
wait_for_pods_ready() {
    local selector="$1"
    local timeout="$2"
    local namespace="${3:-}"
    
    local namespace_flag=""
    if [[ -n "$namespace" ]]; then
        namespace_flag="-n $namespace"
    fi
    
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $timeout ]]; then
            return 1
        fi
        
        # Check if pods exist and are ready
        local pods_total=$(eval "kubectl get pods $namespace_flag -l app=$selector --no-headers 2>/dev/null" | wc -l)
        if [[ "$pods_total" -eq 0 ]]; then
            # Try alternative selectors
            pods_total=$(eval "kubectl get pods $namespace_flag --no-headers 2>/dev/null | grep '$selector'" | wc -l)
        fi
        
        if [[ "$pods_total" -gt 0 ]]; then
            local pods_ready=$(eval "kubectl get pods $namespace_flag -l app=$selector --no-headers 2>/dev/null | grep -c '1/1\\|2/2\\|3/3'" || echo "0")
            if [[ "$pods_ready" -eq 0 ]]; then
                # Try alternative check
                pods_ready=$(eval "kubectl get pods $namespace_flag --no-headers 2>/dev/null | grep '$selector' | grep -c 'Running'" || echo "0")
            fi
            
            if [[ "$pods_ready" -eq "$pods_total" ]]; then
                return 0
            fi
        fi
        
        sleep 5
    done
}

# Check service connectivity
check_service_connectivity() {
    local service="$1"
    local namespace="$2"
    
    if kubectl get service "$service" -n "$namespace" >/dev/null 2>&1; then
        local cluster_ip=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
        local port=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
        
        if [[ -n "$cluster_ip" && "$cluster_ip" != "None" && -n "$port" ]]; then
            return 0
        fi
    fi
    return 1
}

# Check ingress status
check_ingress_status() {
    local ingress="$1"
    local namespace="$2"
    
    if kubectl get ingress "$ingress" -n "$namespace" >/dev/null 2>&1; then
        local ingress_ip=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        
        if [[ -n "$ingress_ip" && "$ingress_ip" != "null" ]]; then
            return 0
        fi
    fi
    return 1
}

# Check system pods health
check_system_pods_health() {
    local system_namespaces=("kube-system" "kube-public" "kube-node-lease")
    local all_healthy=true
    
    for namespace in "${system_namespaces[@]}"; do
        local unhealthy_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
        if [[ "$unhealthy_pods" -gt 0 ]]; then
            all_healthy=false
        fi
    done
    
    return $([[ "$all_healthy" == "true" ]] && echo 0 || echo 1)
}

# Test cluster networking
test_cluster_networking() {
    # Simple networking test using busybox
    local test_pod_name="gok-network-test-$(date +%s)"
    
    if kubectl run "$test_pod_name" --image=busybox --restart=Never --rm -i --tty --timeout=30s -- nslookup kubernetes.default >/dev/null 2>&1; then
        return 0
    else
        # Cleanup in case the pod wasn't removed
        kubectl delete pod "$test_pod_name" >/dev/null 2>&1 || true
        return 1
    fi
}

# =============================================================================
# VALIDATION SUMMARY AND REPORTING
# =============================================================================

# Display validation summary
display_validation_summary() {
    local validation_passed="$1"
    local component_name="$2"
    
    echo
    if [[ "$validation_passed" == "true" ]]; then
        echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✅ $component_name VALIDATION PASSED${COLOR_RESET}"
        echo -e "${COLOR_GREEN}All health checks completed successfully${COLOR_RESET}"
    else
        echo -e "${COLOR_BRIGHT_RED}${COLOR_BOLD}❌ $component_name VALIDATION FAILED${COLOR_RESET}"
        echo -e "${COLOR_RED}Some health checks failed - see details above${COLOR_RESET}"
        
        # Provide troubleshooting guidance
        echo
        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🛠️  TROUBLESHOOTING SUGGESTIONS:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Check pod logs: ${COLOR_BOLD}kubectl logs -l app=$component_name${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Describe pods: ${COLOR_BOLD}kubectl describe pods -l app=$component_name${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Check events: ${COLOR_BOLD}kubectl get events --sort-by=.metadata.creationTimestamp${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Run verification: ${COLOR_BOLD}gok-new verify $component_name${COLOR_RESET}"
    fi
    echo
}

# Export functions for use by other modules
export -f validate_component_installation
export -f validate_kubernetes_cluster
export -f validate_docker_installation
export -f validate_helm_installation
export -f check_deployment_readiness
export -f check_statefulset_readiness
export -f wait_for_pods_ready
export -f check_service_connectivity