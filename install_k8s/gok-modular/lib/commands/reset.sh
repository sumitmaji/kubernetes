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
    start_component "$component" "Starting reset operation for $component"
    
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
        "haproxy"|"ha-proxy"|"ha")
            haproxyReset
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
        complete_component "$component" "Reset completed successfully"
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
    echo "  docker, haproxy, kubernetes, helm, calico, ingress"
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
    case "$component" in
        "docker")
            echo "This will:"
            echo "  • Stop and disable Docker services"
            echo "  • Remove all Docker containers and images"
            echo "  • Uninstall Docker packages completely"
            echo "  • Delete Docker data directories (/var/lib/docker, /etc/docker)"
            echo "  • Clean up Docker network namespaces and mount points"
            echo "  • Remove Docker user groups and repository configuration"
            ;;
        *)
            echo "This will:"
            echo "  • Remove all $component resources from Kubernetes"
            echo "  • Delete persistent data and configurations"
            echo "  • Remove associated secrets and certificates"
            echo "  • Clean up related namespaces"
            ;;
    esac
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
            
            # Create temporary crictl config to suppress warnings
            local crictl_config_created=false
            if [[ ! -f /etc/crictl.yaml ]]; then
                sudo tee /etc/crictl.yaml > /dev/null <<EOF
runtime-endpoint: unix:///run/crio/crio.sock
image-endpoint: unix:///run/crio/crio.sock
timeout: 10
debug: false
EOF
                crictl_config_created=true
            fi
            
            crictl rm $(crictl ps -aq) 2>/dev/null || true
            crictl rmi $(crictl images -q) 2>/dev/null || true
            
            # Clean up temporary config if we created it
            if [[ "$crictl_config_created" == "true" ]]; then
                sudo rm -f /etc/crictl.yaml
            fi
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

