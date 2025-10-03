# Vault Integration Test Scripts# Process of retrieving secret from vault



This directory contains comprehensive test scripts for validating different Vault integration methods in Kubernetes. Each script automatically discovers configuration, creates test secrets, and verifies the integration is working correctly.When a secret from HashiCorp Vault is mounted on a Kubernetes pod, the process involves several components working together to securely retrieve the secret from Vault and make it available to the pod. Below is a detailed explanation of how this works:



## 📋 Test Scripts Overview---



### 1. **test_vault_agent_injector.sh** - Vault Agent Injector Test### **1. Overview**

Tests Vault's Agent Injector functionality where Vault automatically injects secrets into pods using init containers and sidecars.The secret is mounted into the pod as a file using the **Secrets Store CSI Driver** and the **Vault provider**. The CSI Driver dynamically fetches the secret from Vault at runtime and makes it available to the pod as a volume.



**What it tests:**---

- Creates test secrets in Vault with multiple key-value pairs

- Sets up Vault policies and Kubernetes authentication roles### **2. Components Involved**

- Creates a pod with Vault Agent Injector annotations1. **HashiCorp Vault**:

- Verifies secrets are mounted at `/vault/secrets/`   - Stores the secret securely.

- Validates secret content and format   - Provides APIs to retrieve the secret.

   - Uses Kubernetes authentication to validate which pods can access which secrets.

**Key Features:**

- Tests environment variable injection2. **Secrets Store CSI Driver**:

- Validates JSON templating   - A Kubernetes-native mechanism that integrates external secret stores (like Vault) with Kubernetes.

- Checks file-based secret access   - Dynamically fetches secrets from Vault and mounts them as volumes in pods.



### 2. **test_vault_csi.sh** - Vault CSI Driver Test3. **Vault Provider for CSI Driver**:

Tests the Secrets Store CSI Driver with Vault provider for mounting secrets as volumes.   - An extension of the CSI Driver that enables it to communicate with HashiCorp Vault specifically.



**What it tests:**4. **Kubernetes Service Account**:

- Creates test secrets in Vault with complex data types   - Used by the pod to authenticate with Vault.

- Creates SecretProviderClass for Vault integration   - Vault validates the service account token to ensure the pod is authorized to access the secret.

- Mounts secrets as CSI volumes in pods

- Synchronizes secrets to Kubernetes secrets5. **SecretProviderClass**:

- Tests environment variable injection from K8s secrets   - A Kubernetes resource that defines how the CSI Driver should retrieve the secret from Vault (e.g., Vault address, role, secret path).



**Key Features:**---

- CSI volume mounting

- Kubernetes secret synchronization### **3. Step-by-Step Process**

- File-based secret access

- Environment variable integration#### **Step 1: Pod Starts**

- A pod is created in Kubernetes with a volume that uses the **Secrets Store CSI Driver**.

### 3. **test_vault_api.sh** - Vault API Test- The pod specifies a `SecretProviderClass` that defines how to retrieve the secret from Vault.

Tests direct API access to Vault using Kubernetes authentication from within pods.

#### **Step 2: Service Account Token**

**What it tests:**- The pod uses a Kubernetes **service account** to authenticate with Vault.

- Kubernetes service account authentication to Vault- The service account token is automatically mounted into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`.

- Direct API calls to retrieve secrets

- Token management and renewal#### **Step 3: CSI Driver Requests the Secret**

- JSON parsing and data validation- The Secrets Store CSI Driver reads the `SecretProviderClass` associated with the pod.

- Python-based API client implementation- The CSI Driver uses the service account token to authenticate with Vault via the Kubernetes authentication method (`v1/auth/kubernetes/login`).



**Key Features:**#### **Step 4: Vault Authenticates the Pod**

- Programmatic API access- Vault validates the service account token by calling the Kubernetes **TokenReview API**.

- Token lifecycle management- Vault checks if the service account and namespace match the **role** configuration in Vault.

- Complex data type handling- If the authentication is successful, Vault issues a **client token** to the CSI Driver.

- Error handling and retry logic

#### **Step 5: CSI Driver Fetches the Secret**

## 🚀 Quick Start- The CSI Driver uses the client token to request the secret from Vault.

- The secret is retrieved from the specified path in Vault (e.g., `secret/data/my-secret`).

### Prerequisites

- Kubernetes cluster with Vault installed#### **Step 6: Secret is Mounted into the Pod**

- `kubectl` configured and connected to cluster- The Secrets Store CSI Driver mounts the secret into the pod as a file in the specified volume path (e.g., `/mnt/secrets-store`).

- `jq` installed for JSON processing- The secret is now available to the application running in the pod.

- Vault initialized with root token in `vault-init-keys` secret

---

### Running Tests

### **4. Example Workflow**

```bash

