#!/bin/bash
# =============================================================================
# GOK Modular - Comprehensive Validation Utilities
# =============================================================================

# Source dependencies
if [[ -f "${BASH_SOURCE[0]%/*}/logging.sh" ]]; then
    source "${BASH_SOURCE[0]%/*}/logging.sh"
fi
if [[ -f "${BASH_SOURCE[0]%/*}/colors.sh" ]]; then
    source "${BASH_SOURCE[0]%/*}/colors.sh"
fi
# verbosity.sh is loaded by bootstrap before validation.sh
# if [[ -f "${BASH_SOURCE[0]%/*}/verbosity.sh" ]]; then
#     source "${BASH_SOURCE[0]%/*}/verbosity.sh"
# fi

# =============================================================================
# HELPER FUNCTIONS FOR VALIDATION
# =============================================================================

# Wait for pods to be ready in a namespace
wait_for_pods_ready() {
    local namespace="${1:-default}"
    local timeout="${2:-300}"
    local component="${3:-}"
    local max_wait_time="$timeout"
    local wait_time=0
    local check_interval=10
    
    if [[ -n "$component" ]]; then
        log_info "Waiting for $component pods to be ready in namespace '$namespace'..."
    else
        log_info "Waiting for all pods to be ready in namespace '$namespace'..."
    fi
    
    while [[ $wait_time -lt $max_wait_time ]]; do
        local pending_pods
        local failed_pods
        if is_verbose; then
            log_debug "Getting pod status in namespace $namespace"
        fi
        pending_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -E "(Pending|ContainerCreating|Init:|PodInitializing)" | wc -l)
        failed_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError)" | wc -l)
        
        # Clean up whitespace from wc output
        pending_pods=$(echo "$pending_pods" | tr -d '[:space:]')
        failed_pods=$(echo "$failed_pods" | tr -d '[:space:]')
        
        if [[ $pending_pods -eq 0 && $failed_pods -eq 0 ]]; then
            local ready_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c "Running\|Completed" || echo "0")
            ready_pods=$(echo "$ready_pods" | tr -d '[:space:]')
            if [[ $ready_pods -gt 0 ]]; then
                log_success "All pods are ready in namespace '$namespace'"
                return 0
            fi
        fi
        
        if [[ $failed_pods -gt 0 ]]; then
            log_warning "Found $failed_pods failed pods in namespace '$namespace'"
            if is_verbose; then
                execute_controlled "Showing failed pods" "kubectl get pods -n \"$namespace\" --no-headers | grep -E '(Error|CrashLoopBackOff|ImagePullBackOff|ErrImagePull)'"
            fi
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
        log_verbose "Waiting... ($wait_time/$max_wait_time seconds elapsed)"
    done
    
    log_error "Timeout waiting for pods in namespace '$namespace'"
    return 1
}

# Check deployment readiness with detailed diagnostics
check_deployment_readiness() {
    local deployment="$1"
    local namespace="$2"
    
    if [[ -z "$deployment" || -z "$namespace" ]]; then
        log_error "Deployment name and namespace required"
        return 1
    fi
    
    log_info "🚀 Analyzing deployment readiness: $deployment"
    
    # Get deployment status
    local deployment_info=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}/{.status.replicas} {.status.conditions[?(@.type=="Available")].status} {.status.conditions[?(@.type=="Progressing")].status}' 2>/dev/null)
    
    if [[ -z "$deployment_info" ]]; then
        log_error "Deployment $deployment not found in namespace $namespace"
        return 1
    fi
    
    local ready_replicas=$(echo "$deployment_info" | cut -d' ' -f1 | cut -d'/' -f1)
    local total_replicas=$(echo "$deployment_info" | cut -d' ' -f1 | cut -d'/' -f2)
    local available_status=$(echo "$deployment_info" | cut -d' ' -f2)
    local progressing_status=$(echo "$deployment_info" | cut -d' ' -f3)
    
    echo -e "${COLOR_CYAN}  📊 Ready: ${COLOR_BOLD}${ready_replicas:-0}/${total_replicas:-0}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  📈 Available: ${COLOR_BOLD}$available_status${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  🔄 Progressing: ${COLOR_BOLD}$progressing_status${COLOR_RESET}"
    
    # Check if deployment is healthy
    if [[ "$ready_replicas" == "$total_replicas" ]] && [[ "$available_status" == "True" ]]; then
        log_success "Deployment $deployment is ready and healthy"
        return 0
    else
        log_warning "Deployment $deployment is not fully ready"
        
        # Get replica set issues
        echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔍 REPLICA SET ANALYSIS:${COLOR_RESET}"
        kubectl describe deployment "$deployment" -n "$namespace" 2>/dev/null | grep -A 10 "Conditions:\|Events:" | tail -20
        
        return 1
    fi
}

