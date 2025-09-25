Here is a documentation summary for all the main methods in your gok script:

---

### 1. **getOAuth0Config**
**Description:**  
Returns environment variables for OAuth0 configuration.  
No user input required; used internally.

**Inputs:** None

**Example:**
```sh
gok getOAuth0Config
```

---

### 2. **getKeycloakConfig**
**Description:**  
Returns environment variables for Keycloak configuration.  
No user input required; used internally.

**Inputs:** None

**Example:**
```sh
gok getKeycloakConfig
```

---

### 3. **rootDomain**
**Description:**  
Prints the root domain for the cluster.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok rootDomain
```

---

### 4. **sedRootDomain**
**Description:**  
Prints the root domain with dots replaced by dashes.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok sedRootDomain
```

---

### 5. **registrySubdomain, defaultSubdomain, keycloakSubdomain, argocdSubdomain, jupyterHubSubdomain**
**Description:**  
Prints the subdomain for the respective service.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok registrySubdomain
gok defaultSubdomain
gok keycloakSubdomain
gok argocdSubdomain
gok jupyterHubSubdomain
```

---

### 6. **fullDefaultUrl, fullRegistryUrl, fullKeycloakUrl, fullVaultUrl, fullSpinnakerUrl**
**Description:**  
Prints the full URL for the respective service.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok fullDefaultUrl
gok fullRegistryUrl
gok fullKeycloakUrl
gok fullVaultUrl
gok fullSpinnakerUrl
```

---

### 7. **echoSuccess, echoFailed, echoWarning**
**Description:**  
Prints colored success, failure, or warning messages.  
Takes a message string as input.

**Inputs:**  
- Message string

**Example:**
```sh
gok echoSuccess "Operation completed successfully"
gok echoFailed "Operation failed"
gok echoWarning "This is a warning"
```

---

### 8. **replaceEnvVariable**
**Description:**  
Fetches a file from a URL and substitutes environment variables.  
Takes a URL as input.

**Inputs:**  
- URL

**Example:**
```sh
gok replaceEnvVariable https://example.com/file.yaml
```

---

### 9. **promptUserInput**
**Description:**  
Prompts the user for input with an optional default value.  
Takes a message and a default value.

**Inputs:**  
- Prompt message  
- Default value

**Example:**
```sh
gok promptUserInput "Enter your name: " "defaultName"
```

---

### 10. **promptSecret**
**Description:**  
Prompts the user for a secret (hidden input).  
Takes a message as input.

**Inputs:**  
- Prompt message

**Example:**
```sh
gok promptSecret "Enter your password: "
```

---

### 11. **dataFromSecret**
**Description:**  
Fetches a key from a Kubernetes secret.  
Needs secret name, namespace, and key.

**Inputs:**  
- Secret name  
- Namespace  
- Key

**Example:**
```sh
gok dataFromSecret my-secret default password
```

---

### 12. **createApp1**
**Description:**  
Deploys a sample app and service with ingress.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok createApp1
```

---

### 13. **kcurl**
**Description:**  
Deploys a pod with curl installed for testing.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok kcurl
```

---

### 14. **checkCurl**
**Description:**  
Executes a curl command inside the curl pod.  
Takes a URL as input.

**Inputs:**  
- URL

**Example:**
```sh
gok checkCurl https://kubernetes
```

---

### 15. **checkCMWebhook**
**Description:**  
Checks the cert-manager webhook using curl.  
No user input required.

**Inputs:** None

**Example:**
```sh
gok checkCMWebhook
```

---

### 16. **join**
**Description:**  
Prints the kubeadm join command for adding a node.  
No user input required.

**Inputs:** None

---

### 17. **dnsUtils**
**Description:**  
Deploys a pod for DNS utilities.  
No user input required.

**Inputs:** None

---

### 18. **checkDns**
**Description:**  
Checks DNS resolution for a given domain using the dnsutils pod.  
Takes a domain as input.

**Inputs:**  
- Domain name

---

### 19. **getpod**
**Description:**  
Gets the name of a pod for a given release.  
No user input required.

**Inputs:** None

---

### 20. **updateSys**
**Description:**  
Runs `apt-get update` to update system packages.  
No user input required.

**Inputs:** None

---

### 21. **setupDockerRegistry**
**Description:**  
Sets up a Docker registry with TLS certificates.  
No user input required.

**Inputs:** None

---

### 22. **installDeps**
**Description:**  
Installs system dependencies like net-tools, jq, and Python.  
No user input required.

**Inputs:** None

---

