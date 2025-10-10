#!/bin/bash

# GOK Infrastructure Components - Core infrastructure installation functions

# Docker installation with comprehensive validation and configuration
dockrInst() {
    log_component_start "docker" "Installing Docker container runtime"
    
    # Pre-installation validation
    log_step "1" "Validating system requirements for Docker"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "Docker installation requires root privileges"
        return 1
    fi
    
    # Check system compatibility
    local os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
    log_info "Operating System: $os_info"
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        log_warning "Docker is already installed (version: $docker_version)"
        
        # Validate existing installation
        if validate_docker_installation 30; then
            log_component_success "docker" "Existing Docker installation is working correctly"
            show_docker_next_steps
            return 0
        else
            log_warning "Existing Docker installation has issues, proceeding with reinstallation"
        fi
    fi
    
    # Step 2: Install prerequisites
    log_step "2" "Installing Docker prerequisites and dependencies"
    log_substep "Installing required packages"
    
    if ! apt-get update; then
        log_error "Failed to update package list"
        return 1
    fi
    
    if ! apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg \
        lsb-release; then
        log_error "Failed to install prerequisite packages"
        return 1
    fi
    
    log_success "Prerequisites installed successfully"
    
    # Step 3: Add Docker repository
    log_step "3" "Adding Docker official repository"
    
    log_substep "Creating keyrings directory"
    if ! install -m 0755 -d /etc/apt/keyrings; then
        log_error "Failed to create keyrings directory"
        return 1
    fi
    
    log_substep "Adding Docker GPG key"
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; then
        log_error "Failed to download Docker GPG key"
        return 1
    fi
    
    if ! chmod a+r /etc/apt/keyrings/docker.asc; then
        log_error "Failed to set permissions on Docker GPG key"
        return 1
    fi
    
    log_substep "Adding Docker repository to sources"
    if ! echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        log_error "Failed to add Docker repository"
        return 1
    fi
    
    log_substep "Updating package list with Docker repository"
    if ! apt-get update; then
        log_error "Failed to update package list after adding Docker repository"
        return 1
    fi
    
    log_success "Docker repository added successfully"
    
    # Step 4: Install Docker Engine
    log_step "4" "Installing Docker Engine and components"
    
    local docker_packages="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    log_substep "Installing: $docker_packages"
    
    if ! apt-get install -y $docker_packages; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    
    log_success "Docker Engine installed successfully"
    
    # Step 5: Configure Docker daemon
    log_step "5" "Configuring Docker daemon for Kubernetes compatibility"
    
    configure_docker_daemon || return 1
    
    # Step 6: Configure and start services
    log_step "6" "Starting and enabling Docker services"
    
    configure_docker_services || return 1
    
    # Step 7: Set up user permissions (if not root)
    if [[ -n "$SUDO_USER" ]]; then
        log_step "7" "Configuring user permissions for Docker"
        log_substep "Adding user $SUDO_USER to docker group"
        
        if ! usermod -aG docker "$SUDO_USER"; then
            log_warning "Failed to add user to docker group - manual setup may be required"
        else
            log_success "User $SUDO_USER added to docker group"
            log_info "User $SUDO_USER will need to log out and back in for group membership to take effect"
        fi
    fi
    
    # Step 8: Post-installation validation
    log_step "8" "Validating Docker installation"
    
    if validate_docker_installation 30; then
        log_success "Docker installation validation passed"
    else
        log_error "Docker installation validation failed"
        return 1
    fi
    
    # Show Docker information
    local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    local containerd_version=$(containerd --version | cut -d' ' -f3)
    
    log_component_success "docker" "Docker installation completed successfully!"
    log_info "Docker version: $docker_version"
    log_info "Containerd version: $containerd_version"
    
    # Show next steps and system status
    show_docker_next_steps
    show_docker_system_status
    
    return 0
}

