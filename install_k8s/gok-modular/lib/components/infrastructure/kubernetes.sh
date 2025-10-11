#!/bin/bash

# GOK Infrastructure Components - Core infrastructure installation functions

# Docker installation with comprehensive validation and configuration
dockrInst() {
    log_component_start "docker" "Installing Docker container runtime"
    
    # Pre-installation validation
    log_step "1 Validating system requirements for Docker"
    
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
    log_step "2 Installing Docker prerequisites and dependencies"
    
    if ! apt_update_controlled; then
        log_error "Failed to update package list"
        return 1
    fi
    
    if ! apt_install_controlled \
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
    log_step "3 Adding Docker official repository"

    if ! execute_controlled "Creating keyrings directory" "install -m 0755 -d /etc/apt/keyrings"; then
        log_error "Failed to create keyrings directory"
        return 1
    fi
    
    if ! execute_controlled "Adding Docker GPG key" "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"; then
        log_error "Failed to download Docker GPG key"
        return 1
    fi
    
    if ! execute_controlled "Setting GPG key permissions" "chmod a+r /etc/apt/keyrings/docker.asc"; then
        log_error "Failed to set permissions on Docker GPG key"
        return 1
    fi
    
    log_verbose "Adding Docker repository to sources"
    if ! echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        log_error "Failed to add Docker repository"
        return 1
    fi
    
    if ! apt_update_controlled; then
        log_error "Failed to update package list after adding Docker repository"
        return 1
    fi
    
    log_success "Docker repository added successfully"
    
    # Step 4: Install Docker Engine
    log_step "4 Installing Docker Engine and components"
    
    local docker_packages="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    
    if ! apt_install_controlled $docker_packages; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    
    log_success "Docker Engine installed successfully"
    
    # Step 5: Configure Docker daemon
    log_step "5 Configuring Docker daemon for Kubernetes compatibility"
    
    configure_docker_daemon || return 1
    
    # Step 6: Configure and start services
    log_step "6 Starting and enabling Docker services"

    configure_docker_services || return 1
    
    # Step 7: Set up user permissions (if not root)
    if [[ -n "$SUDO_USER" ]]; then
        log_step "7 Configuring user permissions for Docker"
        log_substep "Adding user $SUDO_USER to docker group"
        
        if ! usermod -aG docker "$SUDO_USER"; then
            log_warning "Failed to add user to docker group - manual setup may be required"
        else
            log_success "User $SUDO_USER added to docker group"
            log_info "User $SUDO_USER will need to log out and back in for group membership to take effect"
        fi
    fi
    
    # Step 8: Post-installation validation
    log_step "8 Validating Docker installation"

    if validate_docker_installation 30; then
        complete_component "docker" "Docker installation completed and validated"
    else
        complete_component "docker" "Docker installed but validation had warnings"
        return 1
    fi
        
    log_component_success "docker" "Docker installation completed successfully!"
    
    return 0
}