# Run all tests#### **Vault Configuration**

./test_vault_agent_injector.sh1. Store a secret in Vault:

./test_vault_csi.sh   ```bash

./test_vault_api.sh   vault kv put secret/my-secret username="my-username" password="my-password"

   ```

# Run specific test with verbose output

./test_vault_agent_injector.sh --verbose2. Create a Vault role:

   ```bash

# Clean up test resources   vault write auth/kubernetes/role/my-role \

./test_vault_agent_injector.sh --cleanup       bound_service_account_names=vault-auth \

./test_vault_csi.sh --cleanup       bound_service_account_namespaces=default \

./test_vault_api.sh --cleanup       policies=my-policy \

       ttl=24h

# Get help   ```

./test_vault_agent_injector.sh --help

```3. Create a Vault policy:

   ```hcl

## 📊 Test Scenarios   path "secret/data/my-secret" {

     capabilities = ["read"]

### Agent Injector Test Scenario   }

```   ```

┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐

│  Vault Server   │    │ Agent        │    │   Test Pod      │#### **Kubernetes Configuration**

│                 │    │ Injector     │    │                 │1. Create a `SecretProviderClass`:

│ secret/agent... │◄───┤ Init/Sidecar │◄───┤ /vault/secrets/ │   ```yaml

│                 │    │              │    │                 │   apiVersion: secrets-store.csi.x-k8s.io/v1

└─────────────────┘    └──────────────┘    └─────────────────┘   kind: SecretProviderClass

```   metadata:

     name: vault-secret-provider

**Created Resources:**     namespace: default

- Secret: `secret/agent-test`   spec:

- Policy: `agent-test-policy`     provider: vault

- Role: `agent-test-role`     parameters:

- ServiceAccount: `agent-test-sa`       vaultAddress: "https://vault.example.com"

- Pod: `vault-agent-test-pod`       roleName: "my-role"

       objects: |

**Test Data:**         - objectName: "my-secret"

```json           secretPath: "secret/data/my-secret"

{           secretKey: "username"

  "username": "agent-test-user",   ```

  "password": "agent-test-password",

  "database_url": "postgresql://localhost:5432/testdb",2. Create a pod that uses the `SecretProviderClass`:

  "api_key": "test-api-key-12345"   ```yaml

}   apiVersion: v1

```   kind: Pod

   metadata:

### CSI Driver Test Scenario     name: vault-secret-pod

```     namespace: default

┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐   spec:

│  Vault Server   │    │ CSI Driver   │    │   Test Pod      │     serviceAccountName: vault-auth

│                 │    │              │    │                 │     containers:

│ secret/csi...   │◄───┤ Volume Mount │◄───┤ /mnt/secrets/   │     - name: app

│                 │    │              │    │                 │       image: nginx

└─────────────────┘    └──────────────┘    └─────────────────┘       volumeMounts:

                              │       - name: secrets-store-inline

                              ▼         mountPath: "/mnt/secrets-store"

                       ┌──────────────┐         readOnly: true

                       │ K8s Secret   │     volumes:

                       │              │     - name: secrets-store-inline

                       │ vault-csi... │       csi:

                       └──────────────┘         driver: secrets-store.csi.k8s.io

```         readOnly: true

         volumeAttributes:

**Created Resources:**           secretProviderClass: "vault-secret-provider"