### 23. **ingressUnInst**
**Description:**  
Uninstalls the ingress-nginx controller and deletes its namespace.  
No user input required.

**Inputs:** None

---

### 24. **patchNginxConfig**
**Description:**  
Patches the nginx configmap for debug logging and restarts the controller.  
No user input required.

**Inputs:** None

---

### 25. **ingressInst**
**Description:**  
Installs the ingress-nginx controller using Helm.  
No user input required.

**Inputs:** None

---

### 26. **resetChart**
**Description:**  
Uninstalls ChartMuseum and cleans up storage.  
No user input required.

**Inputs:** None

---

### 27. **chartInst**
**Description:**  
Installs ChartMuseum with persistent storage and sets up Helm repo.  
No user input required.

**Inputs:** None

---

### 28. **dockrInst**
**Description:**  
Installs Docker and configures it for Kubernetes.  
No user input required.

**Inputs:** None

---

### 29. **customDns**
**Description:**  
Configures CoreDNS with custom DNS forwarding.  
No user input required.

**Inputs:** None

---

### 30. **taintNode**
**Description:**  
Taints the master node to allow scheduling.  
No user input required.

**Inputs:** None

---

### 31. **k8sInst**
**Description:**  
Installs Kubernetes master or worker node, depending on argument.  
Input: `"kubernetes"` or `"kubernetes-worker"`

**Inputs:**  
- Node type (master/worker)

---

### 32. **calicoInst**
**Description:**  
Installs Calico networking for Kubernetes.  
No user input required.

**Inputs:** None

---

### 33. **helmInst**
**Description:**  
Installs Helm package manager.  
No user input required.

**Inputs:** None

---

### 34. **certmanagerInst**
**Description:**  
Installs cert-manager using Helm.  
No user input required.

**Inputs:** None

---

### 35. **subDomain**
**Description:**  
Prints the subdomain, or default if not provided.  
Input: subdomain (optional)

**Inputs:**  
- Subdomain (optional)

---

### 36. **certificateRequestForNs**
**Description:**  
Creates a certificate request for a namespace and subdomain.  
Inputs: namespace, subdomain (optional)

**Inputs:**  
- Namespace  
- Subdomain (optional)

---

### 37. **getLetsEncEnv, getLetsEncryptUrl, isProd, getClusterIssuerName**
**Description:**  
Returns Let's Encrypt environment, URL, or issuer name.  
No user input required.

**Inputs:** None

---

### 38. **godaddyWebhook, godaddyWebhookReset**
**Description:**  
Sets up or resets GoDaddy DNS webhook for cert-manager.  
Prompts for API key.

**Inputs:**  
- GoDaddy API key (prompted)

---

### 39. **addLetsEncryptStagingCertificates**
**Description:**  
Adds Let's Encrypt staging root certificate to the system.  
No user input required.

**Inputs:** None

---

### 40. **setupCertiIssuers**
**Description:**  
Sets up cert-manager ClusterIssuers based on challenge type.  
No user input required.

**Inputs:** None

---

### 41. **certManagerReset**
**Description:**  
Deletes cert-manager and all related resources.  
No user input required.

**Inputs:** None

---

### 42. **haInst, startHa**
**Description:**  
Sets up or starts HAProxy for Kubernetes API server.  
No user input required.

**Inputs:** None

---

### 43. **startKubelet**
**Description:**  
Restarts the kubelet service.  
No user input required.

**Inputs:** None

---

### 44. **disableSwap**
**Description:**  
Disables swap on the system.  
No user input required.

**Inputs:** None

---

### 45. **hostSecret**
**Description:**  
Generates a TLS secret for the app ingress.  
No user input required.

**Inputs:** None

---

### 46. **dashboardInst, dashboardReset**
**Description:**  
Installs or resets the Kubernetes dashboard.  
No user input required.

**Inputs:** None

---

### 47. **prometheusGrafanaReset, prometheusGrafanaResetv2, prometheusGrafanaInst, prometheusGrafanaInstv2**
**Description:**  
Installs or resets Prometheus and Grafana monitoring stack.  
No user input required.

**Inputs:** None

---

### 48. **emptyLocalFsStorage, createLocalStorageClassAndPV**
**Description:**  
Deletes or creates local storage class and persistent volume.  
Inputs: service name, PV name, storage class, volume path, namespace (optional)

**Inputs:**  
- Service name  
- PV name  
- Storage class  
- Volume path  
- Namespace (optional)

---

### 49. **adminRole, oauthDev, oauthAdmin**
**Description:**  
Creates RBAC roles and bindings for admin or developer users.  
No user input required.

