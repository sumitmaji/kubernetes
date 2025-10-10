#!/bin/bash

# GOK Reset Command Module - Component uninstallation and cleanup

# Main reset command handler
resetCmd() {
    local component="$1"
    
    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_reset_help
        return 1
    fi
    
    # Parse verbose flags
    shift  # Remove component name
    local verbose_flag=""
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_flag="--verbose"
                export GOK_VERBOSE="true"
                log_info "Verbose logging enabled for reset operation"
                ;;
        esac
    done
    
    # Initialize verbosity for this reset operation
    if [[ -n "$verbose_flag" ]]; then
        set_verbosity_level "verbose"
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
    echo "Usage: gok reset <component> [--verbose|-v]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v      Show detailed cleanup output and system logs"
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
    local verbose_mode="$1"
    local is_verbose=false

    if [[ "$verbose_mode" == "--verbose" ]] || [[ "$GOK_VERBOSE" == "true" ]]; then
        is_verbose=true
    fi

    log_step 1 "Cleaning up Kubernetes configuration files"

    # Kubernetes config directories
    local k8s_dirs=(
        "/etc/kubernetes"
        "/var/lib/kubelet"
        "/var/lib/kube-proxy"
        "/var/lib/kube-scheduler"
        "/var/lib/kube-controller-manager"
        "/var/lib/etcd"
        "/opt/cni/bin"
        "/etc/cni/net.d"
        "/var/lib/cni"
        "/var/run/kubernetes"
        "/etc/systemd/system/kubelet.service.d"
    )

    # User kubeconfig files
    local user_configs=(
        "$HOME/.kube"
        "/root/.kube"
    )

    # Container runtime directories (enhanced)
    local container_dirs=(
        "/var/lib/docker/containers"
        "/var/lib/containerd"
        "/run/containerd"
        "/var/lib/dockershim"
        "/var/lib/cri-o"
        "/var/run/cri-o"
        "/var/lib/containers"
    )

    # Network configuration (enhanced)
    local network_files=(
        "/etc/cni/net.d/*"
        "/opt/cni/bin/*"
        "/var/lib/calico"
        "/var/lib/canal"
        "/var/lib/weave"
        "/var/lib/flannel"
        "/var/lib/kube-router"
        "/var/lib/cilium"
        "/etc/kubernetes/addons"
    )

    log_info "Stopping Kubernetes services..."

    # Stop services gracefully (enhanced list)
    local services=("kubelet" "kube-proxy" "kube-scheduler" "kube-controller-manager" "kube-apiserver" "etcd" "docker" "containerd" "cri-o" "flanneld" "calico-node" "cilium")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl_controlled "stop" "$service" "Stopping $service service"
        fi
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            systemctl_controlled "disable" "$service" "Disabling $service service"
        fi
    done

    # Remove Kubernetes directories
    log_info "Removing Kubernetes directories..."
    for dir in "${k8s_dirs[@]}"; do
        if [ -d "$dir" ]; then
            execute_controlled "Removing Kubernetes directory $dir" "rm -rf \"$dir\""
        fi
    done

    # Handle user kubeconfig files
    log_info "Cleaning up kubeconfig files..."
    for config in "${user_configs[@]}"; do
        if [ -d "$config" ]; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Backing up and removing: $config"
            fi
            # Create backup before removing
            if [ -f "$config/config" ]; then
                cp "$config/config" "$config/config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
                if [[ "$is_verbose" == "true" ]]; then
                    log_substep "Created backup: $config/config.backup.$(date +%Y%m%d_%H%M%S)"
                fi
            fi
            rm -rf "$config" 2>/dev/null || log_warning "Failed to remove $config"
        fi
    done

    # Clean network configurations
    log_info "Cleaning up network configurations..."
    for net_path in "${network_files[@]}"; do
        if ls $net_path 1> /dev/null 2>&1; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Removing network files: $net_path"
            fi
            rm -rf $net_path 2>/dev/null || log_warning "Failed to remove $net_path"
        fi
    done

    # Clean container runtime (always do full cleanup for kubernetes reset)
    log_info "Performing container runtime cleanup..."

        # Stop and remove all containers
        if command -v docker &> /dev/null; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Stopping and removing Docker containers"
            fi
            docker stop $(docker ps -aq) 2>/dev/null || true
            docker rm $(docker ps -aq) 2>/dev/null || true
            docker system prune -af 2>/dev/null || true
        fi

        # Clean containerd
        if command -v ctr &> /dev/null; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Cleaning containerd containers and images"
            fi
            ctr -n k8s.io containers rm $(ctr -n k8s.io containers list -q) 2>/dev/null || true
            ctr -n k8s.io images rm $(ctr -n k8s.io images list -q) 2>/dev/null || true
        fi

        # Clean CRI-O
        if command -v crictl &> /dev/null; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Cleaning CRI-O containers and images"
            fi
            crictl rm $(crictl ps -aq) 2>/dev/null || true
            crictl rmi $(crictl images -q) 2>/dev/null || true
        fi

        # Clean container directories
        for dir in "${container_dirs[@]}"; do
            if [ -d "$dir" ]; then
                if [[ "$is_verbose" == "true" ]]; then
                    log_substep "Cleaning container directory: $dir"
                fi
                find "$dir" -type f -name "*.pid" -delete 2>/dev/null || true
                find "$dir" -type f -name "*.lock" -delete 2>/dev/null || true
            fi
        done

    # Clean systemd files (enhanced)
    log_info "Cleaning up systemd service files..."
    local systemd_files=(
        "/etc/systemd/system/kubelet.service"
        "/etc/systemd/system/kubelet.service.d"
        "/etc/systemd/system/kube-proxy.service"
        "/etc/systemd/system/kube-scheduler.service"
        "/etc/systemd/system/kube-controller-manager.service"
        "/etc/systemd/system/kube-apiserver.service"
        "/etc/systemd/system/etcd.service"
        "/etc/systemd/system/calico-node.service"
        "/etc/systemd/system/flanneld.service"
        "/etc/systemd/system/cri-o.service"
        "/lib/systemd/system/kubelet.service"
        "/lib/systemd/system/kube-proxy.service"
        "/lib/systemd/system/etcd.service"
    )

    for file in "${systemd_files[@]}"; do
        if [ -e "$file" ]; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Removing systemd file: $file"
            fi
            rm -rf "$file" 2>/dev/null || log_warning "Failed to remove $file"
        fi
    done

    # Reload systemd daemon
    if [[ "$is_verbose" == "true" ]]; then
        log_substep "Reloading systemd daemon"
    fi
    systemctl daemon-reload 2>/dev/null || log_warning "Failed to reload systemd daemon"

    # Clean up iptables rules (optional)
    log_info "Cleaning up iptables rules..."
    iptables -F 2>/dev/null || log_warning "Failed to flush iptables rules"
    iptables -t nat -F 2>/dev/null || log_warning "Failed to flush NAT rules"
    iptables -t mangle -F 2>/dev/null || log_warning "Failed to flush mangle rules"

    # Clean up network interfaces
    log_info "Cleaning up network interfaces..."
    local interfaces
    interfaces=$(ip link show 2>/dev/null | grep -E "(cni|flannel|calico|weave|cilium|kube-router)" | awk -F: '{print $2}' | tr -d ' ' | grep -v '^$')

    if [[ -n "$interfaces" ]]; then
        while IFS= read -r iface; do
            if [[ -n "$iface" && "$iface" != "ee" ]]; then  # Skip invalid interface names
                if [[ "$is_verbose" == "true" ]]; then
                    log_substep "Removing network interface: $iface"
                fi
                ip link delete "$iface" 2>/dev/null || log_warning "Failed to remove interface $iface"
            fi
        done <<< "$interfaces"
    else
        if [[ "$is_verbose" == "true" ]]; then
            log_substep "No network interfaces to clean up"
        fi
    fi

    # Clean up certificates and secrets
    log_info "Cleaning up certificates and secrets..."
    local cert_files=(
        "/etc/kubernetes/pki"
        "/var/lib/kubernetes/pki"
        "/etc/ssl/certs/kubernetes"
    )

    for cert_dir in "${cert_files[@]}"; do
        if [ -d "$cert_dir" ]; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Removing certificate directory: $cert_dir"
            fi
            rm -rf "$cert_dir" 2>/dev/null || log_warning "Failed to remove certificates from $cert_dir"
        fi
    done

    # Clean up logs
    log_info "Cleaning up Kubernetes logs..."
    local log_files=(
        "/var/log/kubelet.log"
        "/var/log/kube-proxy.log"
        "/var/log/kube-apiserver.log"
        "/var/log/kube-scheduler.log"
        "/var/log/kube-controller-manager.log"
        "/var/log/etcd.log"
    )

    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            if [[ "$is_verbose" == "true" ]]; then
                log_substep "Removing log file: $log_file"
            fi
            rm -f "$log_file" 2>/dev/null || log_warning "Failed to remove log file $log_file"
        fi
    done

    log_success "Kubernetes file cleanup completed"
}

