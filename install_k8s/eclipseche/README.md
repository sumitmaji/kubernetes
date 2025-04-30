# **Documentation: Installing Eclipse Che on Kubernetes**

This guide provides step-by-step instructions to install **Eclipse Che**, a cloud-based integrated development environment (IDE), on a Kubernetes cluster. It also includes how to use the gok script to automate the installation and uninstallation of Eclipse Che.

---

## **Prerequisites**
Before installing Eclipse Che, ensure the following prerequisites are met:

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

5. **OIDC Provider**:
   - An OIDC provider (e.g., Keycloak) configured for authentication.

6. **Chectl**:
   - Install `chectl`, the CLI tool for managing Eclipse Che:
     ```bash
     npm install -g @che-incubator/chectl
     ```

7. **gok Script**:
   - The gok script is available and executable in your environment.
   - Source the gok script:
     ```bash
     source /path/to/gok
     ```

---

## **Installing Eclipse Che Using the gok Script**

1. **Run the gok Command**:
   Use the following command to install Eclipse Che:
   ```bash
   gok install che
   ```

2. **What Happens During Installation**:
   - The `eclipseCheInst` function in the gok script is executed.
   - It performs the following steps:
     - Fetches the OIDC client secret and other required parameters from the Kubernetes secret.
     - Creates a storage class and persistent volume for Eclipse Che.
     - Installs `chectl`, the CLI tool for managing Eclipse Che.
     - Creates a patch file (`che-patch.yaml`) to configure the CheCluster with OIDC authentication and storage settings.
     - Deploys Eclipse Che using `chectl` with the specified configuration.

3. **Verify Installation**:
   - Once the installation is complete, you can access Eclipse Che at:
     ```plaintext
     https://che.<your-domain>
     ```
   - Replace `<your-domain>` with the appropriate domain configured in your environment.

---

## **Uninstalling Eclipse Che Using the gok Script**

1. **Run the gok Command**:
   Use the following command to uninstall Eclipse Che:
   ```bash
   gok reset che
   ```

2. **What Happens During Uninstallation**:
   - The `resetEclipseChe` function in the gok script is executed.
   - It performs the following steps:
     - Deletes all Eclipse Che deployments and resources in the `eclipse-che` namespace.
     - Deletes the `eclipse-che` namespace.
     - Removes the persistent volumes and storage classes created for Eclipse Che.

3. **Verify Uninstallation**:
   - Ensure that all Eclipse Che-related resources have been removed:
     ```bash
     kubectl get all -n eclipse-che
     ```
   - The output should indicate that no resources exist in the `eclipse-che` namespace.

---

## **Manual Installation Steps (Optional)**

If you prefer to install Eclipse Che manually without using the gok script, follow these steps:

### **1. Add the Eclipse Che Helm Repository**
Add the official Eclipse Che Helm chart repository and update it:
```bash
helm repo add eclipse-che https://eclipse-che.github.io/che-operator/helm/
helm repo update
```

### **2. Create Persistent Volumes**
Create storage classes and persistent volumes for Eclipse Che:
```bash
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: eclipse-che-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: eclipse-che-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: eclipse-che-storage
  local:
    path: /data/volumes/eclipse-che
EOF
```

### **3. Create a Namespace for Eclipse Che**
Create a dedicated namespace for Eclipse Che:
```bash
kubectl create namespace eclipse-che
```

### **4. Configure OIDC Authentication**
If you are using an OIDC provider (e.g., Keycloak), configure the following:

1. Fetch the OIDC client details:
   ```bash
   CLIENT_SECRET=$(kubectl get secret oauth-secrets -n kube-system -o jsonpath="{['data']['OIDC_CLIENT_SECRET']}" | base64 --decode)
   CLIENT_ID=$(kubectl get secret oauth-secrets -n kube-system -o jsonpath="{['data']['OIDC_CLIENT_ID']}" | base64 --decode)
   REALM=$(kubectl get secret oauth-secrets -n kube-system -o jsonpath="{['data']['OAUTH_REALM']}" | base64 --decode)
   ```

2. Save these details for use in the installation command.

### **5. Install Eclipse Che**
Install Eclipse Che using `chectl`:

1. Create a patch file for the CheCluster configuration:
   ```bash
   cat > che-patch.yaml << EOF
kind: CheCluster
apiVersion: org.eclipse.che/v2
spec:
  devEnvironments:
    storage:
      perUserStrategyPvcConfig:
        claimSize: 2Gi
        storageClass: eclipse-che-storage
      pvcStrategy: per-user
  networking:
    auth:
      oAuthClientName: ${CLIENT_ID}
      oAuthSecret: ${CLIENT_SECRET}
      identityProviderURL: "https://keycloak.example.com/realms/${REALM}"
      gateway:
        oAuthProxy:
          cookieExpireSeconds: 300
  components:
    cheServer:
      extraProperties:
        CHE_OIDC_USERNAME__CLAIM: email
        CHE_OIDC_SKIP_CERTIFICATE_VERIFICATION: "true"
EOF
   ```

2. Deploy Eclipse Che using `chectl`:
   ```bash
   chectl server:deploy --platform k8s --domain che.example.com --che-operator-cr-patch-yaml che-patch.yaml --skip-cert-manager
   ```

---

## **Summary of Commands**

| **Command**                  | **Description**                                      |
|-------------------------------|-----------------------------------------------------|
| `gok install che`             | Installs Eclipse Che on the Kubernetes cluster.     |
| `gok reset che`               | Uninstalls Eclipse Che and cleans up related resources. |

---

## **Troubleshooting**
- **Pods Not Ready**:
  - Check the logs of the Eclipse Che pods:
    ```bash
    kubectl logs -n eclipse-che <pod-name>
    ```

- **Ingress Not Working**:
  - Verify the ingress configuration:
    ```bash
    kubectl describe ingress che -n eclipse-che
    ```

- **OIDC Issues**:
  - Ensure the OIDC provider is correctly configured and reachable.

---

This documentation now includes the use of the gok script for automating the installation and uninstallation of Eclipse Che, along with manual installation steps for reference.

# Note

The current removal of eclipse che does not stop all the pods, so after executing `gok reset che` follow below steps

1. Open a new tab and login to box.
2. change the namespace to `eclipse-che`
3. stop the running containers
  ```console
    kubectl delete deployment --all
  ``

If you delete the workspace from eclipse-che, the `persistance volument` will not be freed from the previous claim, to make it available follow below steps

1. Edit the `persistance volume`
  ```console
    kubectl edit pv eclipse-che-pv
  ``` 
2. Remove the tag `claimRef`
  ```yaml
    claimRef:
      apiVersion: v1
      kind: PersistentVolumeClaim
      name: claim-devworkspace
      namespace: skmaji1-outlook-com-che-x4x051
      resourceVersion: "5663200"
      uid: 4e5d4d41-f91a-4bc0-b863-2dd064335c3d

  ```