- Secret: `secret/csi-test`   ```

- Policy: `csi-test-policy`

- Role: `csi-test-role`---

- ServiceAccount: `csi-test-sa`

- SecretProviderClass: `vault-csi-test-provider`### **5. Security Considerations**

- Pod: `vault-csi-test-pod`- **Authentication**:

- K8s Secret: `vault-csi-secret`  - Vault uses Kubernetes service account tokens to authenticate pods.

  - Only authorized pods can access specific secrets based on Vault roles and policies.

**Test Data:**

```json- **Dynamic Secrets**:

{  - Secrets are not hardcoded into the application or Kubernetes manifests.

  "username": "csi-test-user",  - Secrets can be updated in Vault without requiring changes to the pod.

  "password": "csi-test-password",

  "database_url": "mysql://localhost:3306/testdb",- **Access Control**:

  "api_token": "csi-test-token-67890",  - Vault policies ensure fine-grained access control to secrets.

  "config_json": "{\"server\":\"https://api.example.com\",\"timeout\":30}"  - Only specific service accounts and namespaces can access specific secrets.

}

```---



### API Test Scenario### **6. Benefits of Using Vault with CSI Driver**

```1. **Centralized Secret Management**:

┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐   - Secrets are stored and managed centrally in Vault, ensuring consistency and security.

│  Vault Server   │    │              │    │   Python Pod    │

│                 │◄──────── HTTPS ───────┤                 │2. **Dynamic Secret Retrieval**:

│ secret/api...   │    │   API Call   │    │ requests lib    │   - Secrets are dynamically fetched at runtime, reducing the risk of stale or outdated secrets.

│                 │    │              │    │                 │

└─────────────────┘    └──────────────┘    └─────────────────┘3. **Seamless Integration**:

```   - The Secrets Store CSI Driver integrates seamlessly with Kubernetes, making it easy to mount secrets into pods.



**Created Resources:**4. **Improved Security**:

- Secret: `secret/api-test`   - Secrets are not stored in Kubernetes manifests or ConfigMaps, reducing the risk of accidental exposure.

- Policy: `api-test-policy`

- Role: `api-test-role`---

- ServiceAccount: `api-test-sa`

- ConfigMap: `vault-api-test-script`### **7. Summary**

- Pod: `vault-api-test-pod`- The Secrets Store CSI Driver and Vault provider enable Kubernetes pods to securely retrieve secrets from Vault.

- The process involves Kubernetes service accounts, Vault roles, and policies to ensure only authorized pods can access specific secrets.

**Test Data:**- Secrets are dynamically fetched and mounted into pods as files, providing a secure and scalable solution for secret management in Kubernetes.

```json

{

  "username": "api-test-user",# Mounting Secrets from Vault into Kubernetes Pods

  "password": "api-test-password",

  "database_host": "postgres.example.com",This guide explains the steps required to securely retrieve and mount secrets from HashiCorp Vault into Kubernetes pods using the Secrets Store CSI Driver.

  "database_port": "5432",

  "database_name": "api_test_db",---

  "api_endpoint": "https://api.example.com/v1",

  "api_key": "api-test-key-abcdef123456",## Steps to Mount Secrets into a Pod

  "config_json": "{\"timeout\":60,\"retries\":3,\"debug\":true}",

  "ssl_cert": "-----BEGIN CERTIFICATE-----\\nMIIC...test...cert\\n-----END CERTIFICATE-----"### 1. Install the Secrets Store CSI Driver and Vault Provider

}

```#### Why This Step is Needed

- The **Secrets Store CSI Driver** is a Kubernetes-native mechanism that allows secrets from external secret stores (like Vault) to be mounted as volumes in Kubernetes pods.

## 🔧 Configuration Auto-Discovery- The **Vault provider** is an extension of the CSI Driver that enables it to communicate with HashiCorp Vault specifically.

- Without the CSI Driver and Vault provider, Kubernetes cannot directly interact with Vault to retrieve secrets.

All scripts automatically discover Vault configuration:

#### What It Does

### Vault Address Detection- The CSI Driver acts as a bridge between Kubernetes and Vault.

1. **Ingress Route**: Checks for `vault-ingress` in `vault` namespace- It dynamically fetches secrets from Vault and mounts them into pods as files.

2. **Service DNS**: Falls back to `https://vault.vault.svc.cluster.local:8200`