# Clean up Docker files
cleanup_docker_files() {
    log_info "Cleaning up Docker files..."
    
    # Stop Docker daemon first
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active --quiet docker; then
            systemctl_controlled "stop" "docker" "Stopping Docker daemon"
        fi
        
        execute_controlled "Stopping all Docker containers" "docker stop \$(docker ps -aq) 2>/dev/null || true"
        execute_controlled "Removing all Docker containers" "docker rm \$(docker ps -aq) 2>/dev/null || true"
        execute_controlled "Removing all Docker images" "docker rmi \$(docker images -q) 2>/dev/null || true"
        execute_controlled "Pruning Docker system" "docker system prune -af"
    fi
    
    # Remove Docker data subdirectories but preserve structure
    local docker_data_dirs=(
        "/var/lib/docker/containers"
        "/var/lib/docker/image"
        "/var/lib/docker/volumes"
        "/var/lib/docker/network"
        "/var/lib/docker/plugins"
        "/var/lib/docker/swarm"
        "/var/lib/docker/tmp"
    )
    
    for dir in "${docker_data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            execute_controlled "Removing Docker directory $dir" "rm -rf \"$dir\""
        fi
    done
    
    # Recreate essential directories
    log_verbose "Recreating essential Docker directories"
    execute_controlled "Creating Docker tmp directory" "mkdir -p /var/lib/docker/tmp"
    execute_controlled "Creating Docker containers directory" "mkdir -p /var/lib/docker/containers"
    execute_controlled "Creating Docker image directory" "mkdir -p /var/lib/docker/image"
    
    # Set proper permissions
    execute_controlled "Setting Docker directory ownership" "chown root:root /var/lib/docker"
    execute_controlled "Setting Docker directory permissions" "chmod 755 /var/lib/docker"
    execute_controlled "Setting Docker tmp permissions" "chmod 1777 /var/lib/docker/tmp"
    
    # Remove configuration directories
    local config_dirs=(
        "/etc/docker"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            execute_controlled "Removing Docker config directory $dir" "rm -rf \"$dir\""
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