# Kubernetes installation with comprehensive system configuration
k8sInst() {
    local k8s_type="${1:-kubernetes}"
    local verbose_mode="${GOK_VERBOSE:-false}"

    # Check for verbose flags in all arguments
    for arg in "$@"; do
        if [[ "$arg" == "--verbose" ]] || [[ "$arg" == "-v" ]]; then
            verbose_mode="true"
            break
        fi
    done

    # Also check if GOK_VERBOSE environment variable is set
    if [[ "${GOK_VERBOSE}" == "true" ]]; then
        verbose_mode="true"
    fi

    log_component_start "kubernetes" "Installing $k8s_type"

    # Step 1: System Prerequisites and Kernel Modules
    log_step "1 Configuring system prerequisites and kernel modules"

    if ! validate_system_requirements; then
        log_error "System requirements validation failed"
        return 1
    fi

    log_info "Loading required kernel modules..."
    local mod_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo modprobe overlay br_netfilter"
        if mod_output=$(sudo modprobe overlay && sudo modprobe br_netfilter 2>&1); then
            log_success "Kernel modules loaded successfully"
            [[ -n "$mod_output" ]] && log_debug "$mod_output"
        else
            log_error "Failed to load kernel modules"
            log_error "Error details: $mod_output"
            return 1
        fi
    else
        if mod_output=$(sudo modprobe overlay && sudo modprobe br_netfilter 2>&1); then
            log_success "Kernel modules loaded successfully"
        else
            log_error "Failed to load kernel modules"
            log_error "Error details: $mod_output"
            return 1
        fi
    fi

    # Configure persistent module loading
    log_info "Configuring persistent kernel modules..."
    sudo tee /etc/modules-load.d/containerd.conf <<EOF >/dev/null
overlay
br_netfilter
EOF
    log_success "Kernel modules configured for persistence"

    # Step 2: Network Configuration
    log_step "2 Configuring network settings for Kubernetes"

    log_info "Setting up network bridge configurations..."
    sudo tee /etc/sysctl.d/kubernetes.conf <<EOF >/dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

    local sysctl_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo sysctl --system"
        if sysctl_output=$(sudo sysctl --system 2>&1); then
            log_success "Network settings applied successfully"
            log_debug "$sysctl_output"
        else
            log_error "Failed to apply network settings"
            log_error "Error details: $sysctl_output"
            return 1
        fi
    else
        if sysctl_output=$(sudo sysctl --system 2>&1); then
            log_success "Network settings applied successfully"
        else
            log_error "Failed to apply network settings"
            log_error "Error details: $sysctl_output"
            return 1
        fi
    fi

    # Step 3: Container Runtime Configuration
    log_step "3 Configuring containerd container runtime"

    log_info "Setting up containerd configuration..."
    sudo mkdir -p /etc/containerd

    local containerd_config_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Creating /etc/containerd directory and configuration..."
        log_debug "Executing: containerd config default | sudo tee /etc/containerd/config.toml"
        if containerd_config_output=$(containerd config default 2>&1) && echo "$containerd_config_output" | sudo tee /etc/containerd/config.toml >/dev/null; then
            log_success "Default containerd configuration created"
            log_debug "Configuration written to /etc/containerd/config.toml"
        else
            log_error "Failed to create containerd configuration"
            log_error "Error details: $containerd_config_output"
            return 1
        fi
    else
        if containerd_config_output=$(containerd config default 2>&1) && echo "$containerd_config_output" | sudo tee /etc/containerd/config.toml >/dev/null; then
            log_success "Default containerd configuration created"
        else
            log_error "Failed to create containerd configuration"
            log_error "Error details: $containerd_config_output"
            return 1
        fi
    fi

    # Configure systemd cgroup driver
    log_info "Configuring systemd cgroup driver..."
    local sed_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Updating containerd config: SystemdCgroup = false -> SystemdCgroup = true"
        log_debug "Executing: sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml"
        if sed_output=$(sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml 2>&1); then
            log_success "Systemd cgroup driver configured"
            log_debug "Verification:"
            local cgroup_check=$(grep -n "SystemdCgroup" /etc/containerd/config.toml || echo "SystemdCgroup setting not found")
            log_debug "$cgroup_check"
        else
            log_warning "Cgroup driver configuration may have failed"
            log_warning "Warning details: $sed_output"
        fi
    else
        if sed_output=$(sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml 2>&1); then
            log_success "Systemd cgroup driver configured"
        else
            log_warning "Cgroup driver configuration may have failed"
            log_warning "Warning details: $sed_output"
        fi
    fi

    # Restart and enable containerd
    log_info "Starting containerd service..."
    local containerd_service_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo systemctl restart containerd && sudo systemctl enable containerd"
        if containerd_service_output=$(sudo systemctl restart containerd 2>&1 && sudo systemctl enable containerd 2>&1); then
            log_success "Containerd service started and enabled"
            [[ -n "$containerd_service_output" ]] && log_debug "$containerd_service_output"
        else
            log_error "Failed to start containerd service"
            log_error "Error details: $containerd_service_output"
            log_info "Try: sudo systemctl status containerd for more details"
            return 1
        fi
    else
        if containerd_service_output=$(sudo systemctl restart containerd 2>&1 && sudo systemctl enable containerd 2>&1); then
            log_success "Containerd service started and enabled"
        else
            log_error "Failed to start containerd service"
            log_error "Error details: $containerd_service_output"
            log_info "Try: sudo systemctl status containerd for more details"
            return 1
        fi
    fi

    # Step 4: Kubernetes Repository Setup
    log_step "4 Setting up Kubernetes package repository"

    # Clean up old Kubernetes repositories first
    log_info "Cleaning up old Kubernetes repositories..."
    sudo rm -f /etc/apt/sources.list.d/kubernetes.list
    sudo rm -f /etc/apt/sources.list.d/kubernetes-xenial.list
    sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo rm -f /usr/share/keyrings/kubernetes-apt-keyring.gpg

    # Remove any old Google repository references
    if grep -q "packages.cloud.google.com" /etc/apt/sources.list 2>/dev/null; then
        sudo sed -i '/packages.cloud.google.com/d' /etc/apt/sources.list
    fi

    log_info "Installing required packages..."
    local repo_packages_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo apt-get install -y apt-transport-https ca-certificates curl"
        if repo_packages_output=$(sudo apt-get install -y apt-transport-https ca-certificates curl 2>&1); then
            log_success "Required packages installed"
            log_debug "$repo_packages_output"
        else
            log_error "Failed to install required packages"
            log_error "Error details: $repo_packages_output"
            return 1
        fi
    else
        if repo_packages_output=$(sudo apt-get install -y apt-transport-https ca-certificates curl 2>&1); then
            log_success "Required packages installed"
        else
            log_error "Failed to install required packages"
            log_error "Error details: $repo_packages_output"
            return 1
        fi
    fi

    # Setup Kubernetes signing key
    log_info "Adding Kubernetes signing key..."
    sudo mkdir -p -m 755 /etc/apt/keyrings

    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Downloading Kubernetes signing key from pkgs.k8s.io..."
        if curl -fsSL --show-error https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
           sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; then
            sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            log_success "Kubernetes signing key added"
            log_debug "Key location: /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
        else
            log_error "Failed to add Kubernetes signing key"
            return 1
        fi
    else
        if curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key 2>/dev/null | \
           sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null; then
            sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            log_success "Kubernetes signing key added"
        else
            log_error "Failed to add Kubernetes signing key"
            return 1
        fi
    fi

    # Add Kubernetes repository
    log_info "Adding Kubernetes repository..."
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Creating repository configuration: /etc/apt/sources.list.d/kubernetes.list"
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
          sudo tee /etc/apt/sources.list.d/kubernetes.list
    else
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
          sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    fi
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
    log_success "Kubernetes repository added"

    # Now update package lists with the new repository
    log_info "Updating package lists with new repository..."
    local apt_update_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo apt-get update"
        if apt_update_output=$(sudo apt-get update 2>&1); then
            log_success "Package lists updated"
            log_debug "$apt_update_output"
        else
            log_error "Failed to update package lists"
            log_error "Error details: $apt_update_output"
            return 1
        fi
    else
        if apt_update_output=$(sudo apt-get update 2>&1); then
            log_success "Package lists updated"
        else
            log_error "Failed to update package lists"
            log_error "Error details: $apt_update_output"
            return 1
        fi
    fi

    # Step 5: Kubernetes Components Installation
    log_step "5 Installing Kubernetes components"

    log_info "Installing kubectl, kubeadm, and kubelet..."
    local apt_install_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo apt-get install -y --allow-change-held-packages kubectl kubeadm kubelet"
        if apt_install_output=$(sudo apt-get install -y --allow-change-held-packages kubectl kubeadm kubelet 2>&1); then
            log_success "Kubernetes components installed successfully"
            log_debug "$apt_install_output"
        else
            log_error "Failed to install Kubernetes components"
            log_error "Error details: $apt_install_output"
            return 1
        fi
    else
        if apt_install_output=$(sudo apt-get install -y --allow-change-held-packages kubectl kubeadm kubelet 2>&1); then
            log_success "Kubernetes components installed successfully"
        else
            log_error "Failed to install Kubernetes components"
            log_error "Error details: $apt_install_output"
            return 1
        fi
    fi

    # Show installed versions
    local kubectl_version=$(kubectl version --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    local kubeadm_version=$(kubeadm version -o short 2>/dev/null || echo "unknown")
    local kubelet_version=$(kubelet --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "Installed versions:"
    log_info "  kubectl: $kubectl_version"
    log_info "  kubeadm: $kubeadm_version"
    log_info "  kubelet: $kubelet_version"

    # Hold packages to prevent automatic updates
    if sudo apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1; then
        log_info "Kubernetes packages held to prevent automatic updates"
    else
        log_warning "Failed to hold Kubernetes packages (kubelet, kubeadm, kubectl)"
    fi

    # Step 6: Cluster Initialization (Master) or Worker Setup
    if [[ "$k8s_type" == "kubernetes" ]]; then
        initialize_kubernetes_master "$verbose_mode"
    elif [[ "$k8s_type" == "kubernetes-worker" ]]; then
        setup_kubernetes_worker "$verbose_mode"
    else
        log_error "Unknown Kubernetes installation type: $k8s_type"
        return 1
    fi
}

# Initialize Kubernetes master node
initialize_kubernetes_master() {
    local verbose_mode="${1:-false}"

    log_step "6 Initializing Kubernetes master node"

    # Pre-flight check: Detect existing Kubernetes cluster
    log_info "Running pre-flight checks..."
    
    # Check if port 6443 is in use (existing kube-apiserver)
    if sudo lsof -i :6443 >/dev/null 2>&1; then
        log_warning "Port 6443 is in use - existing Kubernetes cluster detected"
        
        local existing_processes=$(sudo lsof -i :6443 | grep LISTEN | awk '{print $1}' | sort -u | tr '\n' ', ' | sed 's/,$//')
        log_info "Processes using port 6443: $existing_processes"
        
        # Prompt for cleanup
        log_info "An existing Kubernetes cluster must be reset before installing a new one."
        read -p "Do you want to reset the existing cluster and continue? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Resetting existing Kubernetes cluster..."
            
            # Run kubeadm reset to clean up existing cluster
            if command -v kubeadm >/dev/null 2>&1; then
                log_substep "Running kubeadm reset..."
                if [[ "$verbose_mode" == "true" ]]; then
                    sudo kubeadm reset --force
                else
                    sudo kubeadm reset --force >/dev/null 2>&1
                fi
                log_success "Existing cluster reset completed"
                
                # Wait a moment for cleanup to complete
                sleep 5
                
                # Verify port is now free
                if sudo lsof -i :6443 >/dev/null 2>&1; then
                    log_error "Port 6443 is still in use after reset. Manual cleanup required."
                    log_info "You may need to: sudo pkill -f kube-apiserver"
                    return 1
                else
                    log_success "Port 6443 is now available for new cluster"
                fi
            else
                log_error "kubeadm not found - cannot reset existing cluster"
                log_info "Manual cleanup required: sudo pkill -f kube-apiserver"
                return 1
            fi
        else
            log_info "Installation cancelled by user"
            return 1
        fi
    else
        log_success "Port 6443 is available - ready for cluster initialization"
    fi

    # Disable swap
    log_info "Disabling swap for Kubernetes..."
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    sudo swapoff -a
    log_success "Swap disabled successfully"

    # Create kubelet service file (required for modern Kubernetes)
    log_info "Setting up kubelet systemd service..."
    if ! systemctl list-unit-files kubelet.service >/dev/null 2>&1; then
        log_substep "Creating base kubelet.service file (missing from kubelet package)"
        
        # Create the base kubelet.service file that should have been provided by the package
        sudo tee /lib/systemd/system/kubelet.service > /dev/null << 'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd to recognize the new service
        sudo systemctl daemon-reload
        log_success "Base kubelet.service file created"
    fi
    
    # Now enable the kubelet service
    log_info "Enabling kubelet service..."
    local kubelet_enable_output
    if kubelet_enable_output=$(sudo systemctl enable kubelet 2>&1); then
        log_success "Kubelet service enabled"
        if [[ "$verbose_mode" == "true" ]] && [[ -n "$kubelet_enable_output" ]]; then
            log_debug "$kubelet_enable_output"
        fi
    else
        log_warning "Kubelet service enable failed: $kubelet_enable_output"
    fi

    # Pull container images
    log_info "Pulling required container images..."
    local pull_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: kubeadm config images pull"
        if pull_output=$(kubeadm config images pull 2>&1); then
            log_success "Container images pulled successfully"
            log_debug "$pull_output"
        else
            log_warning "Some container images may not have been pulled"
            log_warning "Warning details: $pull_output"
        fi
    else
        if pull_output=$(kubeadm config images pull 2>&1); then
            log_success "Container images pulled successfully"
        else
            log_warning "Some container images may not have been pulled"
            log_warning "Warning details: $pull_output"
        fi
    fi

    # Generate cluster configuration
    log_info "Generating cluster configuration..."
    if [ -f "$WORKING_DIR/cluster-config-master.yaml" ]; then
        envsubst <"$WORKING_DIR/cluster-config-master.yaml" >"$WORKING_DIR/config.yaml"
        log_success "Cluster configuration generated"
    else
        log_warning "Using default cluster configuration"
    fi

    # Initialize the cluster
    log_info "Initializing Kubernetes cluster (this may take several minutes)..."

    local init_cmd="kubeadm init"
    if [ -f "$WORKING_DIR/config.yaml" ]; then
        init_cmd="$init_cmd --config=$WORKING_DIR/config.yaml"
    fi
    init_cmd="$init_cmd --upload-certs"

    local init_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Executing: sudo $init_cmd"
        log_debug "This will initialize the control plane and may take 5-10 minutes..."
        if init_output=$(sudo $init_cmd 2>&1); then
            log_success "Kubernetes cluster initialized successfully"
            log_debug "$init_output"
        else
            log_error "Kubernetes cluster initialization failed"
            log_error "Error details: $init_output"
            log_info "Troubleshooting commands:"
            log_info "  sudo journalctl -xeu kubelet"
            log_info "  sudo kubeadm reset -f (to reset and try again)"
            return 1
        fi
    else
        if init_output=$(sudo $init_cmd 2>&1); then
            log_success "Kubernetes cluster initialized successfully"
        else
            log_error "Kubernetes cluster initialization failed"
            log_error "Error details: $init_output"
            log_info "Troubleshooting commands:"
            log_info "  sudo journalctl -xeu kubelet"
            log_info "  sudo kubeadm reset -f (to reset and try again)"
            return 1
        fi
    fi

    # Setup kubectl configuration
    log_info "Setting up kubectl configuration..."
    export KUBECONFIG=/etc/kubernetes/admin.conf
    mkdir -p "$HOME/.kube"

    local config_output
    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Copying admin.conf to ~/.kube/config"
        log_debug "Setting proper ownership and permissions..."
        if config_output=$(sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config" 2>&1 && sudo chown $(id -u):$(id -g) "$HOME/.kube/config" 2>&1); then
            log_success "Kubectl configuration completed"
            log_debug "Config location: $HOME/.kube/config"
            [[ -n "$config_output" ]] && log_debug "$config_output"
        else
            log_error "Failed to setup kubectl configuration"
            log_error "Error details: $config_output"
            return 1
        fi
    else
        if config_output=$(sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config" 2>&1 && sudo chown $(id -u):$(id -g) "$HOME/.kube/config" 2>&1); then
            log_success "Kubectl configuration completed"
        else
            log_error "Failed to setup kubectl configuration"
            log_error "Error details: $config_output"
            return 1
        fi
    fi

    # Configure master node (remove taints for single-node scheduling)
    log_info "Configuring master node for pod scheduling..."

    # Remove the taint to allow scheduling on master node
    local taint_output
    if taint_output=$(kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>&1); then
        log_success "Master node configured for pod scheduling"
        if [[ "$verbose_mode" == "true" ]] && [[ -n "$taint_output" ]]; then
            log_debug "Taint removal output: $taint_output"
        fi
    else
        # Check if taint was already removed
        if [[ "$taint_output" == *"not found"* ]]; then
            log_info "Master node taint already removed - node ready for scheduling"
        else
            log_warning "Master node taint removal failed: $taint_output"
            log_info "Master node may not schedule pods. Manual fix: kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
        fi
    fi

    # Install Calico network plugin
    log_info "Installing Calico network plugin..."

    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Installing container networking for pod communication..."
    fi

    # Check if Calico is already installed
    if kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | grep -q "Running"; then
        log_info "Calico appears to be already running - skipping installation"
    else
        # Install Calico network plugin
        local calico_version="v3.25.1"
        local calico_manifest="https://raw.githubusercontent.com/projectcalico/calico/$calico_version/manifests/calico.yaml"

        log_substep "Applying Calico network plugin..."
        local calico_apply_output
        if [[ "$verbose_mode" == "true" ]]; then
            log_debug "Executing: kubectl create -f $calico_manifest"
            if calico_apply_output=$(kubectl create -f "$calico_manifest" 2>&1); then
                log_success "Calico manifest applied successfully"
                log_debug "$calico_apply_output"
            else
                log_warning "Failed to apply Calico manifest"
                log_warning "Error details: $calico_apply_output"
                log_warning "You may need to install a network plugin manually"
            fi
        else
            if calico_apply_output=$(kubectl create -f "$calico_manifest" 2>&1); then
                log_success "Calico manifest applied successfully"
            else
                log_warning "Failed to apply Calico manifest"
                log_warning "You may need to install a network plugin manually"
            fi
        fi

        # Wait briefly for Calico pods to start
        log_substep "Waiting for Calico pods to start..."
        sleep 15

        # Get Calico pod status
        local pod_output
        pod_output=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null || true)

        local ready_pods=0
        local total_pods=0

        if [[ -n "$pod_output" ]]; then
            total_pods=$(echo "$pod_output" | wc -l)
            ready_pods=$(echo "$pod_output" | grep -c "Running" 2>/dev/null)
            ready_pods=${ready_pods:-0}
        fi

        if [[ "$ready_pods" -gt 0 ]]; then
            log_success "Calico network plugin is starting ($ready_pods/$total_pods pods running)"
        else
            log_info "Calico pods are initializing (this may take 1-2 minutes)"
        fi
    fi

    # Validate cluster is running
    log_info "Validating cluster status..."
    sleep 10  # Give cluster time to start

    if [[ "$verbose_mode" == "true" ]]; then
        log_debug "Checking cluster connectivity and status..."
        if kubectl cluster-info; then
            log_success "Kubernetes cluster is running and accessible"
            log_debug "Checking node status:"
            kubectl get nodes
            log_debug "Checking system pods:"
            kubectl get pods -n kube-system
        else
            log_error "Cluster validation failed"
            return 1
        fi
    else
        if kubectl cluster-info >/dev/null 2>&1; then
            log_success "Kubernetes cluster is running and accessible"
        else
            log_error "Cluster validation failed"
            return 1
        fi
    fi

    log_component_success "kubernetes" "Kubernetes master installation completed"
}

# Setup Kubernetes worker node
setup_kubernetes_worker() {
    local verbose_mode="${1:-false}"

    log_step "6" "Setting up Kubernetes worker node"

    # Disable swap
    log_info "Disabling swap for Kubernetes..."
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    sudo swapoff -a
    log_success "Swap disabled successfully"

    # Create kubelet service file (required for modern Kubernetes)
    log_info "Setting up kubelet systemd service..."
    if ! systemctl list-unit-files kubelet.service >/dev/null 2>&1; then
        log_substep "Creating base kubelet.service file (missing from kubelet package)"
        
        # Create the base kubelet.service file
        sudo tee /lib/systemd/system/kubelet.service > /dev/null << 'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Reload systemd to recognize the new service
        sudo systemctl daemon-reload
        log_success "Base kubelet.service file created"
    fi
    
    # Now enable the kubelet service
    log_info "Enabling kubelet service..."
    if sudo systemctl enable kubelet >/dev/null 2>&1; then
        log_success "Kubelet service enabled"
    else
        log_warning "Kubelet service enable failed"
    fi

    log_component_success "kubernetes-worker" "Kubernetes worker setup completed"
    log_info "To join this node to a cluster, run the 'kubeadm join' command from the master"
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
        
        # Show comprehensive installation summary
        show_component_summary "helm"
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
    log_substep "Creating Docker data directory"
    if ! mkdir -p /var/lib/docker; then
        log_error "Failed to create Docker data directory"
        return 1
    fi
    
    if ! mkdir -p /var/lib/docker/tmp; then
        log_error "Failed to create Docker tmp directory"
        return 1
    fi
    
    if ! chown root:root /var/lib/docker; then
        log_error "Failed to set ownership on Docker data directory"
        return 1
    fi
    
    if ! chmod 755 /var/lib/docker; then
        log_error "Failed to set permissions on Docker data directory"
        return 1
    fi
    
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
    # log_component_start "ingress" "Installing NGINX Ingress Controller"
    
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm is required before installing Ingress Controller"
        return 1
    fi
    
    log_info "Installing NGINX Ingress Controller..."
    
    # Create namespace
    ensure_namespace "ingress-nginx"
    
    # Add ingress-nginx repository if not already added
    log_info "Adding Nginx Ingress Helm repository"
    execute_with_suppression helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    execute_with_suppression helm repo update

    helm_install_with_summary "ingress-nginx" "ingress-nginx" \
        ingress-nginx ingress-nginx/ingress-nginx --version 4.12.1 \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.nodePorts.http=80 \
        --set controller.service.nodePorts.https=443 \
        --set controller.service.type=NodePort \
        --set defaultBackend.enabled=true \
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

    # Validate API_SERVERS format and count
    local server_count=$(echo "$API_SERVERS" | tr ',' '\n' | wc -l)
    if [[ $server_count -lt 2 ]]; then
        log_warning "Only $server_count API server configured - HA proxy is recommended for 2+ servers"
        log_info "Current API_SERVERS: $API_SERVERS"
    else
        log_success "Multiple API servers detected ($server_count servers) - HA setup recommended"
        log_info "API servers: $API_SERVERS"
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
        execute_controlled "Stopping existing HAProxy container" "docker stop master-proxy"
    fi
    
    if docker ps -a -q -f name=master-proxy | grep -q .; then
        execute_controlled "Removing existing HAProxy container" "docker rm master-proxy"
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
        log stdout local0
        log stdout local1 notice
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
        
frontend k8s-api-frontend
        bind *:$HA_PROXY_PORT
        mode tcp
        option tcplog
        default_backend k8s-api-backend

backend k8s-api-backend
        mode tcp
        balance roundrobin
        option tcp-check
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
    
    if ! docker_pull_controlled "haproxy:latest"; then
        log_error "Failed to pull HAProxy Docker image"
        return 1
    fi
    
    log_success "HAProxy image pulled successfully"
    
    # Step 5: Start HAProxy container
    log_step "5 Starting HAProxy container"
    
    if ! docker_run_controlled "Running HAProxy container with host networking" \
        "-d --name master-proxy \
        --restart=unless-stopped \
        -v /opt/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
        --net=host \
        haproxy:latest"; then
        log_error "Failed to start HAProxy container"
        return 1
    fi
    
    log_success "HAProxy container started successfully"
    
    # Step 6: Validate installation
    log_step "6 Validating HA proxy installation"
    
    # Wait a moment for container to start
    sleep 3
    
    if validate_ha_proxy_installation; then
        log_success "HA proxy installation validation passed"
    else
        log_error "HA proxy installation validation failed"
        return 1
    fi
    
    # Show comprehensive installation summary
    show_component_summary "haproxy"
    
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