# Remove Kubernetes packages during reset
remove_kubernetes_packages() {
    local verbose_flag="${1:-}"

    log_substep "Removing Kubernetes packages (kubeadm, kubectl, kubelet)"

    # List of Kubernetes packages to remove
    local k8s_packages=("kubeadm" "kubectl" "kubelet" "kubernetes-cni" "cri-tools")

    # Check if any packages are actually installed
    local installed_packages=()
    for package in "${k8s_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package" 2>/dev/null; then
            installed_packages+=("$package")
        fi
    done

    # If no packages are installed, exit gracefully
    if [[ ${#installed_packages[@]} -eq 0 ]]; then
        log_info "No Kubernetes packages found to remove."
        return 0
    fi

    if is_verbose_mode "$verbose_flag"; then
        log_info "Verbose mode: Showing detailed package removal output"

        # Check which packages are installed first
        log_info "Checking installed Kubernetes packages..."
        for package in "${k8s_packages[@]}"; do
            if dpkg -l | grep -q "^ii.*$package" 2>/dev/null; then
                echo -e "${COLOR_DIM}  • $package: installed${COLOR_RESET}"
            else
                echo -e "${COLOR_DIM}  • $package: not installed${COLOR_RESET}"
            fi
        done

        # Remove only installed packages with verbose output
        log_info "Removing installed Kubernetes packages..."
        if [[ ${#installed_packages[@]} -gt 0 ]]; then
            sudo apt-get remove --purge -y "${installed_packages[@]}" 2>&1 | while read line; do
                echo -e "${COLOR_DIM}  $line${COLOR_RESET}"
            done
        else
            echo -e "${COLOR_DIM}  No packages to remove${COLOR_RESET}"
        fi

        # Clean up package cache
        log_info "Cleaning up package cache..."
        sudo apt-get autoremove -y 2>&1 | while read line; do
            echo -e "${COLOR_DIM}  $line${COLOR_RESET}"
        done

        sudo apt-get autoclean 2>&1 | while read line; do
            echo -e "${COLOR_DIM}  $line${COLOR_RESET}"
        done

    else
        # Silent removal with progress indication - only remove installed packages
        {
            if [[ ${#installed_packages[@]} -gt 0 ]]; then
                sudo apt-get remove --purge -y "${installed_packages[@]}" >/dev/null 2>&1
            fi
            sudo apt-get autoremove -y >/dev/null 2>&1
            sudo apt-get autoclean >/dev/null 2>&1
        } &

        local pid=$!
        local dots=""
        while kill -0 $pid 2>/dev/null; do
            printf "\r    Removing Kubernetes packages${dots}"
            dots="${dots}."
            if [[ ${#dots} -gt 3 ]]; then dots=""; fi
            sleep 0.5
        done

        wait $pid
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            printf "\r    ✓ Kubernetes packages removed successfully\n"
        else
            printf "\r    ⚠ Package removal completed with warnings\n"
            log_warning "Some packages may not have been removed completely"
        fi
    fi

    # Remove Kubernetes repository configuration
    log_substep "Removing Kubernetes repository configuration"

    if is_verbose_mode "$verbose_flag"; then
        log_info "Removing repository files..."
        if [[ -f /etc/apt/sources.list.d/kubernetes.list ]]; then
            echo -e "${COLOR_DIM}  • Removing /etc/apt/sources.list.d/kubernetes.list${COLOR_RESET}"
            sudo rm -f /etc/apt/sources.list.d/kubernetes.list
        fi

        if [[ -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
            echo -e "${COLOR_DIM}  • Removing /etc/apt/keyrings/kubernetes-apt-keyring.gpg${COLOR_RESET}"
            sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        fi

        log_info "Updating package lists..."
        sudo apt-get update 2>&1 | while read line; do
            echo -e "${COLOR_DIM}  $line${COLOR_RESET}"
        done
    else
        sudo rm -f /etc/apt/sources.list.d/kubernetes.list
        sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        sudo apt-get update >/dev/null 2>&1
        log_success "Repository configuration removed"
    fi

}

# Helper function to safely remove directories with mounted content
safe_remove_docker_dir() {
    local dir="$1"
    local description="$2"
    
    if [[ ! -d "$dir" ]]; then
        log_verbose "Directory $dir does not exist, skipping"
        return 0
    fi
    
    log_verbose "Attempting safe removal of directory: $dir"
    
    # Check if anything is mounted within this directory
    local mounted_paths=$(mount | grep " $dir" | awk '{print $3}' || true)
    
    if [[ -n "$mounted_paths" ]]; then
        log_verbose "Found mounted paths in $dir, attempting to unmount"
        echo "$mounted_paths" | while IFS= read -r mount_path; do
            if [[ -n "$mount_path" ]]; then
                log_verbose "Unmounting: $mount_path"
                umount "$mount_path" 2>/dev/null || umount -l "$mount_path" 2>/dev/null || true
            fi
        done
    fi
    
    # Try normal removal first
    if rm -rf "$dir" 2>/dev/null; then
        log_verbose "Successfully removed $dir"
        return 0
    fi
    
    # If that failed, try more aggressive cleanup
    log_verbose "Standard removal failed for $dir, trying forced cleanup"
    
    # Kill any processes using files in this directory
    if command -v lsof >/dev/null 2>&1; then
        local pids=$(lsof +D "$dir" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u || true)
        if [[ -n "$pids" ]]; then
            log_verbose "Killing processes using $dir: $pids"
            echo "$pids" | xargs -r kill -TERM 2>/dev/null || true
            sleep 2
            echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # Check for network namespaces specifically in /run/docker/netns
    if [[ "$dir" == "/run/docker" && -d "$dir/netns" ]]; then
        log_verbose "Cleaning up Docker network namespaces"
        for netns_file in "$dir/netns"/*; do
            if [[ -f "$netns_file" ]]; then
                log_verbose "Unmounting netns: $netns_file"
                umount "$netns_file" 2>/dev/null || true
            fi
        done
    fi
    
    # Try lazy unmount for the entire directory
    umount -l "$dir" 2>/dev/null || true
    
    # Final removal attempt
    if rm -rf "$dir" 2>/dev/null; then
        log_verbose "Successfully removed $dir after cleanup"
        return 0
    else
        log_warning "Could not completely remove $dir - some files may remain (this is often normal for runtime directories)"
        # Try to remove contents but leave directory structure
        find "$dir" -mindepth 1 -delete 2>/dev/null || true
        return 0  # Don't fail the whole operation for runtime directories
    fi
}

# Clean up Docker files and uninstall Docker packages
cleanup_docker_files() {
    log_info "Cleaning up Docker installation and data..."
    
    # Step 1: Stop Docker services
    log_step "1 Stopping Docker services"
    local docker_services=("docker" "docker.socket" "containerd")
    
    for service in "${docker_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl_controlled "stop" "$service" "Stopping $service service"
        fi
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            systemctl_controlled "disable" "$service" "Disabling $service service"
        fi
    done
    
    # Step 2: Clean up Docker containers and images (if Docker is still available)
    log_step "2 Cleaning up Docker containers and images"
    if command -v docker >/dev/null 2>&1; then
        execute_controlled "Stopping all Docker containers" "docker stop \$(docker ps -aq) 2>/dev/null || true"
        execute_controlled "Removing all Docker containers" "docker rm \$(docker ps -aq) 2>/dev/null || true"
        execute_controlled "Removing all Docker images" "docker rmi \$(docker images -q) 2>/dev/null || true"
        execute_controlled "Pruning Docker system" "docker system prune -af 2>/dev/null || true"
    fi
    
    # Step 3: Uninstall Docker packages
    log_step "3 Uninstalling Docker packages"
    local docker_packages=(
        "docker-ce"
        "docker-ce-cli"
        "docker-buildx-plugin"
        "docker-compose-plugin"
        "containerd.io"
        "docker.io"
        "docker-doc"
        "docker-compose"
        "podman-docker"
        "containerd"
        "runc"
    )
    
    # Remove packages that are installed
    local packages_to_remove=""
    for package in "${docker_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package "; then
            packages_to_remove="$packages_to_remove $package"
        fi
    done
    
    if [[ -n "$packages_to_remove" ]]; then
        log_verbose "Packages to remove:$packages_to_remove"
        if apt_remove_controlled $packages_to_remove; then
            log_success "Docker packages removed successfully"
        else
            log_warning "Some Docker packages may not have been removed completely"
        fi
    else
        log_info "No Docker packages found to remove"
    fi
    
    # Step 4: Remove Docker APT repository and keys
    log_step "4 Removing Docker repository and GPG keys"
    execute_controlled "Removing Docker APT repository" "rm -f /etc/apt/sources.list.d/docker.list"
    execute_controlled "Removing Docker GPG key" "rm -f /etc/apt/keyrings/docker.asc"
    execute_controlled "Removing legacy Docker GPG key" "rm -f /usr/share/keyrings/docker-archive-keyring.gpg"
    
    # Update package cache after removing repository
    if apt_update_controlled; then
        log_success "Package cache updated after Docker repository removal"
    else
        log_warning "Failed to update package cache - continuing with cleanup"
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
    
    # Step 5: Clean up Docker network namespaces and mounted resources
    log_step "5 Cleaning up Docker network namespaces and mounted resources"
    
    # Clean up network namespaces first
    if [[ -d "/run/docker/netns" ]]; then
        log_verbose "Cleaning up Docker network namespaces"
        for netns in /run/docker/netns/*; do
            if [[ -f "$netns" ]]; then
                local netns_name=$(basename "$netns")
                log_verbose "Unmounting network namespace: $netns_name"
                execute_controlled "Unmounting netns $netns_name" "umount \"$netns\" 2>/dev/null || true"
            fi
        done
    fi
    
    # Clean up any remaining Docker mount points
    log_verbose "Cleaning up Docker mount points"
    local docker_mounts=$(mount | grep -E "(docker|containerd)" | awk '{print $3}' || true)
    if [[ -n "$docker_mounts" ]]; then
        echo "$docker_mounts" | while IFS= read -r mount_point; do
            if [[ -n "$mount_point" ]]; then
                log_verbose "Unmounting: $mount_point"
                execute_controlled "Unmounting $mount_point" "umount \"$mount_point\" 2>/dev/null || true"
            fi
        done
    fi
    
    # Step 6: Remove Docker data and configuration directories
    log_step "6 Removing Docker data and configuration directories"
    
    # Define directories to remove with special handling for runtime directories
    local persistent_dirs=(
        "/var/lib/docker"
        "/var/lib/containerd"
        "/etc/docker"
        "/etc/containerd"
        "/opt/containerd"
    )
    
    local runtime_dirs=(
        "/run/docker"
        "/run/containerd"
    )
    
    # Remove persistent directories first
    for dir in "${persistent_dirs[@]}"; do
        safe_remove_docker_dir "$dir" "Removing Docker directory $dir"
    done
    
    # Handle runtime directories with extra care
    for dir in "${runtime_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_verbose "Attempting safe removal of runtime directory: $dir"
            safe_remove_docker_dir "$dir" "Removing Docker runtime directory $dir"
        fi
    done
    
    # Step 7: Remove Docker users and groups
    log_step "7 Cleaning up Docker users and groups"
    if getent group docker >/dev/null 2>&1; then
        execute_controlled "Removing docker group" "groupdel docker 2>/dev/null || true"
    fi
    
    # Step 8: Remove systemd service files
    log_step "8 Removing Docker systemd service files"
    local service_files=(
        "/lib/systemd/system/docker.service"
        "/lib/systemd/system/docker.socket"
        "/lib/systemd/system/containerd.service"
        "/etc/systemd/system/docker.service"
        "/etc/systemd/system/docker.socket" 
        "/etc/systemd/system/containerd.service"
    )
    
    for service_file in "${service_files[@]}"; do
        if [[ -f "$service_file" ]]; then
            execute_controlled "Removing service file $service_file" "rm -f \"$service_file\""
        fi
    done
    
    # Reload systemd after removing service files
    execute_controlled "Reloading systemd daemon" "systemctl daemon-reload"
    
    # Step 9: Clean up remaining packages and dependencies
    log_step "9 Cleaning up remaining dependencies"
    if apt_autoremove_controlled; then
        log_success "Unused packages cleaned up successfully"
    else
        log_warning "Failed to clean up all unused packages"
    fi
    
    log_success "Docker uninstallation completed successfully"
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
k8sReset() {
    local verbose_flag="${1:-}"

    log_info "Starting Kubernetes cluster reset..."

    # Check if any Kubernetes components are installed
    local kubeadm_installed=false
    local kubectl_installed=false
    local kubelet_installed=false

    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm_installed=true
    fi

    if command -v kubectl >/dev/null 2>&1; then
        kubectl_installed=true
    fi

    if command -v kubelet >/dev/null 2>&1; then
        kubelet_installed=true
    fi

    # If no Kubernetes components are found, exit gracefully
    if [[ "$kubeadm_installed" == "false" && "$kubectl_installed" == "false" && "$kubelet_installed" == "false" ]]; then
        log_info "No Kubernetes components found to reset."
        log_info "Kubernetes appears to be not installed - nothing to reset."
        return 0
    fi

    # Show what components were found
    if is_verbose_mode "$verbose_flag"; then
        log_info "Found Kubernetes components:"
        [[ "$kubeadm_installed" == "true" ]] && echo -e "  ${COLOR_GREEN}✓ kubeadm${COLOR_RESET}" || echo -e "  ${COLOR_DIM}- kubeadm (not found)${COLOR_RESET}"
        [[ "$kubectl_installed" == "true" ]] && echo -e "  ${COLOR_GREEN}✓ kubectl${COLOR_RESET}" || echo -e "  ${COLOR_DIM}- kubectl (not found)${COLOR_RESET}"
        [[ "$kubelet_installed" == "true" ]] && echo -e "  ${COLOR_GREEN}✓ kubelet${COLOR_RESET}" || echo -e "  ${COLOR_DIM}- kubelet (not found)${COLOR_RESET}"
    fi

    # Only run kubeadm reset if kubeadm is installed
    if [[ "$kubeadm_installed" == "true" ]]; then
        log_info "Performing kubeadm reset..."
        if is_verbose_mode "$verbose_flag"; then
            kubeadm reset <<EOF
y
EOF
        else
            kubeadm reset <<EOF 2>/dev/null || { log_warning "kubeadm reset failed, continuing with cleanup"; }
y
EOF
        fi
    else
        log_info "Skipping kubeadm reset (kubeadm not found)..."
    fi

    log_info "Removing Kubernetes packages..."
    remove_kubernetes_packages "$verbose_flag"

    # Reset related components
    # log_info "Resetting Helm package manager..."
    # helmReset

    # log_info "Resetting HAProxy load balancer..."
    # haproxyReset

    # log_info "Resetting Docker container runtime..."
    # dockrReset

    log_success "Kubernetes reset completed successfully."
}
helmReset() { log_info "Resetting Helm..."; helm reset --force 2>/dev/null || true; }
calicoReset() { helm_component_reset "calico" "kube-system"; }
ingressReset() { helm_component_reset "ingress-nginx" "ingress-nginx"; }
haproxyReset() { 
    log_info "Resetting HAProxy..."
    
    # Stop and remove HAProxy container
    if docker ps -q -f name=master-proxy | grep -q .; then
        execute_controlled "Stopping HAProxy container" "docker stop master-proxy" || true
    fi
    
    if docker ps -a -q -f name=master-proxy | grep -q .; then
        execute_controlled "Removing HAProxy container" "docker rm master-proxy" || true
    fi
    
    # Remove HAProxy configuration file
    if [[ -f /opt/haproxy.cfg ]]; then
        log_substep "Removing HAProxy configuration file"
        rm -f /opt/haproxy.cfg || log_warning "Failed to remove HAProxy configuration"
    fi
    
    # Remove HAProxy image (optional, as it's commonly used)
    # docker rmi haproxy:latest 2>/dev/null || true
    
    log_success "HAProxy reset completed"
}
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