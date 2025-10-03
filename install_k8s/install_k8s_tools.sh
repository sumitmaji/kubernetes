#!/bin/bash

# Kubernetes Tools Installation Script
# This script installs kubectl, Docker, and Helm on Linux systems
# Supports Ubuntu/Debian and RHEL/CentOS/Fedora distributions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "This script is running as root. Some operations may not work as expected."
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Detect OS distribution
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS distribution"
        exit 1
    fi
    
    log_info "Detected OS: $OS $VER"
}

# Update package manager
update_packages() {
    log_info "Updating package manager..."
    
    case $OS in
        ubuntu|debian)
            sudo apt-get update -y
            sudo apt-get install -y curl wget apt-transport-https ca-certificates gnupg lsb-release
            ;;
        rhel|centos|fedora|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                sudo dnf update -y
                sudo dnf install -y curl wget ca-certificates gnupg
            else
                sudo yum update -y
                sudo yum install -y curl wget ca-certificates
            fi
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    log_success "Package manager updated"
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_warning "Docker is already installed: $(docker --version)"
        return 0
    fi
    
    case $OS in
        ubuntu|debian)
            # Remove old versions
            sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Update package index
            sudo apt-get update -y
            
            # Install Docker Engine
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        rhel|centos|fedora|rocky|almalinux)
            # Remove old versions
            sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
            
            # Install yum-utils
            if command -v dnf &> /dev/null; then
                sudo dnf install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            else
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;
    esac
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group
    if [[ $EUID -ne 0 ]]; then
        sudo usermod -aG docker $USER
        log_warning "Added $USER to docker group. You may need to log out and back in for this to take effect."
    fi
    
    log_success "Docker installed successfully: $(docker --version)"
}

# Install kubectl
install_kubectl() {
    log_info "Installing kubectl..."
    
    # Check if kubectl is already installed
    if command -v kubectl &> /dev/null; then
        log_warning "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi
    
    # Get the latest stable version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    log_info "Installing kubectl version: $KUBECTL_VERSION"
    
    # Download kubectl binary
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    
    # Validate the binary (optional)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Install kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
    # Clean up
    rm -f kubectl.sha256
    
    log_success "kubectl installed successfully: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Install Helm
install_helm() {
    log_info "Installing Helm..."
    
    # Check if Helm is already installed
    if command -v helm &> /dev/null; then
        log_warning "Helm is already installed: $(helm version --short)"
        return 0
    fi
    
    # Download and install Helm
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    
    # Clean up
    rm -f get_helm.sh
    
    log_success "Helm installed successfully: $(helm version --short)"
}

# Verify installations
verify_installations() {
    log_info "Verifying installations..."
    
    local all_good=true
    
    # Check Docker
    if command -v docker &> /dev/null; then
        log_success "Docker: $(docker --version)"
        
        # Test Docker (if not root and user is in docker group)
        if [[ $EUID -ne 0 ]] && groups $USER | grep -q docker; then
            if docker run --rm hello-world &>/dev/null; then
                log_success "Docker is working correctly"
            else
                log_warning "Docker is installed but may not be working properly"
            fi
        fi
    else
        log_error "Docker installation failed"
        all_good=false
    fi
    
    # Check kubectl
    if command -v kubectl &> /dev/null; then
        log_success "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    else
        log_error "kubectl installation failed"
        all_good=false
    fi
    
    # Check Helm
    if command -v helm &> /dev/null; then
        log_success "Helm: $(helm version --short)"
    else
        log_error "Helm installation failed"
        all_good=false
    fi
    
    if $all_good; then
        log_success "All tools installed successfully!"
        echo
        log_info "Next steps:"
        echo "1. If you added your user to the docker group, log out and back in"
        echo "2. Configure kubectl with your cluster: kubectl config set-cluster ..."
        echo "3. Test Docker: docker run hello-world"
        echo "4. Test Helm: helm list"
    else
        log_error "Some installations failed. Please check the logs above."
        exit 1
    fi
}

# Main installation function
main() {
    log_info "Starting Kubernetes tools installation..."
    echo "This script will install:"
    echo "- Docker (Container runtime)"
    echo "- kubectl (Kubernetes command-line tool)"
    echo "- Helm (Package manager for Kubernetes)"
    echo
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled."
        exit 0
    fi
    
    check_root
    detect_os
    update_packages
    install_docker
    install_kubectl
    install_helm
    verify_installations
    
    log_success "Installation completed!"
}

# Run main function
main "$@"