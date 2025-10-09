#!/bin/bash
# =============================================================================
# GOK Modular Deployment Verification System
# =============================================================================
# Enhanced deployment verification with issue detection and troubleshooting
# 
# Usage:
#   source lib/utils/verification.sh
#   verify_component_deployment "monitoring"
#   check_image_pull_issues "monitoring" "prometheus"
#   check_resource_constraints "monitoring" "grafana"
#   diagnose_deployment_issues "argocd" "argocd-server"
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
# DEPLOYMENT VERIFICATION CONFIGURATION
# =============================================================================

# Common deployment issues and their patterns
declare -A COMMON_ISSUES
COMMON_ISSUES["ImagePullBackOff"]="Docker image pull failures"
COMMON_ISSUES["ErrImagePull"]="Docker image pull errors"
COMMON_ISSUES["CrashLoopBackOff"]="Container crash and restart loop"
COMMON_ISSUES["OutOfMemory"]="Memory resource exhaustion"
COMMON_ISSUES["OutOfCpu"]="CPU resource exhaustion" 
COMMON_ISSUES["Evicted"]="Pod eviction due to resource constraints"
COMMON_ISSUES["Pending"]="Pod scheduling issues"
COMMON_ISSUES["ContainerCreating"]="Container creation delays"
COMMON_ISSUES["Init:0/1"]="Init container failures"

# Resource thresholds for monitoring
declare -A RESOURCE_THRESHOLDS
RESOURCE_THRESHOLDS["memory_warning"]=80  # 80% memory usage
RESOURCE_THRESHOLDS["memory_critical"]=90 # 90% memory usage
RESOURCE_THRESHOLDS["cpu_warning"]=80     # 80% CPU usage
RESOURCE_THRESHOLDS["cpu_critical"]=90    # 90% CPU usage
RESOURCE_THRESHOLDS["disk_warning"]=80    # 80% disk usage
RESOURCE_THRESHOLDS["disk_critical"]=90   # 90% disk usage

# =============================================================================
# MAIN DEPLOYMENT VERIFICATION FUNCTIONS
# =============================================================================