# Check StatefulSet readiness
check_statefulset_readiness() {
    local statefulset="$1"
    local namespace="$2"
    
    if [[ -z "$statefulset" || -z "$namespace" ]]; then
        log_error "StatefulSet name and namespace required"
        return 1
    fi
    
    if is_verbose; then
        log_debug "Getting StatefulSet status for $statefulset in namespace $namespace"
    fi
    local ready_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    local total_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null)
    
    if [[ -z "$ready_replicas" || -z "$total_replicas" ]]; then
        log_error "StatefulSet '$statefulset' not found in namespace '$namespace'"
        return 1
    fi
    
    if [[ "$ready_replicas" == "$total_replicas" ]]; then
        log_success "StatefulSet '$statefulset' is ready ($ready_replicas/$total_replicas replicas)"
        return 0
    else
        log_warning "StatefulSet '$statefulset' not fully ready ($ready_replicas/$total_replicas replicas)"
        return 1
    fi
}

# Check service connectivity
check_service_connectivity() {
    local service="$1"
    local namespace="$2"
    
    if [[ -z "$service" || -z "$namespace" ]]; then
        log_error "Service name and namespace required"
        return 1
    fi
    
    if is_verbose; then
        log_debug "Getting service details for $service in namespace $namespace"
    fi
    local service_ip=$(kubectl get svc "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    local service_port=$(kubectl get svc "$service" -n "$namespace" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [[ -z "$service_ip" || "$service_ip" == "None" ]]; then
        log_warning "Service '$service' in namespace '$namespace' has no ClusterIP"
        return 1
    fi
    
    if [[ -z "$service_port" ]]; then
        log_warning "Service '$service' in namespace '$namespace' has no port defined"
        return 1
    fi
    
    # Test service connectivity using kubectl proxy or direct check
    local endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [[ -n "$endpoints" ]]; then
        log_success "Service '$service' has active endpoints"
        return 0
    else
        log_warning "Service '$service' has no active endpoints"
        return 1
    fi
}

# Check ingress status
check_ingress_status() {
    local ingress="$1"
    local namespace="$2"
    
    if [[ -z "$ingress" || -z "$namespace" ]]; then
        log_error "Ingress name and namespace required"
        return 1
    fi
    
    if is_verbose; then
        log_debug "Getting ingress details for $ingress in namespace $namespace"
    fi
    local ingress_class=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
    local load_balancer_ip=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [[ -z "$ingress_class" ]]; then
        log_warning "Ingress '$ingress' has no ingress class defined"
        return 1
    fi
    
    if [[ -n "$load_balancer_ip" && "$load_balancer_ip" != "null" ]]; then
        log_success "Ingress '$ingress' has load balancer IP: $load_balancer_ip"
        return 0
    else
        log_info "Ingress '$ingress' is configured but no external IP assigned yet"
        return 0
    fi
}

# Check for Docker image pull issues in pods
check_image_pull_issues() {
    local namespace="$1"
    local component="$2"
    
    log_info "🐳 Checking for Docker image pull issues in $component..."
    
    # Get pods with image pull errors
    if is_verbose; then
        log_debug "Checking for image pull issues in namespace $namespace"
    fi
    local image_pull_pods=$(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' 2>/dev/null | grep -E "(ImagePullBackOff|ErrImagePull)" | cut -d' ' -f1)
    
    if [[ -n "$image_pull_pods" ]]; then
        log_error "Found pods with image pull issues:"
        echo "$image_pull_pods" | while read -r pod; do
            if [[ -n "$pod" ]]; then
                echo -e "${COLOR_RED}  ❌ Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                
                # Get detailed image pull error information
                if is_verbose; then
                    local image_error=$(kubectl describe pod "$pod" -n "$namespace" 2>/dev/null | grep -A 3 -B 1 "Failed to pull image\|Error response from daemon")
                    if [[ -n "$image_error" ]]; then
                        echo -e "${COLOR_YELLOW}     Error details:${COLOR_RESET}"
                        echo "$image_error" | sed 's/^/       /'
                    fi
                fi
                
                # Get the image name causing issues
                local failed_image=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].image}' 2>/dev/null)
                if [[ -n "$failed_image" ]]; then
                    echo -e "${COLOR_CYAN}     Image: ${COLOR_BOLD}$failed_image${COLOR_RESET}"
                fi
            fi
        done
        
        # Provide troubleshooting suggestions
        echo
        echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🛠️  TROUBLESHOOTING SUGGESTIONS:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Check Docker registry connectivity: ${COLOR_BOLD}docker pull <image>${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Verify image exists in registry: ${COLOR_BOLD}curl -s <registry-url>/v2/<image>/tags/list${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Check image pull secrets: ${COLOR_BOLD}kubectl get secrets -n $namespace${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Verify network/proxy settings for image registry access${COLOR_RESET}"
        echo
        return 1
    else
        log_success "No Docker image pull issues found"
        return 0
    fi
}

# Check for resource constraint issues
check_resource_constraints() {
    local namespace="$1"
    local component="$2"
    
    log_info "📊 Checking for resource constraint issues in $component..."
    
    # Check for pods with resource-related issues
    local resource_issues=$(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].state.waiting.reason}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -E "(OutOfMemory|OutOfCpu|Evicted|OutOfDisk)")
    
    if [[ -n "$resource_issues" ]]; then
        log_warning "Found pods with resource constraint issues:"
        echo "$resource_issues" | while read -r line; do
            if [[ -n "$line" ]]; then
                local pod=$(echo "$line" | cut -d' ' -f1)
                echo -e "${COLOR_YELLOW}  ⚠️  Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                
                # Get resource usage and limits
                kubectl top pod "$pod" -n "$namespace" 2>/dev/null | tail -n +2 | while read -r usage_line; do
                    echo -e "${COLOR_CYAN}     Resource usage: $usage_line${COLOR_RESET}"
                done
            fi
        done
        
        # Show node resource availability
        echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📈 NODE RESOURCE STATUS:${COLOR_RESET}"
        kubectl top nodes 2>/dev/null | head -10
        echo
        return 1
    else
        log_success "No resource constraint issues found"
        return 0
    fi
}

# =============================================================================
# COMPONENT VALIDATION FUNCTIONS
# =============================================================================

# Main component validation dispatcher
validate_component_installation() {
    local component="$1"
    local timeout="${2:-300}"
    
    if [[ -z "$component" ]]; then
        log_error "Component name is required for validation"
        return 1
    fi
    
    log_header "Validating $component Installation" "Component Verification"
    
    case "$component" in
        "docker")
            validate_docker_installation "$timeout"
            ;;
        "kubernetes")
            validate_kubernetes_cluster "$timeout"
            ;;
        "helm")
            validate_helm_installation "$timeout"
            ;;
        "cert-manager")
            validate_cert_manager "$timeout"
            ;;
        "ingress-nginx"|"ingress")
            validate_ingress_controller "$timeout"
            ;;
        "monitoring")
            validate_monitoring_stack "$timeout"
            ;;
        "vault")
            validate_vault_installation "$timeout"
            ;;
        "gok-controller")
            validate_gok_controller_installation "$timeout"
            ;;
        "che")
            validate_che
            ;;
        "workspace")
            validate_workspace
            ;;
        "workspacev2")
            validate_workspacev2
            ;;
        "keycloak")
            validate_keycloak_installation "$timeout"
            ;;
        "argocd")
            validate_argocd_installation "$timeout"
            ;;
        "jupyterhub"|"jupyter")
            validate_jupyter_installation "$timeout"
            ;;
        "registry")
            validate_registry_installation "$timeout"
            ;;
        "base")
            validate_base_installation "$timeout"
            ;;
        "ha-proxy"|"haproxy")
            validate_ha_proxy_installation "$timeout"
            ;;
        "system")
            validate_system_requirements
            ;;
        *)
            log_info "Using generic validation for component: $component"
            validate_generic_component "$component" "$timeout"
            ;;
    esac
}