**Inputs:** None

---

### 50. **runKubectlOnPod**
**Description:**  
Runs a kubectl command inside a Kubernetes job.  
No user input required.

**Inputs:** None

---

### 51. **oauthUser**
**Description:**  
Creates a kubeconfig file for OAuth user.  
No user input required.

**Inputs:** None

---

### 52. **apiUrl**
**Description:**  
Prints the Kubernetes API server URL.  
No user input required.

**Inputs:** None

---

### 53. **opensearchReset, opensearchInst, opensearchDashReset, opensearchDashInst**
**Description:**  
Installs or resets OpenSearch and its dashboard.  
Prompts for admin password during install.

**Inputs:**  
- Admin password (prompted)

---

### 54. **jenkinsReset, jenkinsInst**
**Description:**  
Installs or resets Jenkins with OAuth and Docker integration.  
Prompts for admin password and other secrets during install.

**Inputs:**  
- Jenkins admin password (prompted)  
- Client secrets (prompted)

---

### 55. **fluentdReset, fluentdInst**
**Description:**  
Installs or resets Fluentd logging stack.  
No user input required.

**Inputs:** None

---

### 56. **resetDockerRegistry, dockerRegistryInst, genRegistryPassword, imagePullSecrets, verifyRegistryInst**
**Description:**  
Installs or resets Docker registry and manages credentials.  
Prompts for Docker credentials.

**Inputs:**  
- Docker username  
- Docker password

---

### 57. **deleteOldDockerImages**
**Description:**  
Deletes old Docker images not tagged as latest.  
Input: image name

**Inputs:**  
- Image name

---

### 58. **createCertificate, createClientCertificate, createKubeConfig**
**Description:**  
Generates certificates and kubeconfig files for users.  
Prompts for user details.

**Inputs:**  
- Username  
- Group name (for client cert)  
- Node IP, hostname, etc. (for server cert)

---

### 59. **patchLdapSecure, patchOauth2Secure, patchLetsEncrypt, patchLocalTls**
**Description:**  
Patches ingress resources with security and TLS annotations.  
Inputs: ingress name, namespace, subdomain/redirect (as needed)

**Inputs:**  
- Ingress name  
- Namespace  
- Subdomain/redirect (as needed)

---

### 60. **helmShowValues, helmShowAll, helmTemplate, helmShowTemplate**
**Description:**  
Shows Helm chart values, resources, or templates.  
Input: chart name or repo

**Inputs:**  
- Chart name or repo

---

### 61. **oauth2Secret, opensearchSecret**
**Description:**  
Creates Kubernetes secrets for OAuth2 or OpenSearch.  
Prompts for secrets if not found.

**Inputs:**  
- Client secret (prompted)

---

### 62. **csiDriverInstall, csiDriverUnInstall**
**Description:**  
Installs or uninstalls the CSI secrets store driver.  
No user input required.

**Inputs:** None

---

### 63. **vaultLogin, cleanExampleSecretStoreInVault, cleanDockerRegistrySecretStoreInVault, verifyVault, debugVault**
**Description:**  
Performs Vault login and cleanup or verification tasks.  
No user input required.

**Inputs:** None

---

### 64. **createVaultSecretStore, exampleSecretStoreInVaule, dockerRegistrySecretStoreInVault**
**Description:**  
Creates Vault secret stores and related Kubernetes resources.  
Prompts for secret details.

**Inputs:**  
- Secret path, role, policy, provider class, prefix, namespace, key-value pairs

---

### 65. **vaultInstall, vaultReset**
**Description:**  
Installs or resets Vault using Helm and configures it.  
No user input required.

**Inputs:** None

---

### 66. **gokAgentReset, gokAgentInstall, gokControllerReset, gokControllerInstall**
**Description:**  
Installs or resets Gok Agent/Controller using Helm.  
No user input required.

**Inputs:** None

---

### 67. **fetch_client_secret, create_sub_scope, debugScope, generateAccessToken**
**Description:**  
Fetches Keycloak client secrets, creates scopes, and generates tokens.  
Prompts for Keycloak admin credentials and client info.

**Inputs:**  
- Keycloak URL  
- Realm  
- Client ID  
- Admin username/password

---

### 68. **installKeycloakWithCertMgr, keycloakReset, keycloakInst**
**Description:**  
Installs or resets Keycloak with cert-manager integration.  
Prompts for admin and database credentials.

**Inputs:**  
- Admin username/password  
- Database username/password

---

