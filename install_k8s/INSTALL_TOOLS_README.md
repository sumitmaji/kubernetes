# Kubernetes Tools Installation Script

This script automates the installation of essential Kubernetes development tools:
- **Docker** - Container runtime
- **kubectl** - Kubernetes command-line tool
- **Helm** - Package manager for Kubernetes

## Features

- ✅ Supports multiple Linux distributions (Ubuntu, Debian, RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux)
- ✅ Automatic OS detection
- ✅ Latest stable version detection
- ✅ Proper error handling and logging
- ✅ Installation verification
- ✅ User-friendly colored output
- ✅ Safety checks (root user warning)

## Prerequisites

- Linux system (Ubuntu/Debian or RHEL/CentOS/Fedora family)
- Internet connection
- `curl` and `wget` (will be installed if missing)
- `sudo` privileges

## Usage

### Quick Installation

```bash
# Clone or download the script
wget https://raw.githubusercontent.com/your-repo/kubernetes/main/install_k8s_tools.sh

# Make it executable
chmod +x install_k8s_tools.sh

# Run the installation
./install_k8s_tools.sh
```

### From Local Repository

```bash
# Navigate to the kubernetes directory
cd /path/to/kubernetes

# Run the installation script
./install_k8s_tools.sh
```

## What the Script Does

### 1. Docker Installation
- Removes old Docker versions
- Adds official Docker repository
- Installs Docker CE with all plugins
- Starts and enables Docker service
- Adds current user to docker group (requires re-login)

### 2. kubectl Installation
- Downloads the latest stable kubectl version
- Verifies binary integrity with SHA256 checksum
- Installs to `/usr/local/bin/kubectl`
- Makes it available system-wide

### 3. Helm Installation
- Downloads and runs the official Helm installation script
- Installs Helm 3 (latest version)
- Installs to `/usr/local/bin/helm`

### 4. Verification
- Checks all installations
- Tests Docker functionality (if possible)
- Displays version information
- Provides next steps guidance

## Post-Installation Steps

### 1. Docker Setup
```bash
# Log out and back in to use Docker without sudo
# Or run: newgrp docker

# Test Docker
docker run hello-world
```

### 2. kubectl Configuration
```bash
# Configure kubectl for your cluster
kubectl config set-cluster my-cluster --server=https://k8s-api-server:6443
kubectl config set-credentials my-user --token=your-token
kubectl config set-context my-context --cluster=my-cluster --user=my-user
kubectl config use-context my-context

# Or copy existing kubeconfig
mkdir -p ~/.kube
cp /path/to/kubeconfig ~/.kube/config
```

### 3. Helm Setup
```bash
# Add popular Helm repositories
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# List available charts
helm search repo
```

## Supported Operating Systems

| OS Family | Distributions | Package Manager |
|-----------|--------------|----------------|
| Debian | Ubuntu 18.04+, Debian 9+ | apt |
| Red Hat | RHEL 7+, CentOS 7+, Fedora 30+ | yum/dnf |
| Rocky/Alma | Rocky Linux 8+, AlmaLinux 8+ | dnf |

## Troubleshooting

### Docker Issues
```bash
# If Docker service fails to start
sudo systemctl status docker
sudo journalctl -u docker

# Check if user is in docker group
groups $USER

# Restart Docker service
sudo systemctl restart docker
```

### kubectl Issues
```bash
# Check kubectl installation
which kubectl
kubectl version --client

# Check kubeconfig
kubectl config view
```

### Helm Issues
```bash
# Check Helm installation
which helm
helm version

# Initialize Helm (if needed for older versions)
helm repo add stable https://charts.helm.sh/stable
```

### Permission Issues
If you encounter permission issues:
```bash
# For Docker
sudo usermod -aG docker $USER
newgrp docker

# For kubectl/helm (if installed in wrong location)
sudo chown $USER:$USER /usr/local/bin/kubectl
sudo chown $USER:$USER /usr/local/bin/helm
```

## Security Considerations

- The script requires sudo privileges for system-wide installation
- Docker daemon runs as root (this is normal)
- Users are added to the docker group (equivalent to root access)
- Always verify scripts before running with elevated privileges

## Customization

You can modify the script to:
- Install specific versions by changing the version detection logic
- Add additional tools (kubectx, kubens, k9s, etc.)
- Change installation directories
- Add company-specific configurations

## License

This script is provided as-is for educational and development purposes.

## Contributing

Feel free to submit issues and pull requests to improve this installation script.