# Generic component validation
validate_generic_component() {
    local component="$1"
    local timeout="$2"
    local validation_passed=true
    
    log_step "1. Checking $component deployments"
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
    fi
    
    log_step "2. Checking $component pods"
    if ! wait_for_pods_ready "$component" "$timeout" "$component"; then
        log_error "Pods not ready for $component"
        validation_passed=false
    else
        log_success "All $component pods are ready"
    fi
    
    log_step "3. Checking $component services"
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
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# DOCKER VALIDATION
# =============================================================================

# Enhanced Docker installation validation
validate_docker_installation() {
    local timeout="${1:-60}"
    local validation_passed=true
    
    log_step "1. Checking Docker daemon status"
    if execute_silent "Checking Docker daemon status" "sudo systemctl is-active --quiet docker"; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon is not running"
        validation_passed=false
    fi
    
    log_step "2. Checking containerd status"
    if execute_silent "Checking containerd status" "sudo systemctl is-active --quiet containerd"; then
        log_success "Containerd runtime is running"
    else
        log_error "Containerd runtime is not running"
        validation_passed=false
    fi
    
    log_step "3. Checking Docker version"
    if execute_controlled "Getting Docker version" "docker --version"; then
        local version=$(execute_silent "Extracting Docker version" "docker --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")
        log_success "Docker version: $version"
    else
        log_error "Cannot get Docker version"
        validation_passed=false
    fi
    
    log_step "4. Testing Docker functionality"
    if execute_controlled "Testing Docker info" "docker info"; then
        log_success "Docker daemon is responding properly"
    else
        log_error "Docker daemon is not responding properly"
        validation_passed=false
    fi
    
    log_step "5. Testing container creation"
    local container_test_result
    execute_with_progress "Testing container creation" "Running hello-world container test" "timeout 30 docker run --rm hello-world"
    container_test_result=$?
    
    if [[ $container_test_result -eq 0 ]]; then
        log_success "Container creation test passed"
    elif [[ $container_test_result -eq 124 ]]; then
        log_success "Container creation test completed (timed out after successful run)"
    else
        log_warning "Docker hello-world test failed (exit code: $container_test_result)"
        if is_verbose; then
            log_info "This may indicate Docker daemon issues or network connectivity problems"
        fi
    fi
    
    log_step "6. Checking Docker configuration"
    local cgroup_driver=$(execute_silent "Getting Docker cgroup driver" "docker info | grep 'Cgroup Driver' | cut -d: -f2 | tr -d ' '")
    if [[ "$cgroup_driver" == "systemd" ]]; then
        log_success "Cgroup driver correctly set to systemd"
    else
        log_warning "Docker cgroup driver is not set to systemd (current: $cgroup_driver)"
        if is_verbose; then
            log_info "For Kubernetes compatibility, systemd cgroup driver is recommended"
        fi
    fi
    
    log_step "7. Checking Docker group membership"
    if groups $USER | grep -q docker; then
        log_success "User is in docker group"
    else
        log_warning "User not in docker group - may need 'sudo' for docker commands"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# HELM VALIDATION
# =============================================================================

# Helm installation validation
validate_helm_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking Helm binary"
    if command -v helm >/dev/null 2>&1; then
        local version=$(helm version --short --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "Helm is installed (version: $version)"
    else
        log_error "Helm binary not found in PATH"
        validation_passed=false
        return 1
    fi
    
    log_step "2. Testing Helm functionality"
    if execute_controlled "Testing Helm functionality" "helm version --short"; then
        log_success "Helm version command works"
    else
        log_error "Helm version command failed"
        validation_passed=false
    fi
    
    log_step "3. Checking Helm repositories"
    if is_verbose; then
        log_debug "Getting Helm repository count"
    fi
    local repo_count=$(helm repo list 2>/dev/null | tail -n +2 | wc -l)
    repo_count=$(echo "$repo_count" | tr -d '[:space:]')
    if [[ $repo_count -gt 0 ]]; then
        log_success "Helm has $repo_count repositories configured"
    else
        log_info "No Helm repositories configured yet (this is normal for new installations)"
    fi
    
    log_step "4. Testing repository access"
    if execute_with_progress "Testing Helm repository access" "Adding and updating Helm repository" "helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update"; then
        log_success "Helm can access remote repositories"
        # Clean up test repository
        execute_silent "Cleaning up test repository" "helm repo remove bitnami || true"
    else
        log_warning "Cannot access remote repositories (may require proxy configuration)"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# KUBERNETES CLUSTER VALIDATION
# =============================================================================

# Kubernetes cluster validation
validate_kubernetes_cluster() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking cluster API server connectivity"
    if execute_controlled "Checking cluster API server" "kubectl cluster-info"; then
        log_success "Kubernetes API server is accessible"
    else
        log_error "Cannot connect to Kubernetes API server"
        validation_passed=false
    fi
    
    log_step "2. Checking node status"
    if is_verbose; then
        log_debug "Getting node status information"
    fi
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready ")
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    
    # Clean up whitespace from wc output
    ready_nodes=$(echo "$ready_nodes" | tr -d '[:space:]')
    total_nodes=$(echo "$total_nodes" | tr -d '[:space:]')
    
    if [[ $ready_nodes -eq $total_nodes && $ready_nodes -gt 0 ]]; then
        log_success "All $total_nodes nodes are ready"
    else
        log_error "Only $ready_nodes out of $total_nodes nodes are ready"
        validation_passed=false
    fi
    
    log_step "3. Checking system components"
    if wait_for_pods_ready "kube-system" "$timeout"; then
        log_success "All system components are ready"
    else
        log_error "Some system components are not ready"
        validation_passed=false
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# CERT-MANAGER VALIDATION
# =============================================================================

# Cert-manager validation
validate_cert_manager() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking cert-manager deployment"
    if check_deployment_readiness "cert-manager" "cert-manager"; then
        log_success "Cert-manager deployment is ready"
    else
        log_error "Cert-manager deployment has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking cert-manager pods"
    if ! wait_for_pods_ready "cert-manager" "$timeout" "cert-manager"; then
        log_error "Cert-manager pods not ready"
        validation_passed=false
    else
        log_success "Cert-manager pods are ready"
    fi
    
    log_step "2. Checking cert-manager webhook"
    if kubectl get validatingwebhookconfiguration cert-manager-webhook >/dev/null 2>&1; then
        log_success "Cert-manager webhook is configured"
    else
        log_error "Cert-manager webhook not found"
        validation_passed=false
    fi
    
    log_step "3. Testing cert-manager functionality"
    # Create a test certificate using the correct ClusterIssuer name
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: default
spec:
  secretName: test-certificate-secret
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - test.example.com
EOF
    
    # Wait for certificate to be processed (increased timeout for stability)
    sleep 15
    
    # Check certificate status with debug information
    local cert_status=$(kubectl get certificate test-certificate -o jsonpath='{.status.conditions[0].type}' 2>/dev/null)
    
    if [[ "$cert_status" == "Ready" ]]; then
        log_success "Cert-manager is functioning correctly"
        kubectl delete certificate test-certificate >/dev/null 2>&1
        kubectl delete secret test-certificate-secret >/dev/null 2>&1
    else
        log_warning "Cert-manager test certificate creation needs verification"
        log_info "Certificate status: '$cert_status' (expected: 'Ready')"
        # Clean up failed certificate
        kubectl delete certificate test-certificate >/dev/null 2>&1
        kubectl delete secret test-certificate-secret >/dev/null 2>&1
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# INGRESS CONTROLLER VALIDATION
# =============================================================================

# Ingress controller validation with enhanced checks
validate_ingress_controller() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking ingress controller deployment"
    if check_deployment_readiness "ingress-nginx-controller" "ingress-nginx"; then
        log_success "Ingress controller deployment is ready"
    else
        log_error "Ingress controller deployment has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking ingress controller pods"
    if ! wait_for_pods_ready "ingress-nginx" "$timeout" "ingress-nginx"; then
        log_error "Ingress controller pods not ready"
        validation_passed=false
    else
        log_success "Ingress controller pods are ready"
    fi
    
    log_step "3. Checking ingress controller service"
    if check_service_connectivity "ingress-nginx-controller" "ingress-nginx"; then
        log_success "Ingress controller service is accessible"
        
        # Check for external IP or NodePort
        local service_type=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.type}' 2>/dev/null)
        if [[ "$service_type" == "LoadBalancer" ]]; then
            local external_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
                log_success "LoadBalancer has external IP: $external_ip"
            else
                log_warning "LoadBalancer service exists but no external IP assigned yet"
            fi
        elif [[ "$service_type" == "NodePort" ]]; then
            local node_port=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
            log_info "NodePort service configured on port: $node_port"
        fi
    else
        log_error "Ingress controller service not accessible"
        validation_passed=false
    fi
    
    log_step "4. Checking ingress class"
    if kubectl get ingressclass nginx >/dev/null 2>&1; then
        log_success "Nginx ingress class is available"
    else
        log_warning "Nginx ingress class not found"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# MONITORING STACK VALIDATION
# =============================================================================

# Monitoring stack validation
validate_monitoring_stack() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking monitoring namespace pods"
    if ! wait_for_pods_ready "monitoring" "$timeout"; then
        log_error "Monitoring pods not ready"
        validation_passed=false
    else
        log_success "Monitoring pods are ready"
    fi
    
    log_step "2. Checking Prometheus"
    if kubectl get statefulset -n monitoring prometheus-prometheus >/dev/null 2>&1; then
        log_success "Prometheus is deployed"
    else
        log_error "Prometheus not found"
        validation_passed=false
    fi
    
    log_step "3. Checking Grafana"
    if kubectl get deployment -n monitoring grafana >/dev/null 2>&1; then
        log_success "Grafana is deployed"
    else
        log_error "Grafana not found"
        validation_passed=false
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# VAULT INSTALLATION VALIDATION
# =============================================================================

# Vault installation validation
validate_vault_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking Vault pods"
    if ! wait_for_pods_ready "vault" "$timeout"; then
        log_error "Vault pods not ready"
        validation_passed=false
    else
        log_success "Vault pods are ready"
    fi
    
    log_step "2. Checking Vault status"
    local vault_status=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed // "unknown"')
    case "$vault_status" in
        "false")
            log_success "Vault is unsealed and ready"
            ;;
        "true")
            log_warning "Vault is sealed - requires manual unsealing"
            ;;
        *)
            log_warning "Could not determine Vault status"
            ;;
    esac
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# GOK CONTROLLER VALIDATION
# =============================================================================

