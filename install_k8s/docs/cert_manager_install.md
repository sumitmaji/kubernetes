# Installing Cert-Manager with `gok`

This guide explains how to install and configure Cert-Manager in a Kubernetes cluster using the `gok` script.

## Prerequisites

Ensure the following prerequisites are met before proceeding:
1. Kubernetes cluster is up and running.
2. `gok` script is installed and available in your system.
3. Helm is installed and configured.

## Environment Variables

The following environment variables are used during the installation and configuration of Cert-Manager:

1. **`CERTMANAGER_CHALANGE_TYPE`**
   - Specifies the challenge type for certificate issuance.
   - Supported values: `dns`, `http`, `selfsigned`.
   - Example:
     ```bash
     export CERTMANAGER_CHALANGE_TYPE=selfsigned
     ```

2. **`LETS_ENCRYPT_ENV`**
   - Specifies the Let's Encrypt environment to use.
   - Supported values: `staging`, `prod`.
   - Example:
     ```bash
     export LETS_ENCRYPT_ENV=staging
     ```

3. **`LETS_ENCRYPT_PROD_URL`**
   - URL for the Let's Encrypt production environment.
   - Example:
     ```bash
     export LETS_ENCRYPT_PROD_URL=https://acme-v02.api.letsencrypt.org/directory
     ```

4. **`LETS_ENCRYPT_STAGING_URL`**
   - URL for the Let's Encrypt staging environment.
   - Example:
     ```bash
     export LETS_ENCRYPT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory
     ```

5. **`DEFAULT_SUBDOMAIN`**
   - Specifies the default subdomain for certificate requests.
   - Example:
     ```bash
     export DEFAULT_SUBDOMAIN=kube
     ```

6. **`GOK_ROOT_DOMAIN`**
   - Specifies the root domain for the cluster.
   - Example:
     ```bash
     export GOK_ROOT_DOMAIN=gokcloud.com
     ```

7. **`GROUP_NAME`**
   - Specifies the group name for the DNS provider webhook.
   - Example:
     ```bash
     export GROUP_NAME=gokcloud.com
     ```

8. **`IDENTITY_PROVIDER`**
   - Specifies the identity provider for authentication.
   - Supported values: `oauth0`, `keycloak`.
   - Example:
     ```bash
     export IDENTITY_PROVIDER=keycloak
     ```

9. **`APP_HOST`**
   - Specifies the application host for the cluster.
   - Example:
     ```bash
     export APP_HOST=kube.gokcloud.com
     ```

10. **`JWKS_URL`**
    - Specifies the JSON Web Key Set (JWKS) URL for the identity provider.
    - Example:
      ```bash
      export JWKS_URL=https://keycloak.gokcloud.com/realms/GokDevelopers/protocol/openid-connect/certs
      ```

## Steps to Install Cert-Manager

1. **Run the `gok` command to install Cert-Manager:**

   ```bash
   gok install cert-manager
   ```

2. **What the script does:**
   - Adds the `jetstack` Helm repository.
   - Updates the Helm repository.
   - Installs the `cert-manager` Helm chart in the `cert-manager` namespace.
   - Installs Cert-Manager version `v1.14.5`.
   - Refers to the `values.yaml` file located at `kubernetes/install_k8s/cert-manager/values.yaml` for custom configurations.
     - Configures node affinity to schedule Cert-Manager pods on specific nodes (`master.cloud.com`).
     - Ensures proper resource allocation and scheduling for Cert-Manager components.
   - Configures the following:
     - Installs CRDs required by Cert-Manager.
     - Sets up a ClusterIssuer based on the challenge type specified in the `config` file.

3. **Verify the installation:**

   Check the status of the Cert-Manager pods:

   ```bash
   kubectl get pods -n cert-manager
   ```

   Check the Cert-Manager namespace:

   ```bash
   kubectl get ns cert-manager
   ```