# Comprehensive component deployment verification
verify_component_deployment() {
    local component="$1"
    local namespace="${2:-${COMPONENT_NAMESPACES[$component]:-$component}}"
    
    log_header "Deployment Verification" "Verifying $component deployment health"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔍 VERIFYING $component DEPLOYMENT${COLOR_RESET}"
    echo
    
    local verification_passed=true
    local issues_found=0
    
    # Step 1: Check for image pull issues
    log_step "1" "Checking for Docker image pull issues"
    if check_image_pull_issues "$namespace" "$component"; then
        log_success "No image pull issues found"
    else
        log_warning "Image pull issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Step 2: Check for resource constraints
    log_step "2" "Checking for resource constraint issues"
    if check_resource_constraints "$namespace" "$component"; then
        log_success "No resource constraint issues found"
    else
        log_warning "Resource constraint issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Step 3: Check for configuration issues
    log_step "3" "Checking for configuration issues"
    if check_configuration_issues "$namespace" "$component"; then
        log_success "No configuration issues found"
    else
        log_warning "Configuration issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Step 4: Check for networking issues
    log_step "4" "Checking for networking issues"
    if check_networking_issues "$namespace" "$component"; then
        log_success "No networking issues found"
    else
        log_warning "Networking issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Step 5: Check for persistent volume issues
    log_step "5" "Checking for storage issues"
    if check_storage_issues "$namespace" "$component"; then
        log_success "No storage issues found"
    else
        log_warning "Storage issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Step 6: Performance and health checks
    log_step "6" "Running performance health checks"
    if check_performance_health "$namespace" "$component"; then
        log_success "Performance health checks passed"
    else
        log_warning "Performance issues detected"
        verification_passed=false
        ((issues_found++))
    fi
    
    # Display verification summary
    display_verification_summary "$verification_passed" "$issues_found" "$component"
    
    # Provide detailed diagnostics if issues found
    if [[ "$issues_found" -gt 0 ]]; then
        echo
        diagnose_deployment_issues "$namespace" "$component"
    fi
    
    return $([[ "$verification_passed" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# SPECIFIC ISSUE DETECTION FUNCTIONS
# =============================================================================

# Check for Docker image pull issues in pods
check_image_pull_issues() {
    local namespace="$1"
    local component="$2"
    
    log_info "🐳 Checking for Docker image pull issues in $component..."
    
    # Get pods with image pull errors
    local image_pull_pods=""
    if kubectl get pods -n "$namespace" >/dev/null 2>&1; then
        image_pull_pods=$(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].state.waiting.reason}{"\n"}{end}' 2>/dev/null | grep -E "(ImagePullBackOff|ErrImagePull)" | cut -d' ' -f1)
    fi
    
    if [[ -n "$image_pull_pods" ]]; then
        log_error "Found pods with image pull issues:"
        echo "$image_pull_pods" | while read -r pod; do
            if [[ -n "$pod" ]]; then
                echo -e "${COLOR_RED}  ❌ Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                
                # Get detailed image pull error information
                local image_error=$(kubectl describe pod "$pod" -n "$namespace" 2>/dev/null | grep -A 3 -B 1 "Failed to pull image\|Error response from daemon")
                if [[ -n "$image_error" ]]; then
                    echo -e "${COLOR_YELLOW}     Error details:${COLOR_RESET}"
                    echo "$image_error" | sed 's/^/       /'
                fi
                
                # Get the image name causing issues
                local failed_image=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].image}' 2>/dev/null)
                if [[ -n "$failed_image" ]]; then
                    echo -e "${COLOR_CYAN}     Image: ${COLOR_BOLD}$failed_image${COLOR_RESET}"
                fi
                
                # Check image accessibility
                check_image_accessibility "$failed_image"
            fi
        done
        
        # Provide troubleshooting suggestions for image pull issues
        display_image_pull_troubleshooting
        return 1
    else
        return 0
    fi
}

# Check for resource constraint issues
check_resource_constraints() {
    local namespace="$1"
    local component="$2"
    
    log_info "📊 Checking for resource constraint issues in $component..."
    
    # Check for pods with resource-related issues
    local resource_issues=""
    if kubectl get pods -n "$namespace" >/dev/null 2>&1; then
        resource_issues=$(kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].state.waiting.reason}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep -E "(OutOfMemory|OutOfCpu|Evicted|OutOfDisk)")
    fi
    
    if [[ -n "$resource_issues" ]]; then
        log_warning "Found pods with resource constraint issues:"
        echo "$resource_issues" | while read -r line; do
            if [[ -n "$line" ]]; then
                local pod=$(echo "$line" | cut -d' ' -f1)
                echo -e "${COLOR_YELLOW}  ⚠️  Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                
                # Get resource usage and limits
                if kubectl top pod "$pod" -n "$namespace" >/dev/null 2>&1; then
                    kubectl top pod "$pod" -n "$namespace" 2>/dev/null | tail -n +2 | while read -r usage_line; do
                        echo -e "${COLOR_CYAN}     Resource usage: $usage_line${COLOR_RESET}"
                    done
                fi
                
                # Check resource requests and limits
                local resources=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].resources}' 2>/dev/null)
                if [[ -n "$resources" && "$resources" != "null" ]]; then
                    echo -e "${COLOR_CYAN}     Resource config: $resources${COLOR_RESET}"
                fi
            fi
        done
        
        # Display node resource status
        display_node_resource_status
        
        # Provide resource troubleshooting
        display_resource_troubleshooting
        return 1
    else
        return 0
    fi
}