#### Code Snippets

### Authentication

- Uses root token from `vault-init-keys` secret in `vault` namespaceInstall the Secrets Store CSI Driver:

- Automatically extracts token from base64 encoded JSON```bash

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/rbac-secretproviderclass.yaml

### Namespacekubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/csi-secrets-store.yaml

- Defaults to `default` namespace```

- Can be customized by modifying script variables

Install the Vault provider for the CSI Driver:

## 📈 Success Criteria```bash

kubectl apply -f https://raw.githubusercontent.com/hashicorp/secrets-store-csi-driver-provider-vault/main/deployment/provider-vault-installer.yaml

### Agent Injector Test```

✅ **Pass Criteria:**---

- Pod starts with both app and vault-agent containers

- Secrets file exists at `/vault/secrets/config`### 2. Configure Vault with Kubernetes Authentication, a Role, a Policy, and the Secret

- All expected secret values are present in the file

- Template rendering works correctly (environment variables + JSON)#### Why This Step is Needed

- Vault needs to authenticate Kubernetes pods securely to ensure that only authorized pods can access specific secrets.

### CSI Driver Test- The **Kubernetes authentication method** allows Vault to validate Kubernetes service account tokens.

✅ **Pass Criteria:**- The **role** maps Kubernetes service accounts and namespaces to Vault policies.

- CSI volume mounts successfully- The **policy** defines what secrets the authenticated pod can access.

- All secret files are created in `/mnt/secrets-store/`- The **secret** is the actual data stored in Vault that the pod needs.

- Kubernetes secret is synchronized automatically

- Environment variables are injected from K8s secret#### What It Does

- File contents match expected values- **Kubernetes Authentication**: Enables Vault to validate Kubernetes service account tokens using the Kubernetes API.

- **Role**: Maps Kubernetes service accounts to Vault policies, ensuring only specific pods can access specific secrets.

### API Test- **Policy**: Grants fine-grained access control to secrets stored in Vault.

✅ **Pass Criteria:**- **Secret**: Stores sensitive data (e.g., API keys, passwords) securely in Vault.

- Kubernetes authentication succeeds

- Token is obtained and validated#### Code Snippets

- Secret retrieval via API works

- All expected secret keys are presentEnable Kubernetes authentication in Vault:

- JSON parsing of complex data succeeds```bash

- Python HTTP client completes without errorsvault auth enable kubernetes

```

## 🛠️ Troubleshooting

Configure Kubernetes authentication in Vault:

### Common Issues```bash

vault write auth/kubernetes/config \

**Pod Won't Start:**    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \

```bash    kubernetes_host="https://<KUBERNETES_API_SERVER>" \

# Check pod status    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

kubectl describe pod [pod-name] -n default```



# Check eventsCreate a Vault role:

kubectl get events -n default --sort-by=.metadata.creationTimestamp```bash

```vault write auth/kubernetes/role/my-role \

    bound_service_account_names=vault-auth \

**Vault Authentication Issues:**    bound_service_account_namespaces=default \

```bash    policies=my-policy \

# Verify Vault is accessible    ttl=24h

kubectl exec -it vault-0 -n vault -- vault status```



# Check Kubernetes auth configurationCreate a Vault policy:

kubectl exec -it vault-0 -n vault -- vault auth list```bash

```vault policy write my-policy - <<EOF

