#!/bin/bash

# GOK Reset Command Module - Component uninstallation and cleanup

# Main reset command handler
resetCmd() {
    local component="$1"
    
    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_reset_help
        return 1
    fi
    
    log_header "Component Reset" "Uninstalling: $component"
    
    # Confirmation prompt for destructive operations
    if ! confirm_reset "$component"; then
        log_info "Reset operation cancelled by user"
        return 0
    fi
    
    # Initialize component tracking
    init_component_tracking
    start_component "$component"
    
    # Dispatch to appropriate reset function
    case "$component" in
        # Infrastructure components
        "docker")
            dockrReset
            ;;
        "kubernetes")
            k8sReset
            ;;
        "helm")
            helmReset
            ;;
        "calico")
            calicoReset
            ;;
        "ingress")
            ingressReset
            ;;
        
        # Security components
        "cert-manager")
            certManagerReset
            ;;
        "keycloak")
            keycloakReset
            ;;
        "oauth2")
            oauth2Reset
            ;;
        "vault")
            vaultReset
            ;;
        "ldap")
            ldapReset
            ;;
        
        # Monitoring components
        "monitoring")
            monitoringReset
            ;;
        "prometheus")
            prometheusReset
            ;;
        "grafana")
            grafanaReset
            ;;
        "fluentd")
            fluentdReset
            ;;
        "opensearch")
            opensearchReset
            ;;
        
        # Development components
        "dashboard")
            dashboardReset
            ;;
        "jupyter")
            jupyterReset
            ;;
        "devworkspace")
            devworkspaceReset
            ;;
        "workspace")
            workspaceReset
            ;;
        "che")
            resetEclipseChe
            ;;
        "ttyd")
            ttydReset
            ;;
        "cloudshell")
            cloudshellReset
            ;;
        "console")
            consoleReset
            ;;
        
        # CI/CD components
        "argocd")
            argocdReset
            ;;
        "jenkins")
            jenkinsReset
            ;;
        "spinnaker")
            spinnakerReset
            ;;
        "registry")
            registryReset
            ;;
        
        # GOK Platform components
        "gok-agent")
            gokAgentReset
            ;;
        "gok-controller")
            gokControllerReset
            ;;
        "gok-login")
            gokLoginReset
            ;;
        "chart")
            chartReset
            ;;
        
        # Messaging and Policy
        "rabbitmq")
            rabbitmqReset
            ;;
        "kyverno")
            kyvernoReset
            ;;
        "istio")
            istioReset
            ;;
        
        # Solution bundles
        "base-services")
            resetBaseServices
            ;;
        
        *)
            log_error "Unknown component: $component"
            echo "Run 'gok reset help' to see available components"
            fail_component "$component" "Unknown component"
            return 1
            ;;
    esac
    
    local reset_result=$?
    
    # Post-reset handling
    if [[ $reset_result -eq 0 ]]; then
        complete_component "$component"
        post_reset_cleanup "$component"
        log_component_success "$component" "Reset completed successfully"
    else
        fail_component "$component" "Reset failed with exit code $reset_result"
        log_component_error "$component" "Reset operation failed"
        return $reset_result
    fi
}

# Show reset command help
show_reset_help() {
    echo "gok reset - Reset and uninstall Kubernetes components"
    echo ""
    echo "Usage: gok reset <component>"
    echo ""
    echo "WARNING: This operation will permanently remove the component and its data!"
    echo ""
    echo "Infrastructure:"
    echo "  docker, kubernetes, helm, calico, ingress"
    echo ""
    echo "Security:"
    echo "  cert-manager, keycloak, oauth2, vault, ldap"
    echo ""
    echo "Monitoring:"
    echo "  monitoring, prometheus, grafana, fluentd, opensearch"
    echo ""
    echo "Development:"
    echo "  dashboard, jupyter, devworkspace, workspace, che, ttyd, cloudshell, console"
    echo ""
    echo "CI/CD:"
    echo "  argocd, jenkins, spinnaker, registry"
    echo ""
    echo "GOK Platform:"
    echo "  gok-agent, gok-controller, gok-login, chart"
    echo ""
    echo "Other:"
    echo "  rabbitmq, kyverno, istio"
    echo ""
    echo "Solutions:"
    echo "  base-services"
    echo ""
    echo "Examples:"
    echo "  gok reset monitoring"
    echo "  gok reset keycloak"
}