# Check for configuration issues
check_configuration_issues() {
    local namespace="$1"
    local component="$2"
    
    log_info "⚙️ Checking for configuration issues in $component..."
    
    local config_issues_found=false
    
    # Check for pods in CrashLoopBackOff
    local crashing_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep "CrashLoopBackOff" | awk '{print $1}')
    if [[ -n "$crashing_pods" ]]; then
        log_warning "Found pods in CrashLoopBackOff:"
        echo "$crashing_pods" | while read -r pod; do
            if [[ -n "$pod" ]]; then
                echo -e "${COLOR_RED}  💥 Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                
                # Get recent logs to understand crash reason
                local crash_logs=$(kubectl logs "$pod" -n "$namespace" --tail=10 2>/dev/null)
                if [[ -n "$crash_logs" ]]; then
                    echo -e "${COLOR_YELLOW}     Recent logs:${COLOR_RESET}"
                    echo "$crash_logs" | sed 's/^/       /'
                fi
            fi
        done
        config_issues_found=true
    fi
    
    # Check for missing ConfigMaps or Secrets
    local missing_configs=$(check_missing_configurations "$namespace" "$component")
    if [[ -n "$missing_configs" ]]; then
        log_warning "Missing configuration resources:"
        echo "$missing_configs" | while read -r missing; do
            echo -e "${COLOR_YELLOW}  📄 $missing${COLOR_RESET}"
        done
        config_issues_found=true
    fi
    
    # Check for incorrect environment variables
    local env_issues=$(check_environment_variables "$namespace" "$component")
    if [[ -n "$env_issues" ]]; then
        log_warning "Environment variable issues detected:"
        echo "$env_issues"
        config_issues_found=true
    fi
    
    return $([[ "$config_issues_found" == "false" ]] && echo 0 || echo 1)
}

# Check for networking issues
check_networking_issues() {
    local namespace="$1"
    local component="$2"
    
    log_info "🌐 Checking for networking issues in $component..."
    
    local network_issues_found=false
    
    # Check for services without endpoints
    local services_without_endpoints=$(check_services_without_endpoints "$namespace")
    if [[ -n "$services_without_endpoints" ]]; then
        log_warning "Services without endpoints:"
        echo "$services_without_endpoints" | while read -r service; do
            echo -e "${COLOR_YELLOW}  🔌 Service: ${COLOR_BOLD}$service${COLOR_RESET}"
        done
        network_issues_found=true
    fi
    
    # Check for DNS issues
    if ! check_dns_resolution "$namespace"; then
        log_warning "DNS resolution issues detected"
        network_issues_found=true
    fi
    
    # Check for ingress issues
    local ingress_issues=$(check_ingress_issues "$namespace")
    if [[ -n "$ingress_issues" ]]; then
        log_warning "Ingress configuration issues:"
        echo "$ingress_issues"
        network_issues_found=true
    fi
    
    return $([[ "$network_issues_found" == "false" ]] && echo 0 || echo 1)
}

# Check for storage issues
check_storage_issues() {
    local namespace="$1"
    local component="$2"
    
    log_info "💾 Checking for storage issues in $component..."
    
    local storage_issues_found=false
    
    # Check for PVC binding issues
    local unbound_pvcs=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | grep "Pending" | awk '{print $1}')
    if [[ -n "$unbound_pvcs" ]]; then
        log_warning "Persistent Volume Claims not bound:"
        echo "$unbound_pvcs" | while read -r pvc; do
            if [[ -n "$pvc" ]]; then
                echo -e "${COLOR_YELLOW}  💿 PVC: ${COLOR_BOLD}$pvc${COLOR_RESET}"
                
                # Get PVC details
                local pvc_details=$(kubectl describe pvc "$pvc" -n "$namespace" 2>/dev/null | grep -A 5 "Events:")
                if [[ -n "$pvc_details" ]]; then
                    echo -e "${COLOR_CYAN}     Events:${COLOR_RESET}"
                    echo "$pvc_details" | sed 's/^/       /'
                fi
            fi
        done
        storage_issues_found=true
    fi
    
    # Check for storage capacity issues
    local storage_capacity=$(check_storage_capacity "$namespace")
    if [[ -n "$storage_capacity" ]]; then
        log_warning "Storage capacity issues:"
        echo "$storage_capacity"
        storage_issues_found=true
    fi
    
    return $([[ "$storage_issues_found" == "false" ]] && echo 0 || echo 1)
}

