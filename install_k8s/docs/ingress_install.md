# Installing Ingress with `gok`

This guide explains how to install the Kubernetes Ingress Controller using the `gok` script.

## Prerequisites

Ensure that the following prerequisites are met before proceeding:
1. Kubernetes cluster is up and running.
2. `gok` script is installed and available in your system.

## Steps to Install Ingress

1. **Run the `gok` command to install ingress:**

   ```bash
   gok install ingress
   ```

2. **What the script does:**
   - Adds the `ingress-nginx` Helm repository.
   - Updates the Helm repository.
   - Installs the `ingress-nginx` Helm chart in the `ingress-nginx` namespace.
   - Configures the ingress controller with the following settings:
     - HTTP NodePort: `80`
     - HTTPS NodePort: `443`
     - Service type: `NodePort`
     - Default backend enabled.

3. **Wait for the service to be available:**

   The script automatically waits for the ingress controller pods to be ready. If the pods are not ready within the timeout period, you may need to troubleshoot the installation.

4. **Verify the installation:**

   Check the status of the ingress controller pods:

   ```bash
   kubectl get pods -n ingress-nginx
   ```

   Check the ingress controller service:

   ```bash
   kubectl get svc -n ingress-nginx
   ```

5. **Patch Ingress Resources (Optional):**

   After installing the ingress controller, you can patch ingress resources for specific configurations like Let's Encrypt certificates, LDAP authentication, or local TLS. Use the following command:

   ```bash
   gok patch ingress <ingress-name> <namespace> <option> <subdomain>
   ```

   Replace `<option>` with one of the following:
   - `letsencrypt`: To enable Let's Encrypt certificates.
   - `ldap`: To enable LDAP authentication.
   - `localtls`: To enable local TLS.

   Example:

   ```bash
   gok patch ingress my-ingress default letsencrypt my-subdomain
   ```

## Troubleshooting

- If the ingress controller pods are not running, check the logs:

  ```bash
  kubectl logs -n ingress-nginx <pod-name>
  ```

- Ensure that the ingress controller is properly configured to handle your ingress resources.

## Uninstalling Ingress

To uninstall the ingress controller, use the following command:

```bash
gok reset ingress
```

This will remove the ingress controller and its associated resources.

## Additional Notes

- The ingress controller is configured to use the `nginx` ingress class by default.
- You can customize the ingress controller settings by modifying the `gok` script or using a custom Helm values file.