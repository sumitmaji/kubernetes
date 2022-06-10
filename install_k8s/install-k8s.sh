#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

#Install network tools
apt-get install net-tools


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

#Installing haproxy
./install_haproxy.sh


echo "Installing Kubernetes"
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
#Kubernets version 1.24.0 is working properly, downgrading to 1.23.0
apt-get install -qy kubelet=1.23.0-00 kubeadm=1.23.0-00 kubectl=1.23.0-00 --allow-downgrades

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

alias kcd='kubectl config set-context $(kubectl config current-context) --namespace'

#Adding custom dns server
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cloud.uat in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
    cloud.com:53 {
        errors
        cache 30
        forward . 11.0.0.1
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
EOF

kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

: ${IP:=$(ifconfig eth0 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
if [ -z "$IP" ]; then
    : ${IP:=$(ifconfig enp0s8 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
fi
JSONPATH="{.items[?(@.status.addresses[0].address == \"${IP}\")].metadata.name}"
NODE_NAME="$(kubectl get nodes -o jsonpath="$JSONPATH")"
kubectl taint node ${NODE_NAME} node-role.kubernetes.io/master:NoSchedule-



#Installing helm
curl https://baltocdn.com/helm/signing.asc | apt-key add - \
&& apt-get install apt-transport-https --yes \
&& echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
&& apt-get update \
&& apt-get install helm \
&& helm version --short \
&& helm repo add stable https://charts.helm.sh/stable

#Creating user role developers which would allow users authenticated with oauth and
#having developers role to connect with cluster
cat <<EOF | kubectl create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

#Creating user role administrators which would allow users authenticated with oauth and
#having administrators role to connect with cluster
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oauth-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: administrators
EOF



kubectl config set-cluster cloud.com --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true --server=https://192.168.43.23:6443 --kubeconfig=/root/oauth.conf
kubectl config --kubeconfig=/root/oauth.conf set-context oauthuser@cloud.com --cluster=cloud.com --user=oauthuser
kubectl config --kubeconfig=/root/oauth.conf use-context oauthuser@cloud.com

echo "OAuth kubeconfig file create in /root/oauth.conf"
echo "Use below command to use oauth.conf"
echo "kubectl --kubeconfig=/root/oauth.conf --token=__USER_TOKEN__ rest of command"
echo "alias kctl='kubectl --kubeconfig=/root/oauth.conf --token=\${__USER_TOKEN__}'"
echo "alias kcd='kctl config set-context \$(kctl config current-context) --namespace'"


echo "alias kcd='kubectl config set-context \$(kubectl config current-context) --namespace'" >> /root/.bashrc

chmod 766 /root/oauth.conf

#Installing python
apt-get install python3
apt-get install python3-pip

cat << EOF
\______   |  |   ____ _____    ______ ____   __  _  ______  |___/  |_  _/ _______________  /_   |   _____ |__| ____
 |     ___|  | _/ __ \\__  \  /  ____/ __ \  \ \/ \/ \__  \ |  \   __\ \   __/  _ \_  __ \  |   |  /     \|  |/    \
 |    |   |  |_\  ___/ / __ \_\___ \\  ___/   \     / / __ \|  ||  |    |  |(  <_> |  | \/  |   | |  Y Y  |  |   |  \
 |____|   |____/\___  (____  /____  >\___  >   \/\_/ (____  |__||__|    |__| \____/|__|     |___| |__|_|  |__|___|  / /\
                    \/     \/     \/     \/               \/                                            \/        \/  \/
EOF
