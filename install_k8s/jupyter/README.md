# **Documentation: Installing JupyterHub on Kubernetes**

This guide provides step-by-step instructions to install **JupyterHub** on a Kubernetes cluster using Helm and the gok script.

---

## **Prerequisites**
Before installing JupyterHub, ensure the following prerequisites are met:

1. **Kubernetes Cluster**:
   - A running Kubernetes cluster with sufficient resources.
   - `kubectl` configured to interact with the cluster.

2. **Helm**:
   - Helm installed and configured to manage Kubernetes applications.
   - Install Helm if not already installed:
     ```bash
     curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
     ```

3. **Ingress Controller**:
   - An ingress controller (e.g., NGINX) installed and configured in the cluster.

4. **Persistent Storage**:
   - Ensure a storage class is available for persistent volumes.

5. **OpenSSL**:
   - OpenSSL installed for generating secrets.

6. **gok Script**:
   - The gok script is available and executable in your environment.
   - Source the gok script:
     ```bash
     source /path/to/gok
     ```

---

## **Step 1: Install JupyterHub Using the gok Script**

1. **Run the gok Command**:
   Use the following command to install JupyterHub:
   ```bash
   gok install jupyter
   ```

2. **What Happens During Installation**:
   - The `jupyterHubInst` function in the gok script is executed.
   - It performs the following steps:
     - Adds the JupyterHub Helm repository.
     - Creates the required storage classes and persistent volumes for JupyterHub and user data.
     - Creates a namespace for JupyterHub (`jupyterhub`).
     - Generates a random secret token for the JupyterHub proxy.
     - Configures OAuth2 authentication (if enabled) using Keycloak or another identity provider.
     - Installs JupyterHub using Helm with the specified configuration.
     - Waits for the JupyterHub pods to become ready.
     - Patches the JupyterHub ingress with Let's Encrypt for TLS certificates.

3. **Verify Installation**:
   - Once the installation is complete, you can access JupyterHub at:
     ```plaintext
     https://<jupyterhub-subdomain>.<root-domain>
     ```
   - Replace `<jupyterhub-subdomain>` and `<root-domain>` with the appropriate values configured in your environment.

---

## **Step 2: Uninstall JupyterHub Using the gok Script**

1. **Run the gok Command**:
   Use the following command to uninstall JupyterHub:
   ```bash
   gok reset jupyter
   ```

2. **What Happens During Uninstallation**:
   - The `jupyterHubReset` function in the gok script is executed.
   - It performs the following steps:
     - Uninstalls the JupyterHub Helm release.
     - Deletes the `hub-secret` and all pods, PVCs, and other resources in the `jupyterhub` namespace.
     - Deletes the persistent volumes and storage classes created for JupyterHub and user data.
     - Deletes the `jupyterhub` namespace.

3. **Verify Uninstallation**:
   - Ensure that all JupyterHub-related resources have been removed:
     ```bash
     kubectl get all -n jupyterhub
     ```
   - The output should indicate that no resources exist in the `jupyterhub` namespace.

---

## **Manual Installation Steps (Optional)**

If you prefer to install JupyterHub manually without using the gok script, follow these steps:

### **1. Add the JupyterHub Helm Repository**
Add the official JupyterHub Helm chart repository and update it:
```bash
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update
```

### **2. Create Persistent Volumes**
Create storage classes and persistent volumes for JupyterHub and user data:
```bash
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: jupyter-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jupyter-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: jupyter-storage
  local:
    path: /data/volumes/jupyter
EOF
```

### **3. Create a Namespace for JupyterHub**
Create a dedicated namespace for JupyterHub:
```bash
kubectl create namespace jupyterhub
```

### **4. Generate a Secret Token**
Generate a secret token for JupyterHub:
```bash
JUPYTERHUB_SECRET=$(openssl rand -hex 32)
kubectl create secret generic hub-secret \
  --from-literal=hub-secret-key="${JUPYTERHUB_SECRET}" \
  --namespace jupyterhub
```

### **5. Install JupyterHub**
Install JupyterHub using Helm:
```bash
helm install jupyterhub jupyterhub/jupyterhub \
  --namespace jupyterhub \
  --set proxy.secretToken="${JUPYTERHUB_SECRET}" \
  --values /path/to/values.yaml
```

### **6. Configure Ingress**
Patch the JupyterHub ingress to use TLS and Let's Encrypt:
```bash
kubectl patch ingress jupyterhub --namespace jupyterhub --patch "$(
  cat <<EOF
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - jupyterhub.example.com
      secretName: jupyterhub-tls
EOF
)"
```

---

## **Summary of Commands**

| **Command**                  | **Description**                                      |
|-------------------------------|-----------------------------------------------------|
| `gok install jupyter`         | Installs JupyterHub on the Kubernetes cluster.      |
| `gok reset jupyter`           | Uninstalls JupyterHub and cleans up related resources. |

---

## **Troubleshooting**
- **Pods Not Ready**:
  - Check the logs of the JupyterHub pods:
    ```bash
    kubectl logs -n jupyterhub <pod-name>
    ```

- **Ingress Not Working**:
  - Verify the ingress configuration:
    ```bash
    kubectl describe ingress jupyterhub -n jupyterhub
    ```

- **OAuth2 Issues**:
  - Ensure the OAuth2 provider is correctly configured and reachable.

---

This documentation now includes the use of the gok script for automating the installation and uninstallation of JupyterHub, along with manual installation steps for reference.