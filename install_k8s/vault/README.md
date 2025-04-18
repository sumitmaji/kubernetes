# Process of retrieving secret from vault

When a secret from HashiCorp Vault is mounted on a Kubernetes pod, the process involves several components working together to securely retrieve the secret from Vault and make it available to the pod. Below is a detailed explanation of how this works:

---

### **1. Overview**
The secret is mounted into the pod as a file using the **Secrets Store CSI Driver** and the **Vault provider**. The CSI Driver dynamically fetches the secret from Vault at runtime and makes it available to the pod as a volume.

---

### **2. Components Involved**
1. **HashiCorp Vault**:
   - Stores the secret securely.
   - Provides APIs to retrieve the secret.
   - Uses Kubernetes authentication to validate which pods can access which secrets.

2. **Secrets Store CSI Driver**:
   - A Kubernetes-native mechanism that integrates external secret stores (like Vault) with Kubernetes.
   - Dynamically fetches secrets from Vault and mounts them as volumes in pods.

3. **Vault Provider for CSI Driver**:
   - An extension of the CSI Driver that enables it to communicate with HashiCorp Vault specifically.

4. **Kubernetes Service Account**:
   - Used by the pod to authenticate with Vault.
   - Vault validates the service account token to ensure the pod is authorized to access the secret.

5. **SecretProviderClass**:
   - A Kubernetes resource that defines how the CSI Driver should retrieve the secret from Vault (e.g., Vault address, role, secret path).

---

### **3. Step-by-Step Process**

#### **Step 1: Pod Starts**
- A pod is created in Kubernetes with a volume that uses the **Secrets Store CSI Driver**.
- The pod specifies a `SecretProviderClass` that defines how to retrieve the secret from Vault.

#### **Step 2: Service Account Token**
- The pod uses a Kubernetes **service account** to authenticate with Vault.
- The service account token is automatically mounted into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`.

#### **Step 3: CSI Driver Requests the Secret**
- The Secrets Store CSI Driver reads the `SecretProviderClass` associated with the pod.
- The CSI Driver uses the service account token to authenticate with Vault via the Kubernetes authentication method (`v1/auth/kubernetes/login`).

#### **Step 4: Vault Authenticates the Pod**
- Vault validates the service account token by calling the Kubernetes **TokenReview API**.
- Vault checks if the service account and namespace match the **role** configuration in Vault.
- If the authentication is successful, Vault issues a **client token** to the CSI Driver.

#### **Step 5: CSI Driver Fetches the Secret**
- The CSI Driver uses the client token to request the secret from Vault.
- The secret is retrieved from the specified path in Vault (e.g., `secret/data/my-secret`).

#### **Step 6: Secret is Mounted into the Pod**
- The Secrets Store CSI Driver mounts the secret into the pod as a file in the specified volume path (e.g., `/mnt/secrets-store`).
- The secret is now available to the application running in the pod.

---

### **4. Example Workflow**

#### **Vault Configuration**
1. Store a secret in Vault:
   ```bash
   vault kv put secret/my-secret username="my-username" password="my-password"
   ```

2. Create a Vault role:
   ```bash
   vault write auth/kubernetes/role/my-role \
       bound_service_account_names=vault-auth \
       bound_service_account_namespaces=default \
       policies=my-policy \
       ttl=24h
   ```

3. Create a Vault policy:
   ```hcl
   path "secret/data/my-secret" {
     capabilities = ["read"]
   }
   ```

#### **Kubernetes Configuration**
1. Create a `SecretProviderClass`:
   ```yaml
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: vault-secret-provider
     namespace: default
   spec:
     provider: vault
     parameters:
       vaultAddress: "https://vault.example.com"
       roleName: "my-role"
       objects: |
         - objectName: "my-secret"
           secretPath: "secret/data/my-secret"
           secretKey: "username"
   ```

2. Create a pod that uses the `SecretProviderClass`:
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: vault-secret-pod
     namespace: default
   spec:
     serviceAccountName: vault-auth
     containers:
     - name: app
       image: nginx
       volumeMounts:
       - name: secrets-store-inline
         mountPath: "/mnt/secrets-store"
         readOnly: true
     volumes:
     - name: secrets-store-inline
       csi:
         driver: secrets-store.csi.k8s.io
         readOnly: true
         volumeAttributes:
           secretProviderClass: "vault-secret-provider"
   ```

---

### **5. Security Considerations**
- **Authentication**:
  - Vault uses Kubernetes service account tokens to authenticate pods.
  - Only authorized pods can access specific secrets based on Vault roles and policies.

- **Dynamic Secrets**:
  - Secrets are not hardcoded into the application or Kubernetes manifests.
  - Secrets can be updated in Vault without requiring changes to the pod.

