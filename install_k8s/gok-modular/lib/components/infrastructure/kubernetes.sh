#!/bin/bash

# GOK Infrastructure Components - Core infrastructure installation functions

# Docker installation
dockrInst() {
    log_component_start "docker" "Installing Docker container runtime"
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        log_info "Docker is already installed"
        docker --version
        return 0
    fi
    
    log_info "Installing Docker CE..."
    
    # Update package index
    execute_with_suppression apt-get update
    
    # Install prerequisites
    execute_with_suppression apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    execute_with_suppression apt-get update
    
    # Install Docker
    execute_with_suppression apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Add current user to docker group
    usermod -aG docker "${USER:-$(whoami)}"
    
    # Start and enable Docker service
    systemctl enable docker
    systemctl start docker
    
    # Verify installation
    if docker --version >/dev/null 2>&1; then
        log_component_success "docker" "Docker installation completed successfully"
        docker --version
        return 0
    else
        log_component_error "docker" "Docker installation failed"
        return 1
    fi
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