# Check performance health
check_performance_health() {
    local namespace="$1"
    local component="$2"
    
    log_info "⚡ Running performance health checks for $component..."
    
    local performance_issues_found=false
    
    # Check pod resource utilization if metrics server is available
    if kubectl top pods -n "$namespace" >/dev/null 2>&1; then
        local high_cpu_pods=$(kubectl top pods -n "$namespace" --no-headers 2>/dev/null | awk '{if($3 ~ /[0-9]+m/ && $3+0 > 1000) print $1}')
        if [[ -n "$high_cpu_pods" ]]; then
            log_warning "Pods with high CPU usage (>1000m):"
            echo "$high_cpu_pods" | while read -r pod; do
                echo -e "${COLOR_YELLOW}  📈 Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
            done
            performance_issues_found=true
        fi
        
        local high_mem_pods=$(kubectl top pods -n "$namespace" --no-headers 2>/dev/null | awk '{if($4 ~ /[0-9]+Mi/ && $4+0 > 1024) print $1}')
        if [[ -n "$high_mem_pods" ]]; then
            log_warning "Pods with high memory usage (>1Gi):"
            echo "$high_mem_pods" | while read -r pod; do
                echo -e "${COLOR_YELLOW}  📊 Pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
            done
            performance_issues_found=true
        fi
    else
        log_info "Metrics server not available - skipping resource usage checks"
    fi
    
    # Check for pods with many restarts
    local high_restart_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{if($4+0 > 5) print $1 " (" $4 " restarts)"}')
    if [[ -n "$high_restart_pods" ]]; then
        log_warning "Pods with high restart count (>5):"
        echo "$high_restart_pods" | while read -r pod_info; do
            echo -e "${COLOR_YELLOW}  🔄 $pod_info${COLOR_RESET}"
        done
        performance_issues_found=true
    fi
    
    return $([[ "$performance_issues_found" == "false" ]] && echo 0 || echo 1)
}

# =============================================================================
# HELPER FUNCTIONS FOR SPECIFIC CHECKS
# =============================================================================

# Check image accessibility
check_image_accessibility() {
    local image="$1"
    
    if [[ -n "$image" ]]; then
        echo -e "${COLOR_CYAN}     Testing image access...${COLOR_RESET}"
        
        # Try to inspect the image (this will pull if not available)
        if docker manifest inspect "$image" >/dev/null 2>&1; then
            echo -e "${COLOR_GREEN}       ✓ Image is accessible${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}       ❌ Image is not accessible${COLOR_RESET}"
            
            # Check if it's a registry connectivity issue
            local registry=$(echo "$image" | cut -d'/' -f1)
            if [[ "$registry" == *"."* ]]; then
                echo -e "${COLOR_CYAN}       Testing registry connectivity to $registry...${COLOR_RESET}"
                if curl -s --connect-timeout 5 "https://$registry" >/dev/null 2>&1; then
                    echo -e "${COLOR_GREEN}       ✓ Registry is accessible${COLOR_RESET}"
                else
                    echo -e "${COLOR_RED}       ❌ Registry is not accessible${COLOR_RESET}"
                fi
            fi
        fi
    fi
}

# Check for missing configurations
check_missing_configurations() {
    local namespace="$1"
    local component="$2"
    
    local missing_configs=""
    
    # Get all pods and check for referenced ConfigMaps and Secrets
    local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [[ -n "$pods" ]]; then
        echo "$pods" | while read -r pod; do
            # Check ConfigMap references
            local configmaps=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.volumes[*].configMap.name}' 2>/dev/null)
            if [[ -n "$configmaps" ]]; then
                for cm in $configmaps; do
                    if [[ "$cm" != "null" ]] && ! kubectl get configmap "$cm" -n "$namespace" >/dev/null 2>&1; then
                        echo "ConfigMap: $cm (referenced by $pod)"
                    fi
                done
            fi
            
            # Check Secret references
            local secrets=$(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.volumes[*].secret.secretName}' 2>/dev/null)
            if [[ -n "$secrets" ]]; then
                for secret in $secrets; do
                    if [[ "$secret" != "null" ]] && ! kubectl get secret "$secret" -n "$namespace" >/dev/null 2>&1; then
                        echo "Secret: $secret (referenced by $pod)"
                    fi
                done
            fi
        done
    fi
}

