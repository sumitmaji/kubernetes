# 🌐 Remote VM Command Execution Guide

This guide shows you how to execute commands on remote VMs from your local environment using various methods, including the enhanced GOK script.

## 🚀 **Method 1: Using Enhanced GOK Script (Recommended)**

The GOK script now includes built-in remote execution capabilities:

### **Setup Remote Hosts**
```bash
# Add your Kubernetes master node
gok remote add master 192.168.1.100 ubuntu

# Add worker nodes  
gok remote add node1 192.168.1.101 ubuntu
gok remote add node2 192.168.1.102 ubuntu

# List configured hosts
gok remote list
```

### **Execute Commands**
```bash
# Execute on specific host
gok remote exec master "kubectl get nodes"
gok remote exec node1 "systemctl status kubelet"

# Execute on all configured hosts
gok remote exec all "docker ps"
gok remote exec all "systemctl status docker"

# Check system status of all hosts
gok remote status

# Copy files to remote hosts
gok remote copy master ./script.sh /tmp/script.sh
gok remote copy node1 ./config.yaml /etc/app/config.yaml

# Install GOK on remote hosts
gok remote install-gok all
```

### **Advanced Remote Operations**
```bash
# Deploy Kubernetes components remotely
gok remote exec master "gok install kubernetes"
gok remote exec all "gok install docker"

# Check cluster status across all nodes
gok remote exec all "kubectl get pods --all-namespaces"

# Restart services on all nodes
gok remote exec all "sudo systemctl restart kubelet"
```

## 🔧 **Method 2: Direct SSH (Traditional)**

### **Setup SSH Keys**
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to remote VMs
ssh-copy-id ubuntu@192.168.1.100
ssh-copy-id ubuntu@192.168.1.101
ssh-copy-id ubuntu@192.168.1.102
```

### **SSH Config Setup**
Create `~/.ssh/config`:
```bash
Host k8s-master
    HostName 192.168.1.100
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    Port 22
    StrictHostKeyChecking no

Host k8s-node1
    HostName 192.168.1.101
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    
Host k8s-node2
    HostName 192.168.1.102
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
```

### **Execute Commands**
```bash
# Single commands
ssh k8s-master "kubectl get nodes"
ssh k8s-node1 "systemctl status kubelet"

# Multiple commands
ssh k8s-master "
    kubectl get nodes
    kubectl get pods --all-namespaces
    kubectl cluster-info
"

# Execute local script on remote host
ssh k8s-master 'bash -s' < local-script.sh

# Execute with sudo
ssh k8s-master "sudo systemctl restart kubelet"
```

## 🤖 **Method 3: Ansible for Advanced Automation**

### **Install Ansible**
```bash
sudo apt update
sudo apt install ansible -y
```

### **Create Inventory**
Create `inventory.ini`:
```ini
[k8s-masters]
k8s-master ansible_host=192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-workers]
k8s-node1 ansible_host=192.168.1.101 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
k8s-node2 ansible_host=192.168.1.102 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-cluster:children]
k8s-masters
k8s-workers
```

### **Run Ansible Commands**
```bash
# Test connectivity
ansible all -i inventory.ini -m ping

# Run commands on all hosts
ansible all -i inventory.ini -m shell -a "kubectl get nodes"
ansible all -i inventory.ini -m shell -a "systemctl status docker"

# Run commands on specific groups
ansible k8s-masters -i inventory.ini -m shell -a "kubeadm token list"
ansible k8s-workers -i inventory.ini -m shell -a "systemctl status kubelet"

# Copy files
ansible all -i inventory.ini -m copy -a "src=./script.sh dest=/tmp/script.sh mode=0755"

# Install packages
ansible all -i inventory.ini -m apt -a "name=htop state=present" --become
```

### **Ansible Playbook Example**
Create `deploy-k8s.yml`:
```yaml
---
- name: Deploy Kubernetes Cluster
  hosts: k8s-cluster
  become: yes
  tasks:
    - name: Update system packages
      apt:
        update_cache: yes
        upgrade: yes
    
    - name: Install Docker
      shell: |
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        usermod -aG docker {{ ansible_user }}
    
    - name: Install kubectl on masters
      shell: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        mv kubectl /usr/local/bin/
      when: inventory_hostname in groups['k8s-masters']