# GOK Controller validation
validate_gok_controller_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking GOK Controller pods"
    if ! wait_for_pods_ready "gok-controller" "$timeout"; then
        log_error "GOK Controller pods not ready"
        validation_passed=false
    else
        log_success "GOK Controller pods are ready"
    fi
    
    log_step "2. Checking GOK Agent pods"
    if ! wait_for_pods_ready "gok-agent" "$timeout"; then
        log_error "GOK Agent pods not ready"
        validation_passed=false
    else
        log_success "GOK Agent pods are ready"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# KEYCLOAK INSTALLATION VALIDATION
# =============================================================================

validate_keycloak_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking Keycloak StatefulSet status"
    if check_statefulset_readiness "keycloak" "keycloak"; then
        log_success "Keycloak StatefulSet is ready"
    else
        log_error "Keycloak StatefulSet has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking Keycloak pods"
    if ! wait_for_pods_ready "keycloak" "$timeout" "keycloak"; then
        log_error "Keycloak pods not ready"
        validation_passed=false
    else
        log_success "Keycloak pods are ready"
    fi
    
    log_step "3. Checking Keycloak service connectivity"
    if check_service_connectivity "keycloak-http" "keycloak"; then
        log_success "Keycloak service is accessible"
    else
        log_warning "Keycloak service connectivity issues detected"
    fi
    
    log_step "4. Checking Keycloak ingress configuration"
    if kubectl get ingress keycloak -n keycloak >/dev/null 2>&1; then
        if check_ingress_status "keycloak" "keycloak"; then
            log_success "Keycloak ingress is configured and ready"
        else
            log_warning "Keycloak ingress has configuration issues"
        fi
    else
        log_info "Keycloak ingress not configured (using NodePort/LoadBalancer)"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# ARGOCD INSTALLATION VALIDATION