# Check environment variables
check_environment_variables() {
    local namespace="$1"
    local component="$2"
    
    # This is a placeholder for more sophisticated environment variable checking
    # In a real implementation, you might check for:
    # - Required environment variables that are missing
    # - Environment variables with invalid values
    # - Secrets that don't exist for environment variable references
    
    local env_issues=""
    
    # Check for pods with env var issues (simplified check)
    local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -E "(Init:0/1|ContainerCreating)" | awk '{print $1}')
    
    if [[ -n "$pods" ]]; then
        echo "$pods" | while read -r pod; do
            local events=$(kubectl describe pod "$pod" -n "$namespace" 2>/dev/null | grep -i "environment\|env\|variable")
            if [[ -n "$events" ]]; then
                echo "Pod $pod: Environment variable issues detected"
            fi
        done
    fi
}

# Check services without endpoints
check_services_without_endpoints() {
    local namespace="$1"
    
    local services=$(kubectl get svc -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [[ -n "$services" ]]; then
        echo "$services" | while read -r service; do
            if [[ -n "$service" ]]; then
                local endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
                if [[ -z "$endpoints" ]]; then
                    echo "$service"
                fi
            fi
        done
    fi
}

# Check DNS resolution
check_dns_resolution() {
    local namespace="$1"
    
    # Create a temporary pod to test DNS resolution
    local test_pod_name="dns-test-$(date +%s)"
    
    if kubectl run "$test_pod_name" --image=busybox --restart=Never --rm -i --tty --timeout=30s -n "$namespace" -- nslookup kubernetes.default >/dev/null 2>&1; then
        return 0
    else
        # Cleanup in case the pod wasn't removed
        kubectl delete pod "$test_pod_name" -n "$namespace" >/dev/null 2>&1 || true
        return 1
    fi
}

# Check ingress issues
check_ingress_issues() {
    local namespace="$1"
    
    local ingress_issues=""
    
    local ingresses=$(kubectl get ingress -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}')
    
    if [[ -n "$ingresses" ]]; then
        echo "$ingresses" | while read -r ingress; do
            if [[ -n "$ingress" ]]; then
                local ingress_ip=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
                if [[ -z "$ingress_ip" || "$ingress_ip" == "null" ]]; then
                    echo "Ingress $ingress: No load balancer IP assigned"
                fi
            fi
        done
    fi
}

# Check storage capacity
check_storage_capacity() {
    local namespace="$1"
    
    # Check for PVs that are near capacity (if metrics are available)
    local capacity_issues=""
    
    # This would require a more sophisticated implementation to check actual storage usage
    # For now, we'll check for obvious capacity issues from events
    local storage_events=$(kubectl get events -n "$namespace" --field-selector type=Warning 2>/dev/null | grep -i "storage\|volume\|capacity")
    
    if [[ -n "$storage_events" ]]; then
        echo "$storage_events"
    fi
}

# Display node resource status
display_node_resource_status() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📈 NODE RESOURCE STATUS:${COLOR_RESET}"
    
    if kubectl top nodes >/dev/null 2>&1; then
        kubectl top nodes 2>/dev/null | while read -r line; do
            echo -e "${COLOR_CYAN}   $line${COLOR_RESET}"
        done
    else
        echo -e "${COLOR_YELLOW}   Metrics server not available${COLOR_RESET}"
    fi
    
    # Show allocatable resources
    echo -e "${COLOR_CYAN}   Allocatable Resources:${COLOR_RESET}"
    kubectl describe nodes 2>/dev/null | grep -A 5 "Allocatable:" | head -10 | while read -r line; do
        echo -e "${COLOR_CYAN}     $line${COLOR_RESET}"
    done
}