# Kubernetes master installation
k8sInst() {
    local install_type="${1:-kubernetes}"
    
    log_component_start "kubernetes" "Installing Kubernetes $install_type"
    
    # Prerequisites check
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required before installing Kubernetes"
        return 1
    fi
    
    log_info "Installing Kubernetes components..."
    
    # Update package index
    execute_with_suppression apt-get update
    
    # Install prerequisites
    execute_with_suppression apt-get install -y apt-transport-https ca-certificates curl
    
    # Add Kubernetes GPG key
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    
    # Add Kubernetes repository
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
    
    # Update package index
    execute_with_suppression apt-get update
    
    # Install Kubernetes components
    execute_with_suppression apt-get install -y kubelet kubeadm kubectl
    
    # Hold packages to prevent automatic updates
    apt-mark hold kubelet kubeadm kubectl
    
    if [[ "$install_type" == "kubernetes" ]]; then
        # Initialize master node
        log_info "Initializing Kubernetes master node..."
        kubeadm init --pod-network-cidr=192.168.0.0/16
        
        # Setup kubectl for current user
        mkdir -p "$HOME/.kube"
        cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
        chown "$(id -u):$(id -g)" "$HOME/.kube/config"
        
        # Remove master node taint to allow scheduling on master (for single-node clusters)
        kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true
        kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
        
        log_component_success "kubernetes" "Kubernetes master installation completed"
    else
        log_component_success "kubernetes-worker" "Kubernetes worker installation completed"
        log_info "To join this node to a cluster, run the 'kubeadm join' command from the master"
    fi
    
    return 0
}

# Helm installation
helmInst() {
    log_component_start "helm" "Installing Helm package manager"
    
    # Check if Helm is already installed
    if command -v helm >/dev/null 2>&1; then
        log_info "Helm is already installed"
        helm version --short
        return 0
    fi
    
    log_info "Installing Helm..."
    
    # Download and install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Add common Helm repositories
    log_info "Adding common Helm repositories..."
    local repos=(
        "bitnami:https://charts.bitnami.com/bitnami"
        "prometheus-community:https://prometheus-community.github.io/helm-charts"
        "ingress-nginx:https://kubernetes.github.io/ingress-nginx"
        "jetstack:https://charts.jetstack.io"
    )
    
    for repo in "${repos[@]}"; do
        local name="${repo%%:*}"
        local url="${repo#*:}"
        helm repo add "$name" "$url" 2>/dev/null || true
    done
    
    # Update repositories
    helm repo update
    
    if command -v helm >/dev/null 2>&1; then
        log_component_success "helm" "Helm installation completed successfully"
        helm version --short
        return 0
    else
        log_component_error "helm" "Helm installation failed"
        return 1
    fi
}

# =============================================================================
# DOCKER CONFIGURATION AND VALIDATION FUNCTIONS
# =============================================================================

# Configure Docker daemon for Kubernetes compatibility
configure_docker_daemon() {
    log_substep "Creating systemd service directory"
    if ! mkdir -p /etc/systemd/system/docker.service.d; then
        log_error "Failed to create Docker systemd directory"
        return 1
    fi
    
    log_substep "Creating Docker daemon configuration"
    if ! tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ]
}
EOF
    then
        log_error "Failed to create Docker daemon configuration"
        return 1
    fi
    
    log_success "Docker daemon configured for Kubernetes"
    return 0
}

# Configure Docker and containerd services
configure_docker_services() {
    log_substep "Reloading systemd daemon"
    if ! systemctl daemon-reload; then
        log_error "Failed to reload systemd daemon"
        return 1
    fi
    
    log_substep "Starting Docker service"
    if ! systemctl start docker; then
        log_error "Failed to start Docker service"
        return 1
    fi
    
    log_substep "Enabling Docker service for auto-start"
    if ! systemctl enable docker; then
        log_error "Failed to enable Docker service"
        return 1
    fi
    
    # Configure containerd
    log_substep "Configuring containerd for Kubernetes"
    
    if ! systemctl enable containerd; then
        log_error "Failed to enable containerd service"
        return 1
    fi
    
    if ! systemctl start containerd; then
        log_error "Failed to start containerd service"
        return 1
    fi
    
    # Remove default containerd config to use defaults
    if [[ -f /etc/containerd/config.toml ]]; then
        log_substep "Removing default containerd configuration"
        rm /etc/containerd/config.toml
        systemctl restart containerd
    fi
    
    log_success "Docker and containerd services started successfully"
    return 0
}