# Confirm reset operation
confirm_reset() {
    local component="$1"
    
    echo
    log_warning "You are about to reset/uninstall: $component"
    echo
    echo "This will:"
    echo "  • Remove all $component resources from Kubernetes"
    echo "  • Delete persistent data and configurations"
    echo "  • Remove associated secrets and certificates"
    echo "  • Clean up related namespaces"
    echo
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    case "$REPLY" in
        "yes"|"YES"|"y"|"Y")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Post-reset cleanup
post_reset_cleanup() {
    local component="$1"
    
    log_info "Running post-reset cleanup for $component..."
    
    # Remove from installed components tracking
    local installed_file="${GOK_CACHE_DIR}/installed_components"
    if [[ -f "$installed_file" ]]; then
        grep -v "^${component}:" "$installed_file" > "${installed_file}.tmp" || true
        mv "${installed_file}.tmp" "$installed_file" 2>/dev/null || true
    fi
    
    # Component-specific cleanup
    case "$component" in
        "kubernetes")
            # Clean up Kubernetes-specific files and directories
            cleanup_kubernetes_files
            ;;
        "docker")
            # Clean up Docker-specific files
            cleanup_docker_files
            ;;
        "monitoring")
            # Remove monitoring data directories
            cleanup_monitoring_data
            ;;
    esac
    
    log_info "Post-reset cleanup completed for $component"
}

# Clean up Kubernetes files and directories
cleanup_kubernetes_files() {
    log_info "Cleaning up Kubernetes files..."
    
    local k8s_dirs=(
        "/etc/kubernetes"
        "/var/lib/kubelet"
        "/var/lib/etcd"
        "/var/lib/cni"
        "/etc/cni"
    )
    
    for dir in "${k8s_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_substep "Removing $dir"
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
    
    # Clean up systemd services
    local services=("kubelet" "kubeadm")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_substep "Stopping $service"
            systemctl stop "$service" 2>/dev/null || true
        fi
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            log_substep "Disabling $service"
            systemctl disable "$service" 2>/dev/null || true
        fi
    done
}

# Clean up Docker files
cleanup_docker_files() {
    log_info "Cleaning up Docker files..."
    
    # Stop and remove all containers
    if command -v docker >/dev/null 2>&1; then
        log_substep "Stopping and removing all containers"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        log_substep "Removing all images"
        docker rmi $(docker images -q) 2>/dev/null || true
        
        log_substep "Pruning Docker system"
        docker system prune -af 2>/dev/null || true
    fi
    
    # Remove Docker directories
    local docker_dirs=(
        "/var/lib/docker"
        "/etc/docker"
    )
    
    for dir in "${docker_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_substep "Removing $dir"
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
}

# Clean up monitoring data
cleanup_monitoring_data() {
    log_info "Cleaning up monitoring data..."
    
    local monitoring_dirs=(
        "/var/lib/prometheus"
        "/var/lib/grafana"
        "/var/log/prometheus"
        "/var/log/grafana"
    )
    
    for dir in "${monitoring_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_substep "Removing $dir"
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
}