### 69. **installLdap, updateLdapConfig, updateUserData, createUserGroup, ldapReset**
**Description:**  
Installs or resets LDAP and manages user/group data.  
Prompts for LDAP and Kerberos passwords, user/group info.

**Inputs:**  
- LDAP/Kerberos passwords  
- User/group info

---

### 70. **copySecret**
**Description:**  
Copies a Kubernetes secret from one namespace to another.  
Inputs: secret name, source namespace, target namespace

**Inputs:**  
- Secret name  
- Source namespace  
- Target namespace

---

### 71. **cloudshellReset, cloudshellInst, consoleReset, consoleInst**
**Description:**  
Installs or resets CloudShell/Console using Helm.  
No user input required.

**Inputs:** None

---

### 72. **installDashboardwithCertManager**
**Description:**  
Installs dashboard with cert-manager integration.  
No user input required.

**Inputs:** None

---

### 73. **add_audience_mapper_to_groups_scope**
**Description:**  
Adds an audience protocol mapper to a Keycloak client.  
Prompts for Keycloak admin credentials and client info.

**Inputs:**  
- Keycloak URL  
- Realm  
- Admin username/password  
- Client ID

---

### 74. **generate_kubeconfig**
**Description:**  
Generates a kubeconfig file for a user.  
Prompts for API server URL, namespace, and token.

**Inputs:**  
- API server URL  
- Namespace  
- Bearer token

---

### 75. **get_keycloak_token**
**Description:**  
Fetches an access token from Keycloak.  
Prompts for Keycloak URL, client ID/secret, username, and password.

**Inputs:**  
- Keycloak URL  
- Client ID  
- Client secret  
- Username  
- Password

**Example:**
```sh
gok get_keycloak_token
```

---

### 76. **oauth2ProxyReset, oauth2ProxyInst**
**Description:**  
Installs or resets OAuth2 Proxy using Helm.  
Prompts for client ID/secret.

**Inputs:**  
- Client ID  
- Client secret

---

### 77. **waitForServiceAvailable**
**Description:**  
Waits for all pods in a namespace to be ready.  
Input: namespace

**Inputs:**  
- Namespace

---

### 78. **resolveDns**
**Description:**  
Runs an nslookup for a domain using a busybox pod.  
Input: domain

**Inputs:**  
- Domain

---

### 79. **ttydReset, ttydInst**
**Description:**  
Installs or resets ttyd using Helm.  
No user input required.

**Inputs:** None

---

### 80. **enableJenkins**
**Description:**  
Enables Jenkins integration in Spinnaker.  
Prompts for Jenkins username and password.

**Inputs:**  
- Jenkins username  
- Jenkins password

---

### 81. **spinnakerInst, spinnakerReset**
**Description:**  
Installs or resets Spinnaker with S3 and OAuth integration.  
Prompts for client secrets and other details.

**Inputs:**  
- Client ID  
- Client secret

---

### 82. **rabbitmqReset, rabbitmqInst**
**Description:**  
Installs or resets RabbitMQ using Helm.  
No user input required.

**Inputs:** None

---

### 83. **argocdReset, argocdInst**
**Description:**  
Installs or resets ArgoCD using Helm.  
No user input required.

**Inputs:** None

---

### 84. **getUserInfo**
**Description:**  
Fetches user info from Keycloak using an access token.  
Prompts for authorization code and client secret.

**Inputs:**  
- Authorization code  
- Client secret

---

### 85. **removeClaimRefFromPV**
**Description:**  
Removes the claimRef from a PersistentVolume in Released state.  
Input: PV name

**Inputs:**  
- PersistentVolume name

---

### 86. **eclipseCheInst, resetEclipseChe**
**Description:**  
Installs or resets Eclipse Che IDE on Kubernetes.  
Prompts for OIDC client secret and other details.

**Inputs:**  
- Client secret  
- Client ID  
- Realm name

---

### 87. **kubeloginInst**
**Description:**  
Installs kubelogin using Homebrew.  
No user input required.

**Inputs:** None

---

### 88. **kyvernoInst, kyvernoReset**
**Description:**  
Installs or resets Kyverno policy engine.  
No user input required.

**Inputs:** None

---

### 89. **help, helpCmd**
**Description:**  
Displays help and usage information for the gok script.  
No user input required.

**Inputs:** None

---

### 90. **bashCmd, descCmd, logsCmd, statusCmd, taintNodeCmd**
**Description:**  
Performs common kubectl operations (bash, describe, logs, status, taint node).  
No user input required.

**Inputs:** None

---