- **Access Control**:
  - Vault policies ensure fine-grained access control to secrets.
  - Only specific service accounts and namespaces can access specific secrets.

---

### **6. Benefits of Using Vault with CSI Driver**
1. **Centralized Secret Management**:
   - Secrets are stored and managed centrally in Vault, ensuring consistency and security.

2. **Dynamic Secret Retrieval**:
   - Secrets are dynamically fetched at runtime, reducing the risk of stale or outdated secrets.

3. **Seamless Integration**:
   - The Secrets Store CSI Driver integrates seamlessly with Kubernetes, making it easy to mount secrets into pods.

4. **Improved Security**:
   - Secrets are not stored in Kubernetes manifests or ConfigMaps, reducing the risk of accidental exposure.

---

### **7. Summary**
- The Secrets Store CSI Driver and Vault provider enable Kubernetes pods to securely retrieve secrets from Vault.
- The process involves Kubernetes service accounts, Vault roles, and policies to ensure only authorized pods can access specific secrets.
- Secrets are dynamically fetched and mounted into pods as files, providing a secure and scalable solution for secret management in Kubernetes.


# Mounting Secrets from Vault into Kubernetes Pods

This guide explains the steps required to securely retrieve and mount secrets from HashiCorp Vault into Kubernetes pods using the Secrets Store CSI Driver.

---

## Steps to Mount Secrets into a Pod

### 1. Install the Secrets Store CSI Driver and Vault Provider

#### Why This Step is Needed
- The **Secrets Store CSI Driver** is a Kubernetes-native mechanism that allows secrets from external secret stores (like Vault) to be mounted as volumes in Kubernetes pods.
- The **Vault provider** is an extension of the CSI Driver that enables it to communicate with HashiCorp Vault specifically.
- Without the CSI Driver and Vault provider, Kubernetes cannot directly interact with Vault to retrieve secrets.

#### What It Does
- The CSI Driver acts as a bridge between Kubernetes and Vault.
- It dynamically fetches secrets from Vault and mounts them into pods as files.

#### Code Snippets

Install the Secrets Store CSI Driver:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/rbac-secretproviderclass.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/csi-secrets-store.yaml
```

Install the Vault provider for the CSI Driver:
```bash
kubectl apply -f https://raw.githubusercontent.com/hashicorp/secrets-store-csi-driver-provider-vault/main/deployment/provider-vault-installer.yaml
```
---

### 2. Configure Vault with Kubernetes Authentication, a Role, a Policy, and the Secret

#### Why This Step is Needed
- Vault needs to authenticate Kubernetes pods securely to ensure that only authorized pods can access specific secrets.
- The **Kubernetes authentication method** allows Vault to validate Kubernetes service account tokens.
- The **role** maps Kubernetes service accounts and namespaces to Vault policies.
- The **policy** defines what secrets the authenticated pod can access.
- The **secret** is the actual data stored in Vault that the pod needs.

#### What It Does
- **Kubernetes Authentication**: Enables Vault to validate Kubernetes service account tokens using the Kubernetes API.
- **Role**: Maps Kubernetes service accounts to Vault policies, ensuring only specific pods can access specific secrets.
- **Policy**: Grants fine-grained access control to secrets stored in Vault.
- **Secret**: Stores sensitive data (e.g., API keys, passwords) securely in Vault.

#### Code Snippets

Enable Kubernetes authentication in Vault:
```bash
vault auth enable kubernetes
```

Configure Kubernetes authentication in Vault:
```bash
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://<KUBERNETES_API_SERVER>" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

Create a Vault role:
```bash
vault write auth/kubernetes/role/my-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=default \
    policies=my-policy \
    ttl=24h
```

Create a Vault policy:
```bash
vault policy write my-policy - <<EOF
path "secret/data/my-secret" {
  capabilities = ["read"]
}
EOF
```

Store a secret in Vault:
```bash
vault kv put secret/my-secret username="my-username" password="my-password"
```

---

### 3. Create a Kubernetes Service Account and Bind it to the `system:auth-delegator` Role

#### Why This Step is Needed
- The Kubernetes service account is used by the pod to authenticate with Vault.
- The `system:auth-delegator` role is required to allow Vault to perform **TokenReview API calls**. These calls validate the service account token presented by the pod.

#### What It Does
- The service account provides the pod with a token that Vault can validate.
- The `system:auth-delegator` role allows Vault to verify the authenticity of the service account token by calling the Kubernetes API.

#### Code Snippets

Create a Kubernetes service account:
```bash
kubectl create serviceaccount vault -n vault
```

Bind the service account to the system:auth-delegator role:
```bash
kubectl create clusterrolebinding vault-auth-delegator \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault:vault
```