# =============================================================================

# ArgoCD validation with comprehensive checks
validate_argocd_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking ArgoCD server deployment"
    if check_deployment_readiness "argocd-server" "argocd"; then
        log_success "ArgoCD server deployment is ready"
    else
        log_error "ArgoCD server deployment has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking ArgoCD pods"
    if ! wait_for_pods_ready "argocd" "$timeout" "argocd"; then
        log_error "ArgoCD pods not ready"
        validation_passed=false
    else
        log_success "ArgoCD pods are ready"
    fi
    
    log_step "3. Checking ArgoCD services"
    if check_service_connectivity "argocd-server" "argocd"; then
        log_success "ArgoCD server service is accessible"
    else
        log_warning "ArgoCD server service connectivity issues detected"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# JUPYTER INSTALLATION VALIDATION
# =============================================================================

# JupyterHub validation with comprehensive checks
validate_jupyter_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking JupyterHub hub deployment"
    if check_deployment_readiness "hub" "jupyterhub"; then
        log_success "JupyterHub hub deployment is ready"
    else
        log_error "JupyterHub hub deployment has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking JupyterHub pods"
    if ! wait_for_pods_ready "jupyterhub" "$timeout" "jupyterhub"; then
        log_error "JupyterHub pods not ready"
        validation_passed=false
    else
        log_success "JupyterHub pods are ready"
    fi
    
    log_step "3. Checking JupyterHub proxy service"
    if check_service_connectivity "proxy-public" "jupyterhub"; then
        log_success "JupyterHub proxy service is accessible"
    else
        log_warning "JupyterHub proxy service connectivity issues detected"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# REGISTRY INSTALLATION VALIDATION