# =============================================================================
# TROUBLESHOOTING GUIDES
# =============================================================================

# Display image pull troubleshooting
display_image_pull_troubleshooting() {
    echo
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🛠️  IMAGE PULL TROUBLESHOOTING:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check Docker registry connectivity: ${COLOR_BOLD}docker pull <image>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Verify image exists in registry: ${COLOR_BOLD}curl -s <registry-url>/v2/<image>/tags/list${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check image pull secrets: ${COLOR_BOLD}kubectl get secrets -n <namespace>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Verify network/proxy settings for image registry access${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check if image tag exists: ${COLOR_BOLD}docker manifest inspect <image:tag>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Fix repository issues: ${COLOR_BOLD}gok-new fix repositories${COLOR_RESET}"
}

# Display resource troubleshooting
display_resource_troubleshooting() {
    echo
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🛠️  RESOURCE TROUBLESHOOTING:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check node capacity: ${COLOR_BOLD}kubectl describe nodes${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Review resource requests/limits: ${COLOR_BOLD}kubectl describe pod <pod-name>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Monitor resource usage: ${COLOR_BOLD}kubectl top nodes && kubectl top pods${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Scale down resource-intensive pods if needed${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Consider adding more nodes to cluster${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Adjust resource requests and limits appropriately${COLOR_RESET}"
}

# =============================================================================
# COMPREHENSIVE ISSUE DIAGNOSIS
# =============================================================================

# Diagnose deployment issues with detailed analysis
diagnose_deployment_issues() {
    local namespace="$1"
    local component="$2"
    
    log_header "Issue Diagnosis" "Detailed analysis for $component in $namespace"
    
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔍 DETAILED ISSUE ANALYSIS${COLOR_RESET}"
    echo
    
    # Get all pods and analyze each one
    local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{print $1 " " $3}')
    
    if [[ -n "$pods" ]]; then
        echo "$pods" | while read -r pod_line; do
            local pod=$(echo "$pod_line" | awk '{print $1}')
            local status=$(echo "$pod_line" | awk '{print $2}')
            
            if [[ "$status" != "Running" && "$status" != "Completed" ]]; then
                echo -e "${COLOR_RED}🚨 Analyzing problematic pod: ${COLOR_BOLD}$pod${COLOR_RESET}"
                echo -e "${COLOR_RED}   Status: $status${COLOR_RESET}"
                
                # Get detailed pod information
                echo -e "${COLOR_CYAN}📋 Pod Details:${COLOR_RESET}"
                kubectl describe pod "$pod" -n "$namespace" 2>/dev/null | grep -A 10 "Conditions:\|Events:" | sed 's/^/   /'
                
                # Get recent logs if available
                echo -e "${COLOR_CYAN}📄 Recent Logs:${COLOR_RESET}"
                local logs=$(kubectl logs "$pod" -n "$namespace" --tail=5 2>/dev/null)
                if [[ -n "$logs" ]]; then
                    echo "$logs" | sed 's/^/   /'
                else
                    echo "   No logs available"
                fi
                
                echo
            fi
        done
    fi
    
    # Provide component-specific troubleshooting
    provide_component_specific_troubleshooting "$namespace" "$component"
}

# Provide component-specific troubleshooting
provide_component_specific_troubleshooting() {
    local namespace="$1"
    local component="$2"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🎯 $component-SPECIFIC TROUBLESHOOTING:${COLOR_RESET}"
    
    case "$component" in
        "cert-manager")
            echo -e "${COLOR_CYAN}• Check cert-manager logs: ${COLOR_BOLD}kubectl logs -n cert-manager -l app=cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Verify webhook: ${COLOR_BOLD}kubectl get validatingwebhookconfiguration${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Check certificates: ${COLOR_BOLD}kubectl get certificates -A${COLOR_RESET}"
            ;;
        "ingress")
            echo -e "${COLOR_CYAN}• Check ingress controller logs: ${COLOR_BOLD}kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Verify ingress class: ${COLOR_BOLD}kubectl get ingressclass${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Check service type: ${COLOR_BOLD}kubectl get svc -n ingress-nginx${COLOR_RESET}"
            ;;
        "monitoring")
            echo -e "${COLOR_CYAN}• Check Prometheus: ${COLOR_BOLD}kubectl logs -n monitoring -l app=prometheus${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Check Grafana: ${COLOR_BOLD}kubectl logs -n monitoring -l app.kubernetes.io/name=grafana${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Verify monitoring services: ${COLOR_BOLD}kubectl get svc -n monitoring${COLOR_RESET}"
            ;;
        "vault")
            echo -e "${COLOR_CYAN}• Check Vault status: ${COLOR_BOLD}kubectl exec -n vault vault-0 -- vault status${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Initialize Vault if needed: ${COLOR_BOLD}kubectl exec -n vault vault-0 -- vault operator init${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Unseal Vault: ${COLOR_BOLD}kubectl exec -n vault vault-0 -- vault operator unseal${COLOR_RESET}"
            ;;
        "keycloak")
            echo -e "${COLOR_CYAN}• Check Keycloak logs: ${COLOR_BOLD}kubectl logs -n keycloak -l app=keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Verify database connection: ${COLOR_BOLD}kubectl get pods -n keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Check ingress: ${COLOR_BOLD}kubectl get ingress -n keycloak${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_CYAN}• Check deployment: ${COLOR_BOLD}kubectl describe deployment -n $namespace${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Verify services: ${COLOR_BOLD}kubectl get svc -n $namespace${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Check configmaps/secrets: ${COLOR_BOLD}kubectl get cm,secrets -n $namespace${COLOR_RESET}"
            ;;
    esac
    
    echo -e "${COLOR_CYAN}• General troubleshooting: ${COLOR_BOLD}kubectl describe pods -n $namespace${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check events: ${COLOR_BOLD}kubectl get events -n $namespace --sort-by='.lastTimestamp'${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Run validation: ${COLOR_BOLD}gok-new validate $component${COLOR_RESET}"
}

# =============================================================================
# VERIFICATION SUMMARY
# =============================================================================

# Display verification summary
display_verification_summary() {
    local verification_passed="$1"
    local issues_found="$2"
    local component="$3"
    
    echo
    if [[ "$verification_passed" == "true" ]]; then
        echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✅ $component DEPLOYMENT VERIFICATION PASSED${COLOR_RESET}"
        echo -e "${COLOR_GREEN}All deployment health checks completed successfully${COLOR_RESET}"
        echo -e "${COLOR_GREEN}Component is ready for production use${COLOR_RESET}"
    else
        echo -e "${COLOR_BRIGHT_RED}${COLOR_BOLD}❌ $component DEPLOYMENT VERIFICATION FAILED${COLOR_RESET}"
        echo -e "${COLOR_RED}Found $issues_found issue(s) that need attention${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}Review the detailed analysis above for resolution steps${COLOR_RESET}"
        
        echo
        echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔧 NEXT STEPS:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}1. Address the identified issues using troubleshooting guidance${COLOR_RESET}"
        echo -e "${COLOR_CYAN}2. Re-run verification: ${COLOR_BOLD}gok-new verify $component${COLOR_RESET}"
        echo -e "${COLOR_CYAN}3. Check component logs for additional details${COLOR_RESET}"
        echo -e "${COLOR_CYAN}4. Contact support if issues persist${COLOR_RESET}"
    fi
    echo
}

# Export functions for use by other modules
export -f verify_component_deployment
export -f check_image_pull_issues
export -f check_resource_constraints
export -f check_configuration_issues
export -f check_networking_issues
export -f check_storage_issues
export -f diagnose_deployment_issues