```

Run playbook:
```bash
ansible-playbook -i inventory.ini deploy-k8s.yml
```

## 🔐 **Method 4: Secure Execution with Bastion Host**

For production environments with bastion hosts:

### **SSH Config with Jump Host**
```bash
Host bastion
    HostName bastion.company.com
    User ubuntu
    IdentityFile ~/.ssh/bastion-key

Host k8s-master
    HostName 10.0.1.100
    User ubuntu
    IdentityFile ~/.ssh/internal-key
    ProxyJump bastion

Host k8s-node*
    HostName 10.0.1.%h
    User ubuntu
    IdentityFile ~/.ssh/internal-key
    ProxyJump bastion
```

### **Execute Through Bastion**
```bash
# Direct command through bastion
ssh k8s-master "kubectl get nodes"

# Using GOK with bastion (modify SSH command in remote_exec function)
gok remote add master 10.0.1.100 ubuntu ~/.ssh/internal-key
```

## 📊 **Method 5: Kubernetes-Native Remote Execution**

For pods/containers within Kubernetes:

```bash
# Execute in specific pod
kubectl exec -it pod-name -- /bin/bash
kubectl exec pod-name -- kubectl get nodes

# Execute in pod on specific node
kubectl exec -it pod-name -n namespace -- command

# Copy files to/from pods
kubectl cp local-file pod-name:/path/to/file
kubectl cp pod-name:/path/to/file local-file
```

## 🛠️ **Troubleshooting Remote Connections**

### **Common Issues and Solutions**

1. **Permission Denied**
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# Verify SSH agent
ssh-add ~/.ssh/id_rsa
```

2. **Connection Timeout**
```bash
# Test basic connectivity
ping 192.168.1.100
telnet 192.168.1.100 22

# Check SSH service
ssh -v user@host
```

3. **Host Key Verification Failed**
```bash
# Remove old host key
ssh-keygen -R 192.168.1.100

# Manually accept new key
ssh -o StrictHostKeyChecking=no user@host
```

4. **GOK Remote Issues**
```bash
# Show configured hosts
gok remote list

# Test individual host connectivity
ssh -i ~/.ssh/id_rsa -o ConnectTimeout=5 user@host "echo test"

# Reconfigure host
gok remote add host-alias 192.168.1.100 ubuntu ~/.ssh/id_rsa
```

## 🎯 **Best Practices**

1. **Security**
   - Use SSH keys instead of passwords
   - Disable root SSH access when possible
   - Use bastion hosts for production
   - Regularly rotate SSH keys

2. **Efficiency**
   - Use SSH config for common hosts
   - Set up SSH multiplexing for faster connections
   - Use parallel execution for multiple hosts

3. **Monitoring**
   - Log all remote executions
   - Use descriptive aliases for hosts
   - Test connectivity before bulk operations

4. **Error Handling**
   - Always check exit codes
   - Use timeout values for connections
   - Have fallback methods for critical operations

## 🚀 **Quick Start Examples**

### **Setup and Deploy Kubernetes Cluster**
```bash
# Configure remote hosts
gok remote add master 192.168.1.100 ubuntu
gok remote add node1 192.168.1.101 ubuntu

# Install Docker on all hosts
gok remote exec all "curl -fsSL https://get.docker.com | sh"
gok remote exec all "sudo usermod -aG docker ubuntu"

# Install Kubernetes on master
gok remote exec master "gok install kubernetes"

# Get join command and execute on workers
JOIN_CMD=$(gok remote exec master "kubeadm token create --print-join-command")
gok remote exec node1 "sudo $JOIN_CMD"

# Verify cluster
gok remote exec master "kubectl get nodes"
```

### **Monitoring and Maintenance**
```bash
# Check system status
gok remote status

# Update all systems
gok remote exec all "sudo apt update && sudo apt upgrade -y"

# Restart services
gok remote exec all "sudo systemctl restart docker kubelet"

# Check logs
gok remote exec all "sudo journalctl -u kubelet -n 50"
```

This comprehensive guide gives you multiple options for remote command execution, from simple SSH commands to advanced automation with Ansible and the enhanced GOK script capabilities!