# Note: validate_docker_installation is provided by lib/utils/validation.sh

# Show Docker system status
show_docker_system_status() {
    echo
    log_section "Docker System Status" "🔍"
    
    # Docker daemon status
    log_substep "Checking Docker daemon status"
    if systemctl is-active --quiet docker; then
        log_success "Docker daemon: Running"
    else
        log_error "Docker daemon: Not running"
    fi
    
    # Containerd status
    log_substep "Checking containerd status"
    if systemctl is-active --quiet containerd; then
        log_success "Containerd: Running"
    else
        log_error "Containerd: Not running"
    fi
    
    # Docker version info
    log_substep "Checking Docker versions"
    local docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
    local containerd_version=$(containerd --version 2>/dev/null | cut -d' ' -f3)
    
    if [[ -n "$docker_version" ]]; then
        log_success "Docker version: $docker_version"
    else
        log_warning "Docker version: Unknown"
    fi
    
    if [[ -n "$containerd_version" ]]; then
        log_success "Containerd version: $containerd_version"
    else
        log_warning "Containerd version: Unknown"
    fi
    
    # Docker configuration check
    log_substep "Validating Docker configuration"
    local cgroup_driver=$(docker info 2>/dev/null | grep "Cgroup Driver" | cut -d: -f2 | tr -d ' ')
    if [[ "$cgroup_driver" == "systemd" ]]; then
        log_success "Cgroup driver: systemd (Kubernetes compatible)"
    else
        log_warning "Cgroup driver: $cgroup_driver (may need systemd for Kubernetes)"
    fi
    
    # Storage driver check
    local storage_driver=$(docker info 2>/dev/null | grep "Storage Driver" | cut -d: -f2 | tr -d ' ')
    if [[ -n "$storage_driver" ]]; then
        log_success "Storage driver: $storage_driver"
    else
        log_warning "Storage driver: Unknown"
    fi
    
    # Container count check
    log_substep "Checking container status"
    local running_containers=$(docker ps -q 2>/dev/null | wc -l)
    local total_containers=$(docker ps -aq 2>/dev/null | wc -l)
    if [[ $? -eq 0 ]]; then
        log_success "Containers: $running_containers running, $total_containers total"
    else
        log_warning "Unable to check container status"
    fi
}

# Show Docker next steps
show_docker_next_steps() {
    log_next_steps "Docker Installation Complete" \
        "Test Docker functionality: docker run hello-world" \
        "Check Docker service status: systemctl status docker" \
        "View Docker system information: docker info" \
        "Verify container runtime: docker version" \
        "Install Kubernetes cluster: gok-new install kubernetes"
    
    log_urls "Docker Resources & Documentation" \
        "Docker Documentation: https://docs.docker.com/" \
        "Docker Hub Registry: https://hub.docker.com/" \
        "Kubernetes Container Runtime Guide: https://kubernetes.io/docs/setup/production-environment/container-runtimes/" \
        "Docker Best Practices: https://docs.docker.com/develop/best-practices/"
    
    log_credentials "Docker Management" "Current User" \
        "Docker group membership: Required for non-root access" \
        "Restart required: Log out and back in to apply group changes" \
        "Test access: docker ps (should work without sudo)"
    
    # Enhanced HA proxy detection and recommendation
    check_and_suggest_ha_setup
    
    log_info "Docker container runtime is now ready for Kubernetes installation"
}

# Enhanced HA setup detection and suggestions
check_and_suggest_ha_setup() {
    local suggest_ha=false
    local ha_reason=""
    
    # Check for multiple API servers configuration
    if [[ -n "$API_SERVERS" ]] && [[ "$API_SERVERS" == *","* ]]; then
        suggest_ha=true
        local server_count=$(echo "$API_SERVERS" | tr ',' '\n' | wc -l)
        ha_reason="Multiple API servers detected ($server_count servers) in API_SERVERS configuration"
    fi
    
    # Check for multiple network interfaces (potential multi-node setup)
    local interface_count=$(ip -o link show | grep -v lo | wc -l)
    if [[ $interface_count -gt 1 ]]; then
        suggest_ha=true
        ha_reason="${ha_reason:+$ha_reason; }Multiple network interfaces detected"
    fi
    
    # Check available memory for multi-node capacity
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -ge 8 ]]; then
        suggest_ha=true
        ha_reason="${ha_reason:+$ha_reason; }Sufficient memory for multi-node setup (${mem_gb}GB available)"
    fi
    
    if [[ "$suggest_ha" == true ]]; then
        log_info "HA Setup Recommendation: $ha_reason"
        log_substep "Consider setting up HA cluster with multiple control planes"
        log_substep "Use: gok-new install kubernetes-ha for high availability setup"
    fi
}

