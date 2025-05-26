# cluster-config-master.yaml Documentation

This file is a **Kubeadm ClusterConfiguration** manifest for bootstrapping a Kubernetes control plane node (master) with OIDC authentication and RBAC enabled.

---

## Purpose

- **Defines cluster-wide settings** for the Kubernetes control plane.
- **Enables OIDC authentication** for integration with external identity providers (e.g., Keycloak, Auth0, Google).
- **Configures RBAC** and other security and networking options.
- **Customizes API server, controller manager, etcd, and networking.**

---

## Key Sections

### `apiVersion` and `kind`
```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
```
Specifies this is a kubeadm cluster configuration file.

---

### `certificatesDir` and `clusterName`
```yaml
certificatesDir: /etc/kubernetes/pki
clusterName: ${CLUSTER_NAME}
```
- Sets the directory for cluster certificates.
- Sets the cluster name (from environment variable).

---

### `apiServer`
Configures the Kubernetes API server.

#### **SANs**
```yaml
certSANs:
  - "master.cloud.com"
  - "${MASTER_HOST_IP}"
```
- Adds extra Subject Alternative Names for the API server certificate.

#### **extraArgs**
```yaml
extraArgs:
  authorization-mode: Node,RBAC
  service-node-port-range: 80-32767
  oidc-issuer-url: ${OIDC_ISSUE_URL}
  oidc-client-id: ${OIDC_CLIENT_ID}
  oidc-username-claim: ${OIDC_USERNAME_CLAIM}
  oidc-groups-claim: ${OIDC_GROUPS_CLAIM}
#  enable-swagger-ui: "true"
```
- **authorization-mode:** Enables Node and RBAC authorization.
- **service-node-port-range:** Sets the range for NodePort services.
- **oidc-issuer-url:** URL of your OIDC provider (e.g., Keycloak, Auth0, Google).
- **oidc-client-id:** OIDC client ID for Kubernetes API server.
- **oidc-username-claim:** JWT claim to use as the username (e.g., `sub` or `preferred_username`).
- **oidc-groups-claim:** JWT claim to use for group membership (e.g., `groups`).
- **enable-swagger-ui:** (commented) Optionally enable the API server Swagger UI.

#### **timeoutForControlPlane**
```yaml
timeoutForControlPlane: 4m0s
```
- Sets the timeout for control plane operations.

---

### `controllerManager`
```yaml
controllerManager:
  extraArgs:
    attach-detach-reconcile-sync-period: 1m0s
    configure-cloud-routes: "false"
```
- Customizes controller manager behavior.

---

### `dns`, `etcd`, `controlPlaneEndpoint`, `kubernetesVersion`, `networking`
- **dns:** DNS settings for the cluster.
- **etcd:** Local etcd data directory.
- **controlPlaneEndpoint:** The endpoint for the control plane (usually a load balancer).
- **kubernetesVersion:** Version of Kubernetes to deploy.
- **networking:** DNS domain, pod subnet, and service subnet.

---

### `KubeletConfiguration`
```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: "systemd"
```
- Sets the kubelet cgroup driver to `systemd` for compatibility with most modern Linux distributions.

---

## OIDC Integration

To enable OIDC authentication:
- Set the following environment variables before running `kubeadm init`:
  - `OIDC_ISSUE_URL` (e.g., `https://keycloak.example.com/auth/realms/myrealm`)
  - `OIDC_CLIENT_ID` (e.g., `kubernetes`)
  - `OIDC_USERNAME_CLAIM` (e.g., `preferred_username`)
  - `OIDC_GROUPS_CLAIM` (e.g., `groups`)
- These will be substituted into the config.

**This allows Kubernetes to use external identity providers for authentication and group-based RBAC.**

---

## Usage

1. Fill in or export the required environment variables.
2. Run `kubeadm init --config cluster-config-master.yaml` to bootstrap your control plane node.

---

## Example

```sh
export OIDC_ISSUE_URL="https://keycloak.example.com/auth/realms/myrealm"
export OIDC_CLIENT_ID="kubernetes"
export OIDC_USERNAME_CLAIM="preferred_username"
export OIDC_GROUPS_CLAIM="groups"
export CLUSTER_NAME="mycluster"
export MASTER_HOST_IP="10.0.0.1"
export LOAD_BALANCER_URL="10.0.0.100:6443"
export DNS_DOMAIN="cluster.local"

kubeadm init --config cluster-config-master.yaml
```

---

## References

- [Kubeadm ClusterConfiguration docs](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/)
- [Kubernetes OIDC Auth](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)

---