path "secret/data/my-secret" {

**CSI Driver Issues:**  capabilities = ["read"]

```bash}

# Check CSI driver installationEOF

kubectl get daemonset -n kube-system | grep csi```



# Check CSI driver logsStore a secret in Vault:

kubectl logs -n kube-system -l app=secrets-store-csi-driver```bash

```vault kv put secret/my-secret username="my-username" password="my-password"

```

**Network Issues:**

```bash---

# Test DNS resolution from pod

kubectl exec [pod-name] -n default -- nslookup vault.vault.svc.cluster.local### 3. Create a Kubernetes Service Account and Bind it to the `system:auth-delegator` Role



# Test network connectivity#### Why This Step is Needed

kubectl exec [pod-name] -n default -- telnet vault.vault.svc.cluster.local 8200- The Kubernetes service account is used by the pod to authenticate with Vault.

```- The `system:auth-delegator` role is required to allow Vault to perform **TokenReview API calls**. These calls validate the service account token presented by the pod.



### Debug Mode#### What It Does

- The service account provides the pod with a token that Vault can validate.

Run any script with verbose output:- The `system:auth-delegator` role allows Vault to verify the authenticity of the service account token by calling the Kubernetes API.

```bash

./test_vault_agent_injector.sh --verbose#### Code Snippets

```

Create a Kubernetes service account:

This enables:```bash

- Detailed command execution (`set -x`)kubectl create serviceaccount vault -n vault

- Step-by-step progress logging```

- Full error output

- Resource descriptions on failureBind the service account to the system:auth-delegator role:

```bash

## 🧹 Cleanupkubectl create clusterrolebinding vault-auth-delegator \

  --clusterrole=system:auth-delegator \

Each script includes automatic cleanup on exit, but you can also run manual cleanup:  --serviceaccount=vault:vault

```

```bash

# Clean up specific test---

./test_vault_agent_injector.sh --cleanup

### 4. Create a SecretProviderClass to Define How the Secret is Retrieved from Vault

# Clean up all tests

for script in test_vault_*.sh; do#### Why This Step is Needed

    ./$script --cleanup- The `SecretProviderClass` is a Kubernetes resource that tells the Secrets Store CSI Driver how to retrieve secrets from Vault.

done- It specifies:

```  - The Vault server address.

  - The Vault role to use for authentication.

**Cleanup includes:**  - The path to the secret in Vault.

- Test pods deletion  - The specific keys within the secret to retrieve.

- Service accounts removal

- ConfigMaps/SecretProviderClass cleanup#### What It Does

- Kubernetes secrets cleanup- The `SecretProviderClass` acts as a configuration file for the CSI Driver.

- Graceful resource termination- It ensures that the correct secret is retrieved from Vault and made available to the pod.



## 📝 Customization#### Code Snippets



### Modifying Test DataCreate a `SecretProviderClass`:

Edit the `create_test_secret()` function in each script to add/modify test data:```bash

apiVersion: secrets-store.csi.x-k8s.io/v1

```bashkind: SecretProviderClass

kubectl exec -it vault-0 -n vault -- vault kv put $SECRET_PATH \metadata:

    your_key="your_value" \  name: vault-secret-provider

    another_key="another_value"  namespace: default

```spec:

  provider: vault

### Changing Namespaces  parameters:

Modify the `NAMESPACE` variable at the top of each script:    vaultAddress: "https://vault.gokcloud.com"

    roleName: "my-role"

```bash    objects: |

NAMESPACE="your-test-namespace"      - objectName: "my-secret"

```        secretPath: "secret/data/my-secret"

        secretKey: "username"

### Custom Vault Paths```

Update the `SECRET_PATH` variable:---



```bash### 5. Create a Pod that Mounts the Secret Using the SecretProviderClass

SECRET_PATH="secret/your/custom/path"

```#### Why This Step is Needed

- The pod is the application that needs access to the secret.

## 🎯 Integration Examples- By mounting the secret as a volume, the application running in the pod can securely access the secret without hardcoding it into the application or storing it in an insecure location.



These test scripts serve as working examples for:#### What It Does

- The pod uses the `SecretProviderClass` to dynamically fetch the secret from Vault.

1. **Production Vault Setup**: Configuration patterns and best practices- The secret is mounted into the pod as a file, making it accessible to the application.

2. **CI/CD Integration**: Automated testing of Vault configurations

3. **Development Workflows**: Local testing of secret management

4. **Troubleshooting**: Validation tools for production issues#### Code Snippets



Each script can be adapted for specific use cases by modifying the test data and resource configurations.Create a pod:

```yaml

## 📚 Additional ResourcesapiVersion: v1

kind: Pod

For detailed information about Vault integration processes, see `README_backup.md` which contains the original documentation about how secrets are retrieved from Vault and mounted in Kubernetes pods.metadata:
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