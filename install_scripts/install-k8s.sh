#!/bin/bash

echo "Installing docker"
apt-get update
apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-ket add -
add-apt-repository \
        "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
        $(lsb_release -cs) \
        stable"

apt-get update && apt-get install -y \
        docker-ce=$(apt-cache madison docker-ce | grep 18.06 | head -1 | awk '{print $3}')

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
sudo swapoff -a

echo "Deploying kubernetes with flannel......"
sysctl net.bridge.bridge-nf-call-iptables=1
kubeadm init --pod-network-cidr=192.168.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
echo << "EOF"
\______   |  |   ____ _____    ______ ____   __  _  ______  |___/  |_  _/ _______________  /_   |   _____ |__| ____
 |     ___|  | _/ __ \\__  \  /  ____/ __ \  \ \/ \/ \__  \ |  \   __\ \   __/  _ \_  __ \  |   |  /     \|  |/    \
 |    |   |  |_\  ___/ / __ \_\___ \\  ___/   \     / / __ \|  ||  |    |  |(  <_> |  | \/  |   | |  Y Y  |  |   |  \
 |____|   |____/\___  (____  /____  >\___  >   \/\_/ (____  |__||__|    |__| \____/|__|     |___| |__|_|  |__|___|  / /\
                    \/     \/     \/     \/               \/                                            \/        \/  \/
EOF