# Kubernetes Installation Guide

This document provides a detailed guide for installing Kubernetes using the `k8sInst` function.

## Prerequisites

Before running the script, ensure the following:

1. **Operating System**: Linux-based OS (e.g., Ubuntu).
2. **Root or Sudo Access**: Administrative privileges are required.
3. **Container Runtime**: `containerd` is used as the container runtime.
4. **Network Configuration**: Ensure proper network connectivity for downloading dependencies.

---

## Steps Performed by `k8sInst`

### 1. Enable Kernel Modules
The script enables necessary kernel modules for Kubernetes networking.

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

### 2. Configure sysctl Settings
The script updates system configurations to enable IP forwarding and bridge networking.

```bash
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

### 3. Load Containerd Modules
The script ensures that `overlay` and `br_netfilter` modules are loaded for `containerd`.

```bash
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sysctl --system
```

### 4. Configure Containerd
The script generates a default configuration for `containerd` and updates it to use the `systemd` cgroup driver.

```bash
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
```

### 5. Install Kubernetes Components
The script installs `kubectl`, `kubeadm`, and `kubelet`.

```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl kubeadm kubelet
```

### 6. Disable Swap
Kubernetes requires swap to be disabled.

```bash
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
```

### 7. Initialize Kubernetes Master Node
If the script is run with the `kubernetes` argument, it initializes the master node.

```bash
kubeadm version
kubeadm config images pull

sudo systemctl enable kubelet

envsubst <"$WORKING_DIR"/cluster-config-master.yaml >"$WORKING_DIR"/config.yaml
kubeadm init --config="$WORKING_DIR"/config.yaml --upload-certs
export KUBECONFIG=/etc/kubernetes/admin.conf

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config

# Check for errors
if [ $? -ne 0 ]; then
  echo "Kubectl command execution failed, please check!!!!!"
  exit 1
fi
```

### 8. Configure Worker Nodes
If the script is run with the `kubernetes-worker` argument, it prepares the worker node for joining the cluster.

```bash
cp /export/certs/issuer.crt /usr/local/share/ca-certificates/issuer.crt
update-ca-certificates
echo "kubectl join ...."
echo "kubectl label node node01 node-role.kubernetes.io/worker=worker"
echo "Reboot the VM to apply changes to CA certificates."
```

---

### 9. Install Helm
The script installs Helm, a package manager for Kubernetes.

```bash
curl https://baltocdn.com/helm/signing.asc | apt-key add -
apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
apt-get install helm
helm version --short
```

---

### 10. Taint Master Node
The script taints the master node to prevent workloads from being scheduled on it.

```bash
# Define a function to get the IP address
getIP() {
  ifconfig eth1 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://'
}

# Get the IP address
IP=$(getIP)