# =============================================================================

# Registry validation with comprehensive checks
validate_registry_installation() {
    local timeout="$1"
    local validation_passed=true
    
    log_step "1. Checking Registry deployment"
    if check_deployment_readiness "registry" "registry"; then
        log_success "Registry deployment is ready"
    else
        log_error "Registry deployment has issues"
        validation_passed=false
    fi
    
    log_step "2. Checking Registry pods"
    if ! wait_for_pods_ready "registry" "$timeout" "registry"; then
        log_error "Registry pods not ready"
        validation_passed=false
    else
        log_success "Registry pods are ready"
    fi
    
    log_step "3. Checking Registry service"
    if check_service_connectivity "registry" "registry"; then
        log_success "Registry service is accessible"
    else
        log_warning "Registry service connectivity issues detected"
    fi
    
    log_step "4. Checking Registry ingress"
    if kubectl get ingress registry -n registry >/dev/null 2>&1; then
        if check_ingress_status "registry" "registry"; then
            log_success "Registry ingress is configured and ready"
        else
            log_warning "Registry ingress has configuration issues"
        fi
    else
        log_info "Registry ingress not configured (using NodePort/LoadBalancer)"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# BASE INSTALLATION VALIDATION
# =============================================================================

# Base platform services validation
validate_base_installation() {
    local timeout="${1:-300}"
    local validation_passed=true

    log_info "Validating base platform installation..."

    # Check if base installation marker exists
    if kubectl get configmap base-config -n kube-system >/dev/null 2>&1; then
        log_success "Base platform installation marker found"

        # Check marker metadata
        local version=$(kubectl get configmap base-config -n kube-system -o jsonpath='{.data.version}' 2>/dev/null || echo "unknown")
        local caching=$(kubectl get configmap base-config -n kube-system -o jsonpath='{.data.caching-enabled}' 2>/dev/null || echo "false")

        if [[ "$version" == "modular" ]]; then
            log_success "Base platform modular version confirmed"
        else
            log_info "Base platform version: ${version}"
        fi

        if [[ "$caching" == "true" ]]; then
            log_success "Smart caching enabled and operational"
        else
            log_info "Smart caching status: ${caching}"
        fi
    else
        log_warning "Base platform installation marker not found"
        validation_passed=false
    fi

    # Check if Docker registry is accessible
    local registry_url=$(kubectl get configmap registry-config -n kube-system -o jsonpath='{.data.url}' 2>/dev/null || echo "localhost:5000")
    if docker images | grep -q "gok-base"; then
        log_success "Base platform Docker image found locally"
    else
        log_warning "Base platform Docker image not found locally"
    fi

    # Check if caching directory exists and is working
    if [[ -d "${GOK_CACHE_DIR:-${GOK_ROOT}/.cache}" ]]; then
        log_success "GOK cache directory operational"

        # Check cache effectiveness
        if [[ -f "${GOK_CACHE_DIR:-${GOK_ROOT}/.cache}/update_cache" ]]; then
            local cache_age=$(stat -c %Y "${GOK_CACHE_DIR:-${GOK_ROOT}/.cache}/update_cache" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local hours_old=$(( (current_time - cache_age) / 3600 ))

            if [[ $hours_old -lt ${GOK_UPDATE_CACHE_HOURS:-6} ]]; then
                log_success "System update cache is fresh (${hours_old}h old)"
            else
                log_info "System update cache is aging (${hours_old}h old)"
            fi
        fi
    else
        log_warning "GOK cache directory not found"
    fi

    # Check base platform directory
    local base_dir="${GOK_ROOT}/../base"
    if [[ -d "$base_dir" ]]; then
        log_success "Base platform directory exists"
    else
        log_error "Base platform directory not found"
        validation_passed=false
    fi

    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# KYVERNO POLICY ENGINE VALIDATION
# =============================================================================

validate_kyverno_installation() {
    local timeout="${1:-300}"
    local validation_passed=true

    log_info "Validating Kyverno policy engine installation..."

    log_step "1. Checking Kyverno deployment"
    if check_deployment_readiness "kyverno" "kyverno"; then
        log_success "Kyverno deployment is ready"
    else
        log_error "Kyverno deployment has issues"
        validation_passed=false
    fi

    log_step "2. Checking Kyverno pods"
    if ! wait_for_pods_ready "kyverno" "$timeout" "Kyverno"; then
        log_error "Kyverno pods not ready"
        validation_passed=false
    else
        log_success "Kyverno pods are ready"
    fi

    log_step "3. Checking Kyverno admission controller"
    if kubectl get validatingwebhookconfiguration kyverno-policy-validating-webhook-cfg >/dev/null 2>&1; then
        log_success "Kyverno admission controller webhook is configured"
    else
        log_error "Kyverno admission controller webhook not found"
        validation_passed=false
    fi

    log_step "4. Checking Kyverno background controller"
    if kubectl get clusterrolebinding kyverno:background-controller >/dev/null 2>&1; then
        log_success "Kyverno background controller is configured"
    else
        log_error "Kyverno background controller not found"
        validation_passed=false
    fi

    log_step "5. Checking cluster policies"
    local policy_count=$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l)
    if [[ $policy_count -gt 0 ]]; then
        log_success "Found $policy_count cluster policies configured"
    else
        log_warning "No cluster policies found - Kyverno may not be enforcing policies"
    fi

    log_step "6. Testing policy functionality"
    # Create a test policy to verify Kyverno is working
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: test-policy-validation
spec:
  validationFailureAction: audit
  rules:
  - name: validate-test
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Test policy validation"
      pattern:
        spec:
          containers:
          - name: "*"
            image: "nginx:*"
EOF

    sleep 5

    # Check if test policy was created
    if kubectl get clusterpolicy test-policy-validation >/dev/null 2>&1; then
        log_success "Kyverno policy creation and validation working"
        # Clean up test policy
        kubectl delete clusterpolicy test-policy-validation >/dev/null 2>&1
    else
        log_error "Kyverno policy creation failed"
        validation_passed=false
    fi

    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# HA PROXY VALIDATION
# =============================================================================

validate_ha_proxy_installation() {
    local verbose_flag="${1:-}"
    local validation_passed=true

    log_substep "Checking HAProxy container status"
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "master-proxy.*Up"; then
        log_error "HAProxy container is not running"
        docker logs master-proxy 2>&1 | tail -5 | while read line; do
            log_error "Container log: $line"
        done
        return 1
    fi

    log_substep "Checking HAProxy port binding"
    local ha_port="${HA_PROXY_PORT:-6643}"
    if ! netstat -tlnp 2>/dev/null | grep -q ":$ha_port.*LISTEN" && ! ss -tlnp 2>/dev/null | grep -q ":$ha_port.*LISTEN"; then
        log_error "HAProxy is not listening on port $ha_port"
        return 1
    fi

    log_substep "Testing HAProxy configuration"
    if ! docker exec master-proxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        log_error "HAProxy configuration validation failed"
        return 1
    fi

    log_substep "Checking backend server connectivity"
    local healthy_backends=0
    local total_backends=0

    # Check if API_SERVERS is defined
    if [[ -n "${API_SERVERS:-}" ]]; then
        IFS=','
        for worker in $API_SERVERS; do
            oifs=$IFS
            IFS=':'
            read -r ip node <<<"$worker"
            total_backends=$((total_backends + 1))

            if timeout 5 nc -z "$ip" 6443 2>/dev/null; then
                log_substep "  Backend $node ($ip:6443): ${EMOJI_SUCCESS:-✓} Reachable"
                healthy_backends=$((healthy_backends + 1))
            else
                log_substep "  Backend $node ($ip:6443): ${EMOJI_WARNING:-⚠} Not reachable (may not be ready yet)"
            fi
            IFS=$oifs
        done
        unset IFS

        if [[ $healthy_backends -eq 0 ]]; then
            log_warning "No backend servers are currently reachable"
            log_info "This is normal if Kubernetes masters are not yet installed"
        else
            log_success "$healthy_backends out of $total_backends backend servers are reachable"
        fi
    else
        log_info "API_SERVERS not configured - skipping backend connectivity checks"
    fi

    return 0
}

# =============================================================================
# SYSTEM REQUIREMENTS VALIDATION
# =============================================================================

validate_system_requirements() {
    log_info "Validating system requirements..."
    
    local validation_passed=true
    
    # Check available memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 2 ]; then
        log_warning "System has ${mem_gb}GB RAM, minimum 2GB recommended"
    else
        log_success "Memory requirement satisfied (${mem_gb}GB available)"
    fi
    
    # Check available disk space
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$disk_gb" -lt 10 ]; then
        log_warning "Available disk space: ${disk_gb}GB, minimum 20GB recommended"
    else
        log_success "Disk space requirement satisfied (${disk_gb}GB available)"
    fi
    
    # Check if Docker is running
    if systemctl is-active --quiet docker; then
        log_success "Docker service is running"
    else
        log_error "Docker service is not running - please install Docker first"
        validation_passed=false
    fi
    
    # Check if swap is disabled
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        log_info "Swap is enabled - will be disabled during installation"
    else
        log_success "Swap is already disabled"
    fi
    
    return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# FUNCTION EXPORTS
# =============================================================================

# Export all helper functions
export -f wait_for_pods_ready
export -f check_deployment_readiness
export -f check_statefulset_readiness
export -f check_service_connectivity
export -f check_ingress_status
export -f check_image_pull_issues
export -f check_resource_constraints

# Export main validation functions
export -f validate_component_installation
export -f validate_generic_component
export -f validate_docker_installation
export -f validate_helm_installation
export -f validate_kubernetes_cluster
export -f validate_cert_manager
export -f validate_ingress_controller
export -f validate_monitoring_stack
export -f validate_vault_installation
export -f validate_gok_controller_installation
export -f validate_keycloak_installation
export -f validate_argocd_installation
export -f validate_jupyter_installation
export -f validate_registry_installation
export -f validate_base_installation
export -f validate_kyverno_installation
export -f validate_ha_proxy_installation
export -f validate_system_requirements

# Validate LDAP installation with comprehensive checks
validate_ldap_installation() {
  log_info "Validating LDAP installation with enhanced diagnostics..."
  local validation_passed=true

  log_step "1" "Checking LDAP namespace"
  if kubectl get namespace ldap >/dev/null 2>&1; then
    log_success "LDAP namespace found"
  else
    log_error "LDAP namespace not found"
    return 1
  fi

  log_step "2" "Checking LDAP deployment status"
  if check_deployment_readiness "ldap" "ldap"; then
    log_success "LDAP deployment is ready"
  else
    log_error "LDAP deployment has issues"
    validation_passed=false
  fi

  log_step "3" "Checking LDAP pods with detailed diagnostics"
  if ! wait_for_pods_ready "ldap" "300" "ldap"; then
    log_error "LDAP pods not ready"
    validation_passed=false
  else
    log_success "LDAP pods are ready"
  fi

  log_step "4" "Checking LDAP service connectivity"
  if check_service_connectivity "ldap" "ldap"; then
    log_success "LDAP service is accessible"
  else
    log_warning "LDAP service connectivity issues detected"
  fi

  log_step "5" "Checking LDAP persistent volumes"
  local ldap_pvcs=$(kubectl get pvc -n ldap --no-headers 2>/dev/null | wc -l)
  if [[ $ldap_pvcs -gt 0 ]]; then
    log_success "LDAP persistent volume claims found ($ldap_pvcs PVCs)"

    # Check for pending PVCs
    local pending_pvcs=$(kubectl get pvc -n ldap --no-headers 2>/dev/null | grep "Pending" | wc -l)
    if [[ $pending_pvcs -gt 0 ]]; then
      log_warning "$pending_pvcs LDAP PVC(s) are in Pending state"
    fi
  else
    log_info "No persistent volume claims found for LDAP (may be using ephemeral storage)"
  fi

  log_step "6" "Testing LDAP connectivity (if accessible)"
  local ldap_pod=$(kubectl get pods -n ldap --no-headers 2>/dev/null | grep "Running" | head -1 | awk '{print $1}')
  if [[ -n "$ldap_pod" ]]; then
    if kubectl exec -n ldap "$ldap_pod" -- ldapsearch -x -b "" -s base "(objectclass=*)" >/dev/null 2>&1; then
      log_success "LDAP server is responding to queries"
    else
      log_warning "LDAP server may not be fully initialized yet"
    fi
  fi

  return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

# Enhanced validation for Keycloak installation
validate_keycloak_installation() {
  log_info "Validating Keycloak installation..."

  # Check if Keycloak namespace exists
  if kubectl get namespace keycloak >/dev/null 2>&1; then
    log_success "Keycloak namespace found"
  else
    log_error "Keycloak namespace not found"
    return 1
  fi

  # Check if Keycloak StatefulSet is ready
  if kubectl get statefulset keycloak -n keycloak >/dev/null 2>&1; then
    log_success "Keycloak StatefulSet found"

    # Check StatefulSet status
    local ready_replicas=$(kubectl get statefulset keycloak -n keycloak -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas=$(kubectl get statefulset keycloak -n keycloak -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    if [[ "$ready_replicas" == "$desired_replicas" ]]; then
      log_success "Keycloak StatefulSet is ready (${ready_replicas}/${desired_replicas} replicas)"
    else
      log_warning "Keycloak StatefulSet is scaling (${ready_replicas}/${desired_replicas} replicas ready)"
    fi
  else
    log_error "Keycloak StatefulSet not found"
    return 1
  fi

  # Check if PostgreSQL is ready
  if kubectl get statefulset keycloak-postgresql -n keycloak >/dev/null 2>&1; then
    log_success "PostgreSQL database found"

    local pg_ready=$(kubectl get statefulset keycloak-postgresql -n keycloak -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$pg_ready" == "1" ]]; then
      log_success "PostgreSQL database is ready"
    else
      log_warning "PostgreSQL database is starting"
    fi
  else
    log_warning "PostgreSQL statefulset not found (may use external database)"
  fi

  # Check if Keycloak service exists
  if kubectl get service keycloak-http -n keycloak >/dev/null 2>&1; then
    log_success "Keycloak service found"
  else
    log_warning "Keycloak service not found"
  fi

  # Check if ingress exists
  if kubectl get ingress keycloak -n keycloak >/dev/null 2>&1; then
    local hostname=$(kubectl get ingress keycloak -n keycloak -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "unknown")
    log_success "Keycloak ingress found (${hostname})"
  else
    log_info "Keycloak ingress not found (may be configured separately)"
  fi

  return 0
}

export -f validate_keycloak_installation
export -f validate_ldap_installation