---

### 4. Create a SecretProviderClass to Define How the Secret is Retrieved from Vault

#### Why This Step is Needed
- The `SecretProviderClass` is a Kubernetes resource that tells the Secrets Store CSI Driver how to retrieve secrets from Vault.
- It specifies:
  - The Vault server address.
  - The Vault role to use for authentication.
  - The path to the secret in Vault.
  - The specific keys within the secret to retrieve.

#### What It Does
- The `SecretProviderClass` acts as a configuration file for the CSI Driver.
- It ensures that the correct secret is retrieved from Vault and made available to the pod.

#### Code Snippets

Create a `SecretProviderClass`:
```bash
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-secret-provider
  namespace: default
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.gokcloud.com"
    roleName: "my-role"
    objects: |
      - objectName: "my-secret"
        secretPath: "secret/data/my-secret"
        secretKey: "username"
```
---

### 5. Create a Pod that Mounts the Secret Using the SecretProviderClass

#### Why This Step is Needed
- The pod is the application that needs access to the secret.
- By mounting the secret as a volume, the application running in the pod can securely access the secret without hardcoding it into the application or storing it in an insecure location.

#### What It Does
- The pod uses the `SecretProviderClass` to dynamically fetch the secret from Vault.
- The secret is mounted into the pod as a file, making it accessible to the application.


#### Code Snippets

Create a pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-secret-pod
  namespace: default
spec:
  serviceAccountName: vault-auth
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secrets-store-inline
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
  - name: secrets-store-inline
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "vault-secret-provider"
```

Apply the pod configuration:
```bash
kubectl apply -f pod.yaml
```
---

### 6. Verify that the Secret is Successfully Mounted into the Pod

#### Why This Step is Needed
- Verifying the secret ensures that the entire process (from Vault configuration to pod mounting) is working correctly.
- It helps identify any issues with authentication, permissions, or configuration.

#### What It Does
- Confirms that the secret is successfully retrieved from Vault and mounted into the pod.
- Ensures that the application can access the secret as expected.

#### Code Snippets

Verify the secret is mounted:
```bash
kubectl exec -it vault-secret-pod -n default -- ls /mnt/secrets-store
```

View the contents of the secret:
```bash
kubectl exec -it vault-secret-pod -n default -- cat /mnt/secrets-store/username
```
---

## Why These Steps Are Necessary

### Security
- Secrets are stored securely in Vault and are not hardcoded into application code or Kubernetes manifests.
- Only authorized pods can access specific secrets, thanks to the combination of Kubernetes authentication, Vault roles, and policies.

### Dynamic Secret Management
- Secrets can be updated in Vault without requiring changes to the Kubernetes pod or application.
- The CSI Driver dynamically fetches the latest version of the secret when the pod starts.

### Separation of Concerns
- Developers can focus on building applications without worrying about how secrets are managed.
- Operations teams can manage secrets centrally in Vault.

### Compliance
- Centralized secret management in Vault ensures compliance with security policies and audit requirements.
- Access to secrets is logged and can be audited.

### Scalability
- The Secrets Store CSI Driver integrates seamlessly with Kubernetes, making it easy to scale secret management across multiple pods and clusters.

---

## Summary

These steps are necessary to securely retrieve and mount secrets from Vault into Kubernetes pods. Each step ensures that:
- Secrets are stored securely in Vault.
- Only authorized pods can access specific secrets.
- Secrets are dynamically fetched and mounted into pods as needed.

By following these steps, you can ensure secure, scalable, and compliant secret management in Kubernetes.

# Checklist for Policy, Role and Kubernetes authentication configuration

When configuring Vault to work with Kubernetes, it is essential to verify the **policy**, **role**, and **Kubernetes authentication configuration** to ensure everything is set up correctly. Below is a checklist of things to verify for each component:

---

### **1. Vault Policy**
The policy defines what secrets the authenticated entity (e.g., a pod) can access and what actions it can perform.

#### **Things to Verify**
1. **Path Configuration**:
   - Ensure the `path` matches the actual location of the secret in Vault.
   - For KV v2 secrets, include the `data/` prefix (e.g., `secret/data/my-secret`).
   - For KV v1 secrets, do not include the `data/` prefix (e.g., `secret/my-secret`).

2. **Capabilities**:
   - Ensure the policy includes the correct capabilities:
     - `read`: Allows reading the secret.
     - `list`: Allows listing secrets (useful for debugging or dynamic secret paths).
     - `create`, `update`, or `delete`: If required for specific use cases.

3. **Policy Name**:
   - Ensure the policy name matches the one referenced in the Vault role.

#### **Commands to Verify**
- View the policy:
  ```bash
  vault policy read <policy-name>
  ```
- Example output:
  ```hcl
  path "secret/data/my-secret" {
    capabilities = ["read", "list"]
  }
  ```

---

### **2. Vault Role**
The role maps Kubernetes service accounts and namespaces to Vault policies. It ensures that only authorized pods can access specific secrets.

#### **Things to Verify**
1. **Bound Service Account Names**:
   - Ensure the `bound_service_account_names` field includes the correct Kubernetes service account(s) that the pod is using.

2. **Bound Service Account Namespaces**:
   - Ensure the `bound_service_account_namespaces` field includes the correct namespace(s) where the pod is running.

3. **Policies**:
   - Ensure the `policies` field includes the correct Vault policy name(s) that grant access to the required secrets.

4. **TTL (Time-to-Live)**:
   - Ensure the `ttl` and `max_ttl` values are appropriate for your use case.

#### **Commands to Verify**
- View the role:
  ```bash
  vault read auth/kubernetes/role/<role-name>
  ```
- Example output:
  ```
  Key                                 Value
  ---                                 -----
  bound_service_account_names         [vault-auth]
  bound_service_account_namespaces    [default]
  policies                            [my-policy]
  ttl                                 24h
  ```

---

### **3. Kubernetes Authentication Configuration**
The Kubernetes authentication configuration in Vault allows Vault to validate Kubernetes service account tokens by communicating with the Kubernetes API server.

#### **Things to Verify**
1. **Kubernetes Host**:
   - Ensure the `kubernetes_host` field points to the correct Kubernetes API server URL.
   - Example: `https://<KUBERNETES_API_SERVER>`.

