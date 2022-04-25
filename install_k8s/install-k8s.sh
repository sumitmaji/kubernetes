#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

# Enable kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Add some settings to sysctl
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system


echo "Installing docker"
apt-get update
apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
        "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
        $(lsb_release -cs) \
        stable"

apt-get update && apt-get install -y \
        docker-ce=$(apt-cache madison docker-ce | grep 20.10 | head -1 | awk '{print $3}')


# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
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

# Start and enable Services
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker


echo "Installing Kubernetes"
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl

kubeadm version
kubeadm config images pull

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

sudo systemctl enable kubelet

envsubst < $WORKING_DIR/cluster-config-master.yaml > $WORKING_DIR/config.yaml
kubeadm init --config=$WORKING_DIR/config.yaml
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
echo << "EOF"
\______   |  |   ____ _____    ______ ____   __  _  ______  |___/  |_  _/ _______________  /_   |   _____ |__| ____
 |     ___|  | _/ __ \\__  \  /  ____/ __ \  \ \/ \/ \__  \ |  \   __\ \   __/  _ \_  __ \  |   |  /     \|  |/    \
 |    |   |  |_\  ___/ / __ \_\___ \\  ___/   \     / / __ \|  ||  |    |  |(  <_> |  | \/  |   | |  Y Y  |  |   |  \
 |____|   |____/\___  (____  /____  >\___  >   \/\_/ (____  |__||__|    |__| \____/|__|     |___| |__|_|  |__|___|  / /\
                    \/     \/     \/     \/               \/                                            \/        \/  \/
EOF