# Generic Helm-based component reset
helm_component_reset() {
    local component="$1"
    local namespace="${2:-default}"
    local release_name="${3:-$component}"
    
    log_info "Resetting Helm component: $component"
    
    # Check if release exists
    if helm list -n "$namespace" -q | grep -q "^${release_name}$"; then
        log_substep "Uninstalling Helm release: $release_name"
        helm_uninstall_with_summary "$release_name" "$namespace" -n "$namespace"
    else
        log_info "Helm release $release_name not found in namespace $namespace"
    fi
    
    # Clean up namespace if it's component-specific
    if [[ "$namespace" != "default" && "$namespace" != "kube-system" ]]; then
        log_substep "Removing namespace: $namespace"
        kubectl delete namespace "$namespace" --ignore-not-found=true --timeout=60s 2>/dev/null || true
    fi
    
    # Clean up any persistent volumes
    cleanup_component_pvs "$component"
}

# Clean up persistent volumes for a component
cleanup_component_pvs() {
    local component="$1"
    
    log_substep "Cleaning up persistent volumes for $component"
    
    # Find PVs with component labels or names
    local pvs=$(kubectl get pv -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -i "$component" || true)
    
    for pv in $pvs; do
        if [[ -n "$pv" ]]; then
            log_substep "Removing persistent volume: $pv"
            kubectl delete pv "$pv" --ignore-not-found=true --timeout=30s 2>/dev/null || true
        fi
    done
}

# Component-specific reset functions (stubs for actual implementations)
dockrReset() { log_info "Resetting Docker..."; cleanup_docker_files; }
k8sReset() { log_info "Resetting Kubernetes..."; cleanup_kubernetes_files; }
helmReset() { log_info "Resetting Helm..."; helm reset --force 2>/dev/null || true; }
calicoReset() { helm_component_reset "calico" "kube-system"; }
ingressReset() { helm_component_reset "ingress-nginx" "ingress-nginx"; }
certManagerReset() { helm_component_reset "cert-manager" "cert-manager"; }
keycloakReset() { helm_component_reset "keycloak" "keycloak"; }
oauth2Reset() { helm_component_reset "oauth2-proxy" "oauth2-proxy"; }
vaultReset() { helm_component_reset "vault" "vault"; }
ldapReset() { helm_component_reset "openldap" "ldap"; }
monitoringReset() { prometheusReset; grafanaReset; }
prometheusReset() { helm_component_reset "prometheus" "monitoring"; }
grafanaReset() { helm_component_reset "grafana" "monitoring"; }
fluentdReset() { helm_component_reset "fluentd" "logging"; }
opensearchReset() { helm_component_reset "opensearch" "opensearch"; }
dashboardReset() { helm_component_reset "kubernetes-dashboard" "kubernetes-dashboard"; }
jupyterReset() { helm_component_reset "jupyterhub" "jupyterhub"; }
devworkspaceReset() { helm_component_reset "devworkspace" "devworkspace"; }
workspaceReset() { helm_component_reset "workspace" "workspace"; }
resetEclipseChe() { helm_component_reset "eclipse-che" "eclipse-che"; }
ttydReset() { helm_component_reset "ttyd" "ttyd"; }
cloudshellReset() { helm_component_reset "cloudshell" "cloudshell"; }
consoleReset() { helm_component_reset "console" "console"; }
argocdReset() { helm_component_reset "argocd" "argocd"; }
jenkinsReset() { helm_component_reset "jenkins" "jenkins"; }
spinnakerReset() { helm_component_reset "spinnaker" "spinnaker"; }
registryReset() { helm_component_reset "docker-registry" "registry"; }
gokAgentReset() { helm_component_reset "gok-agent" "gok-system"; }
gokControllerReset() { helm_component_reset "gok-controller" "gok-system"; }
gokLoginReset() { helm_component_reset "gok-login" "gok-login"; }
chartReset() { helm_component_reset "chartmuseum" "chartmuseum"; }
rabbitmqReset() { helm_component_reset "rabbitmq" "rabbitmq"; }
kyvernoReset() { helm_component_reset "kyverno" "kyverno"; }
istioReset() { 
    log_info "Resetting Istio..."
    istioctl uninstall --purge -y 2>/dev/null || true
    kubectl delete namespace istio-system --ignore-not-found=true --timeout=60s 2>/dev/null || true
}