2. **Kubernetes CA Certificate**:
   - Ensure the `kubernetes_ca_cert` field contains the correct Kubernetes CA certificate.
   - This is required for Vault to securely communicate with the Kubernetes API server.

3. **Token Reviewer JWT**:
   - Ensure the `token_reviewer_jwt` is valid and comes from a service account with the `system:auth-delegator` role.
   - This allows Vault to perform `TokenReview` API calls to validate service account tokens.

4. **Token Reviewer Permissions**:
   - Ensure the service account used by Vault has the `system:auth-delegator` role bound via a `ClusterRoleBinding`.

#### **Commands to Verify**
- View the Kubernetes authentication configuration:
  ```bash
  vault read auth/kubernetes/config
  ```
- Example output:
  ```
  Key                                  Value
  ---                                  -----
  kubernetes_host                      https://<KUBERNETES_API_SERVER>
  kubernetes_ca_cert                   -----BEGIN CERTIFICATE-----
  ...
  -----END CERTIFICATE-----
  token_reviewer_jwt_set               true
  ```

- Verify the `ClusterRoleBinding` for the token reviewer:
  ```bash
  kubectl get clusterrolebinding vault-auth-delegator -o yaml
  ```
- Example output:
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: vault-auth-delegator
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: system:auth-delegator
  subjects:
  - kind: ServiceAccount
    name: vault
    namespace: vault
  ```

---

### **4. Debugging Tips**
If something is not working as expected, check the following:

#### **Vault Logs**
- Check the Vault server logs for errors related to Kubernetes authentication or secret access:
  ```bash
  kubectl logs vault-0 -n vault
  ```

#### **Secrets Store CSI Driver Logs**
- If using the Secrets Store CSI Driver, check its logs for errors:
  ```bash
  kubectl logs -n kube-system -l app=secrets-store-csi-driver
  ```

#### **Test Authentication**
- Manually test authentication with Vault using the Kubernetes service account token:
  ```bash
  TOKEN=$(kubectl exec -it <pod-name> -n <namespace> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl --request POST --data "{\"jwt\": \"$TOKEN\", \"role\": \"<role-name>\"}" https://<VAULT_ADDRESS>/v1/auth/kubernetes/login
  ```

#### **Verify Secret Access**
- Test if the authenticated token can access the secret:
  ```bash
  vault kv get secret/my-secret
  ```

---

### **Summary**
To ensure everything is configured correctly in Vault:
1. **Policy**:
   - Verify the secret path and capabilities.
   - Ensure the policy name matches the one referenced in the role.

2. **Role**:
   - Verify the bound service account names and namespaces.
   - Ensure the role references the correct policy.

3. **Kubernetes Authentication Configuration**:
   - Verify the Kubernetes API server URL and CA certificate.
   - Ensure the token reviewer JWT is valid and has the necessary permissions.

By verifying these components, you can ensure that Vault is correctly configured to authenticate Kubernetes pods and provide access to the required secrets.


# Verify
Execute below command to verify vault setup
```bash
cd $MOUNT_PATH/kubernetes/install_k8s/
source gok
verifyVault
debugVault
```