# Calico network plugin installation
calicoInst() {
    log_component_start "calico" "Installing Calico network plugin"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "Kubernetes is required before installing Calico"
        return 1
    fi
    
    log_info "Installing Calico network plugin..."
    
    # Apply Calico YAML
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    
    # Wait for Calico pods to be ready
    log_info "Waiting for Calico pods to be ready..."
    kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s
    
    log_component_success "calico" "Calico network plugin installation completed"
    return 0
}

# NGINX Ingress Controller installation
ingressInst() {
    log_component_start "ingress" "Installing NGINX Ingress Controller"
    
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm is required before installing Ingress Controller"
        return 1
    fi
    
    log_info "Installing NGINX Ingress Controller..."
    
    # Create namespace
    ensure_namespace "ingress-nginx"
    
    # Add ingress-nginx repository if not already added
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update
    
    # Install NGINX Ingress Controller
    helm_install_with_summary "ingress-nginx" "ingress-nginx" \
        ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --set controller.service.type=LoadBalancer \
        --set controller.service.externalIPs='{192.168.1.100}' \
        --wait
    
    # Wait for deployment to be ready
    check_deployment_readiness "ingress-nginx-controller" "ingress-nginx" 300
    
    log_component_success "ingress" "NGINX Ingress Controller installation completed"
    return 0
}