### 91. **installCmd, startCmd, resetCmd, deployCmd, patchCmd, createCmd**
**Description:**  
Dispatches to the appropriate install, start, reset, deploy, patch, or create function based on user command.  
Inputs: command and component/resource names.

**Inputs:**  
- Command  
- Component/resource name(s)

---

### 92. **postRebootBaseServices**
**Description:**  
Continues base services installation after a system reboot.  
Loads saved user inputs and installs remaining services.

**Inputs:** None

**Example:**
```sh
gok postRebootBaseServices
```

---

### 93. **collectUserInputs**
**Description:**  
Collects all required user inputs for base services installation and saves them to a file.  
Prompts for credentials and configuration values interactively.

**Inputs:** None (prompts interactively)

**Example:**
```sh
gok collectUserInputs
```

---

### 94. **installBaseServices**
**Description:**  
Installs all base services required for the Kubernetes cluster.  
Handles pre-reboot and post-reboot installation steps.

**Inputs:** None

**Example:**
```sh
gok installBaseServices
```

---

### 95. **resetBaseServices**
**Description:**  
Resets all base services in the cluster, including Vault, RabbitMQ, OAuth2, Keycloak, LDAP, Registry, Kyverno, Cert-Manager, and Ingress.  
Useful for troubleshooting or reinstallation.

**Inputs:** None

**Example:**
```sh
gok resetBaseServices
```

---

## gok install options

Below are the available `gok install <option>` commands, their purposes, and the corresponding method called in the script:

| Option                | Purpose                                                                 | Method Called                |
|-----------------------|-------------------------------------------------------------------------|------------------------------|
| ingress               | Installs the ingress-nginx controller using Helm.                        | ingressInst                  |
| cert-manager          | Installs cert-manager for managing TLS certificates.                     | setupCertiIssuers            |
| kyverno               | Installs Kyverno policy engine for Kubernetes.                           | kyvernoInst                  |
| registry              | Sets up a Docker registry with TLS certificates.                         | installRegistryWithCertMgr    |
| base                  | Installs base services required for the Kubernetes cluster.              | baseInst                     |
| ldap                  | Installs LDAP and manages user/group data.                              | installLdap                  |
| keycloak              | Installs Keycloak with cert-manager integration.                         | installKeycloakWithCertMgr    |
| oauth2                | Installs OAuth2 Proxy using Helm.                                       | oauth2ProxyInst               |
| rabbitmq              | Installs RabbitMQ using Helm.                                            | rabbitmqInst                  |
| vault                 | Installs Vault using Helm and configures it.                             | vaultInstall                  |
| cloudshell            | Installs CloudShell for Kubernetes.                                      | cloudshellInst                |
| console               | Installs Console for Kubernetes.                                         | consoleInst                   |
| dashboard             | Installs the Kubernetes dashboard.                                       | installDashboardwithCertManager|
| prometheus-grafana    | Installs Prometheus and Grafana monitoring stack.                        | installPrometheusGrafanaWithCertMgr|
| chartmuseum           | Installs ChartMuseum with persistent storage and sets up Helm repo.       | chartInst                     |
| gok-agent             | Installs Gok Agent using Helm.                                           | gokAgentInstall               |
| gok-controller        | Installs Gok Controller using Helm.                                      | gokControllerInstall          |
| eclipseche            | Installs Eclipse Che IDE on Kubernetes.                                  | eclipseCheInst                |
| spinnaker             | Installs Spinnaker with S3 and OAuth integration.                        | spinnakerInst                 |
| argocd                | Installs ArgoCD using Helm.                                              | argocdInst                    |
| fluentd               | Installs Fluentd logging stack.                                          | fluentdInst                   |
| opensearch            | Installs OpenSearch and its dashboard.                                   | opensearchDashInst            |
| jenkins               | Installs Jenkins with OAuth and Docker integration.                      | jenkinsInst                   |
| ttyd                  | Installs ttyd using Helm.                                                | ttydInst                      |
| calico                | Installs Calico networking for Kubernetes.                               | calicoInst                    |
| k8s                   | Installs Kubernetes master or worker node.                               | k8sInst                       |
| helm                  | Installs Helm package manager.                                           | helmInst                      |
| csi-driver            | Installs the CSI secrets store driver.                                   | csiDriverInstall              |
| base-services         | Installs all base services required for the cluster (multi-service).      | installBaseServices           |
| kubernetes-worker     | Installs a Kubernetes worker node.                                       | k8sInst "kubernetes-worker"   |

**Usage Example:**
```sh
gok install <option>
```

**For more details on each option, see the corresponding method documentation above.**