4. **Configure ClusterIssuer:**

   The `gok` script automatically sets up a ClusterIssuer based on the challenge type specified in the `config` file. The supported challenge types are:
   - `dns`
   - `http`
   - `selfsigned`

   The challenge type is defined in the `CERTMANAGER_CHALANGE_TYPE` variable in the `config` file.

   Example configuration in the `config` file:
   ```bash
   export CERTMANAGER_CHALANGE_TYPE=selfsigned
   ```

   The `setupCertiIssuers` function is used to configure the ClusterIssuer:
   - **DNS Challenge:**
     - Creates a `ClusterIssuer` with the `dns01` solver.
     - Uses a DNS provider webhook (e.g., GoDaddy) to validate domain ownership.
     - Requires an API key stored in a Kubernetes secret (`godaddy-api-key-secret`).
     - Configures the webhook with TTL, production mode, and DNS names.
     - Example YAML:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: ClusterIssuer
       metadata:
         name: letsencrypt-dns
       spec:
         acme:
           email: majisumitkumar@gmail.com
           server: https://acme-staging-v02.api.letsencrypt.org/directory
           privateKeySecretRef:
             name: letsencrypt-staging
           solvers:
           - dns01:
               webhook:
                 config:
                   apiKeySecretRef:
                     name: godaddy-api-key-secret
                     key: api-key
                   production: false
                   ttl: 600
                 groupName: gokcloud.com
                 solverName: godaddy
       ```

   - **HTTP Challenge:**
     - Creates a `ClusterIssuer` with the `http01` solver.
     - Uses the `nginx` ingress class to handle HTTP validation.
     - Example YAML:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: ClusterIssuer
       metadata:
         name: letsencrypt-http
       spec:
           acme:
             email: majisumitkumar@gmail.com
             server: https://acme-staging-v02.api.letsencrypt.org/directory
             privateKeySecretRef:
               name: letsencrypt-staging
             solvers:
             - http01:
                 ingress:
                   ingressClassName: nginx
       ```

   - **Self-Signed Certificates:**
     - Creates a self-signed `ClusterIssuer` and a CA certificate.
     - Configures a `ClusterIssuer` to use the self-signed CA for issuing certificates.
     - Adds the CA certificate to the trusted CA store on the system.
     - The `gok` script performs the following steps for self-signed certificates:
       1. Creates a `ClusterIssuer` named `selfsigned-cluster-issuer` with the `selfSigned` solver.
       2. Generates a self-signed CA certificate using a `Certificate` resource in the `cert-manager` namespace.
       3. Creates a `ClusterIssuer` named `gokselfsign-ca-cluster-issuer` that uses the self-signed CA certificate.
       4. Adds the CA certificate to the trusted CA store on the system and exports it for worker nodes.

     - Example YAML for `selfsigned-cluster-issuer`:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: ClusterIssuer
       metadata:
         name: selfsigned-cluster-issuer
       spec:
         selfSigned: {}
       ```

     - Example YAML for the self-signed CA certificate:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: Certificate
       metadata:
         name: gokselfsign-ca
         namespace: cert-manager
       spec:
         isCA: true
         commonName: gokselfsign-ca
         secretName: gokselfsign-ca
         subject:
           organizations:
             - GOK Inc.
           organizationalUnits:
             - Widgets
         privateKey:
           algorithm: ECDSA
           size: 256
         issuerRef:
           name: selfsigned-cluster-issuer
           kind: ClusterIssuer
           group: cert-manager.io
       ```

     - Example YAML for `gokselfsign-ca-cluster-issuer`:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: ClusterIssuer
       metadata:
         name: gokselfsign-ca-cluster-issuer
       spec:
         ca:
           secretName: gokselfsign-ca
       ```

     - Additional Steps:
       - The CA certificate is added to the trusted CA store on the system using the following command:
         ```bash
         kubectl get secrets -n cert-manager gokselfsign-ca -o json | jq -r '.data["tls.crt"]' | base64 -d > /usr/local/share/ca-certificates/issuer.crt
         update-ca-certificates
         ```
       - The CA certificate is also exported to `/export/certs/issuer.crt` for worker nodes to add it to their trusted certificates.

     - **Note:** After adding the self-signed CA certificate to the trusted CA store, a system reboot may be required for the changes to take effect.

   - **Certificate Creation:**
     - After setting up the `ClusterIssuer`, the `setupCertiIssuers` function creates a certificate for the default namespace.
     - Example YAML:
       ```yaml
       apiVersion: cert-manager.io/v1
       kind: Certificate
       metadata:
         name: gokcloud-tls
         namespace: default
       spec:
         secretName: gokcloud
         issuerRef:
           name: gokselfsign-ca-cluster-issuer
           kind: ClusterIssuer
         commonName: kube.gokcloud.com
         dnsNames:
           - kube.gokcloud.com
       ```

5. **Patch Ingress Resources for Certificates:**

   After installing Cert-Manager, you can patch ingress resources to enable TLS certificates. Use the following command:

   ```bash
   gok patch ingress <ingress-name> <namespace> letsencrypt <subdomain>
   ```

   Replace `<ingress-name>`, `<namespace>`, and `<subdomain>` with appropriate values.

   Example:

   ```bash
   gok patch ingress my-ingress default letsencrypt my-subdomain
   ```

6. **Verify Certificates:**

   Check the status of certificates:

   ```bash
   kubectl get certificates -A
   ```

   Check the status of ClusterIssuers:

   ```bash
   kubectl get clusterissuers
   ```

## Uninstalling Cert-Manager

To uninstall Cert-Manager, use the following command:

```bash
gok reset cert-manager
```

This will remove Cert-Manager and its associated resources.

## Additional Notes

- Cert-Manager is configured to use the `selfsigned` challenge type by default. You can change this in the `config` file.
- For DNS or HTTP challenges, ensure that the required DNS or ingress configurations are in place.
- Cert-Manager is a critical component for managing TLS certificates in Kubernetes. Ensure proper configuration and monitoring.