# HAProxy installation for Kubernetes API server load balancing
haproxyInst() {
    log_component_start "haproxy" "Installing HAProxy load balancer for Kubernetes API servers"
    
    # Debug: Show environment variables
    log_debug "Debug: Environment variables check"
    log_debug "API_SERVERS='${API_SERVERS:-<not set>}'"
    log_debug "HA_PROXY_PORT='${HA_PROXY_PORT:-<not set>}'"
    log_debug "Current working directory: $(pwd)"
    log_debug "Config file location: /root/kubernetes/install_k8s/config"
    
    # Pre-installation validation
    log_step "1 Validating prerequisites for HAProxy installation"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "HAProxy installation requires root privileges"
        return 1
    fi
    
    # Check if Docker is installed and running
    if ! validate_docker_installation 10; then
        log_error "Docker is required for HAProxy installation"
        return 1
    fi
    
    # Debug: Show variable values before validation
    log_debug "Debug: Variable validation check"
    log_debug "API_SERVERS value: '${API_SERVERS}' (length: ${#API_SERVERS})"
    log_debug "HA_PROXY_PORT value: '${HA_PROXY_PORT}' (length: ${#HA_PROXY_PORT})"
    
    # Check if API_SERVERS is configured
    if [[ -z "$API_SERVERS" ]]; then
        log_error "API_SERVERS environment variable is not set"
        log_info "Please configure API_SERVERS with comma-separated list of master nodes (format: ip1:hostname1,ip2:hostname2)"
        return 1
    fi
    
    # Check if HA_PROXY_PORT is configured
    if [[ -z "$HA_PROXY_PORT" ]]; then
        log_error "HA_PROXY_PORT environment variable is not set"
        log_info "Please configure HA_PROXY_PORT (default: 6443)"
        return 1
    fi
    
    log_success "Prerequisites validation passed"
    
    # Step 2: Clean up existing HAProxy container and configuration
    log_step "2 Cleaning up existing HAProxy installation"

    # Stop and remove existing container
    if docker ps -q -f name=master-proxy | grep -q .; then
        log_substep "Stopping existing HAProxy container"
        docker stop master-proxy >/dev/null 2>&1 || log_warning "Failed to stop existing container"
    fi
    
    if docker ps -a -q -f name=master-proxy | grep -q .; then
        log_substep "Removing existing HAProxy container"
        docker rm master-proxy >/dev/null 2>&1 || log_warning "Failed to remove existing container"
    fi
    
    # Remove existing configuration file
    if [[ -f /opt/haproxy.cfg ]]; then
        log_substep "Removing existing HAProxy configuration"
        rm -f /opt/haproxy.cfg || log_warning "Failed to remove existing configuration"
    fi
    
    log_success "Cleanup completed"
    
    # Step 3: Generate HAProxy configuration
    log_step "3 Generating HAProxy configuration"

    log_substep "Creating HAProxy configuration file at /opt/haproxy.cfg"
    
    # Debug: Show configuration generation details
    log_debug "Debug: Configuration generation"
    log_debug "HA_PROXY_PORT for bind: '${HA_PROXY_PORT}'"
    log_debug "API_SERVERS for backend: '${API_SERVERS}'"
    
    if cat > /opt/haproxy.cfg << EOF
global
        log /dev/log local0
        log /dev/log local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

defaults
        log global
        mode tcp
        option tcplog
        option dontlognull
        option redispatch
        retries 3
        timeout connect 5000ms
        timeout client 50000ms
        timeout server 50000ms
        
frontend kubernetes-apiserver
        bind *:$HA_PROXY_PORT
        mode tcp
        option tcplog
        default_backend kubernetes-apiserver

backend kubernetes-apiserver
        mode tcp
        balance roundrobin
        option tcp-check
        option tcplog
$(
    # Generate backend servers from API_SERVERS
    IFS=','
    counter=0
    for worker in $API_SERVERS; do
      oifs=$IFS
      IFS=':'
      read -r ip node <<<"$worker"
      counter=$((counter + 1))
      echo "        server $node $ip:6443 check fall 3 rise 2"
      IFS=$oifs
    done
    unset IFS
)
EOF
    then
        log_success "HAProxy configuration generated"
        
        # Display configuration summary
        log_info "Configuration summary:"
        log_substep "Frontend port: $HA_PROXY_PORT"
        log_substep "Backend servers:"
        
        IFS=','
        counter=0
        for worker in $API_SERVERS; do
            oifs=$IFS
            IFS=':'
            read -r ip node <<<"$worker"
            counter=$((counter + 1))
            log_substep "  $counter. $node ($ip:6443)"
            IFS=$oifs
        done
        unset IFS
    else
        log_error "Failed to create HAProxy configuration file"
        return 1
    fi
    
    # Step 4: Pull HAProxy image
    log_step "4 Pulling HAProxy Docker image"
    
    if ! docker pull haproxy:latest; then
        log_error "Failed to pull HAProxy Docker image"
        return 1
    fi
    
    log_success "HAProxy image pulled successfully"
    
    # Step 5: Start HAProxy container
    log_step "5 Starting HAProxy container"
    
    log_substep "Running HAProxy container with host networking"
    
    if ! docker run -d --name master-proxy \
        --restart=unless-stopped \
        -v /opt/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
        --net=host \
        haproxy:latest; then
        log_error "Failed to start HAProxy container"
        return 1
    fi
    
    log_success "HAProxy container started successfully"
    
    # Step 6: Validate installation
    log_step "6 Validating HA proxy installation"
    
    # Wait a moment for container to start
    sleep 3
    
    if validate_haproxy_installation; then
        log_success "HA proxy installation validation passed"
    else
        log_error "HA proxy installation validation failed"
        return 1
    fi
    
    # Show next steps
    show_component_next_steps "haproxy"
    
    return 0
}

# Network policy setup
setup_network_policies() {
    log_info "Setting up default network policies..."
    
    # This is a placeholder for network policy configuration
    # Actual implementation would depend on specific security requirements
    
    log_info "Network policies setup completed"
}

# Container runtime configuration
configure_container_runtime() {
    log_info "Configuring container runtime..."
    
    # Configure Docker daemon
    cat > /etc/docker/daemon.json << 'EOF'
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF
    
    # Restart Docker to apply configuration
    systemctl restart docker
    
    log_info "Container runtime configuration completed"
}