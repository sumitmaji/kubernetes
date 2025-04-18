# Docker Installation Guide

This document outlines the steps for installing Docker as a prerequisite for Kubernetes.

## Prerequisites
1. **System Update**:
   - Ensure the system is updated before installing Docker.
   - Command: `apt-get update`

2. **Install Required Packages**:
   - Install packages required for Docker installation:
     - `apt-transport-https`
     - `ca-certificates`
     - `curl`
     - `software-properties-common`
   - Command:
     ```bash
     apt-get install -y apt-transport-https ca-certificates curl software-properties-common
     ```

3. **Add Docker GPG Key**:
   - Add the official Docker GPG key to the system.
   - Command:
     ```bash
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
     ```

4. **Add Docker Repository**:
   - Add the Docker repository to the system's package sources.
   - Command:
     ```bash
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
     ```

## Installation Steps
1. **Install Docker**:
   - Install Docker and its related components:
     - `docker-ce`
     - `docker-ce-cli`
     - `containerd.io`
     - `docker-buildx-plugin`
     - `docker-compose-plugin`
   - Command:
     ```bash
     apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
     ```

2. **Configure Docker Daemon**:
   - Create a configuration file for Docker to use `systemd` as the cgroup driver.
   - Command:
     ```bash
     sudo tee /etc/docker/daemon.json <<EOF
     {
       "exec-opts": ["native.cgroupdriver=systemd"],
       "log-driver": "json-file",
       "log-opts": {
         "max-size": "100m"
       },
       "storage-driver": "overlay2"
     }
     EOF
     ```

3. **Enable and Start Docker Services**:
   - Reload systemd and restart Docker services.
   - Commands:
     ```bash
     sudo systemctl daemon-reload
     sudo systemctl restart docker
     sudo systemctl enable docker
     ```

4. **Configure Containerd**:
   - Remove the default containerd configuration and restart the service.
   - Commands:
     ```bash
     sudo rm /etc/containerd/config.toml
     sudo systemctl restart containerd
     sudo systemctl enable containerd
     ```

## Post-Installation Steps
1. **Verify Docker Installation**:
   - Check the Docker version to ensure it is installed correctly.
   - Command: `docker --version`

2. **Test Docker**:
   - Run a test container to verify Docker is working.
   - Command: `docker run hello-world`

## Notes
- The script assumes an Ubuntu-based Linux distribution.
- Ensure you have root or sudo privileges to execute the commands.
- The Docker installation is configured to use `systemd` as the cgroup driver, which is required for Kubernetes compatibility.

For further details, refer to the script located at `/home/sumit/Documents/repository/kubernetes/install_k8s/gok`.