# If IP is empty, try another network interface
if [ -z "$IP" ]; then
  IP=$(ifconfig enp1s0.100 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')
fi

# If IP is still empty, print an error message and exit
if [ -z "$IP" ]; then
  echo "Error: Could not determine IP address"
  exit 1
fi

# Get the node name
JSONPATH="{.items[?(@.status.addresses[0].address == \"${IP}\")].metadata.name}"
NODE_NAME="$(kubectl get nodes -o jsonpath="$JSONPATH")"

# If node name is empty, print an error message and exit
if [ -z "$NODE_NAME" ]; then
  echo "Error: Could not determine node name"
  exit 1
fi

# Taint the node
kubectl taint node "${NODE_NAME}" node-role.kubernetes.io/control-plane:NoSchedule-
```

---

### 11. Install Calico Networking
The script installs Calico, a networking and network policy provider for Kubernetes.

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml

# Check for errors
if [ $? -ne 0 ]; then
  echo "Calico installation failed, please check!!!!!"
  exit 1
fi
```

---

### 12. Configure Custom DNS
The script configures a custom DNS server for the Kubernetes cluster.

```bash
# Adding custom DNS server
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
        forward . ${MASTER_HOST_IP}
    }
    gokcloud.com:53 {
        errors
        cache 30
        forward . ${MASTER_HOST_IP}
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
EOF

# Restart CoreDNS pods to apply the changes
kubectl delete pod --namespace kube-system -l k8s-app=kube-dns
```

---

## Configuration File: `cluster-config-master.yaml`

The `cluster-config-master.yaml` file is used during the initialization of the Kubernetes master node. It contains essential configurations for the cluster, such as API server settings, networking, and control plane parameters. The file is located at:

```
kubernetes/install_k8s/cluster-config-master.yaml
```

### Example Content of `cluster-config-master.yaml`

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
certificatesDir: /etc/kubernetes/pki
clusterName: ${CLUSTER_NAME}
apiServer:
  certSANs:
  - "master.cloud.com"
  - "${MASTER_HOST_IP}"
  extraArgs:
    authorization-mode: Node,RBAC
    service-node-port-range: 80-32767
    oidc-issuer-url: ${OIDC_ISSUE_URL}
    oidc-client-id: ${OIDC_CLIENT_ID}
    oidc-username-claim: ${OIDC_USERNAME_CLAIM}
    oidc-groups-claim: ${OIDC_GROUPS_CLAIM}
  timeoutForControlPlane: 4m0s
controllerManager:
  extraArgs:
    attach-detach-reconcile-sync-period: 1m0s
    configure-cloud-routes: "false"
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
controlPlaneEndpoint: ${LOAD_BALANCER_URL}
kubernetesVersion: v1.32.0
networking:
  dnsDomain: ${DNS_DOMAIN}
  podSubnet: 192.168.0.0/16
  serviceSubnet: 10.96.0.0/12

---

kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: "systemd"
```

### Key Fields in `cluster-config-master.yaml`

1. **`certificatesDir`**: Specifies the directory where Kubernetes stores certificates.
2. **`clusterName`**: The name of the Kubernetes cluster.
3. **`apiServer.certSANs`**: Defines additional Subject Alternative Names (SANs) for the API server certificate.
4. **`apiServer.extraArgs`**: Configures additional arguments for the API server, such as RBAC and OIDC settings.
5. **`controllerManager.extraArgs`**: Configures additional arguments for the controller manager.
6. **`etcd.local.dataDir`**: Specifies the directory where etcd data is stored.
7. **`controlPlaneEndpoint`**: The DNS or IP address of the load balancer for the control plane.
8. **`networking.podSubnet`**: Defines the CIDR block for pod IPs.
9. **`networking.serviceSubnet`**: Defines the CIDR block for service IPs.
10. **`kubelet.config.k8s.io/v1beta1.cgroupDriver`**: Specifies the cgroup driver for the kubelet.

---

## Environment Variables Used in `cluster-config-master.yaml`

The `cluster-config-master.yaml` file uses several environment variables to allow dynamic configuration. Below is a table listing these variables and their exact values as defined in the `config` and `gok` files:

| **Variable**          | **Description**                                      | **Value**                                                                 |
|------------------------|------------------------------------------------------|---------------------------------------------------------------------------|
| `${CLUSTER_NAME}`      | Specifies the name of the Kubernetes cluster.        | `cloud.com`                                                              |
| `${MASTER_HOST_IP}`    | The IP address of the master node.                   | Value derived dynamically using `ifconfig eth0` or `enp0s3`.             |
| `${OIDC_ISSUE_URL}`    | The URL of the OpenID Connect (OIDC) issuer.         | `https://keycloak.gokcloud.com/realms/GokDevelopers`                     |
| `${OIDC_CLIENT_ID}`    | The client ID for OIDC authentication.               | `gok-developers-client`                                                  |
| `${OIDC_USERNAME_CLAIM}`| The claim in the OIDC token that maps to the username.| `sub`                                                                    |
| `${OIDC_GROUPS_CLAIM}` | The claim in the OIDC token that maps to user groups.| `groups`                                                                 |
| `${LOAD_BALANCER_URL}` | The DNS or IP address of the load balancer.          | `${MASTER_HOST_IP}:6643`                                                 |
| `${DNS_DOMAIN}`        | The DNS domain for the Kubernetes cluster.           | `cloud.uat`                                                              |

---

## Notes

- The script uses `containerd` as the container runtime.
- It supports both master and worker node configurations.
- Ensure that the `cluster-config-master.yaml` file is properly configured before running the script for master node initialization.
- Ensure that the placeholders (e.g., `${CLUSTER_NAME}`, `${MASTER_HOST_IP}`) are replaced with actual values before running the script.
- The `controlPlaneEndpoint` should point to a load balancer if you are setting up a highly available cluster.
- Ensure that all environment variables are set before running the script.
- Use a `.env` file or export the variables in your shell session to simplify configuration.

---

## Troubleshooting

- If the script fails at any step, check the logs for errors.
- Ensure that all dependencies are installed and the system has internet access.

---