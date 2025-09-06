# util.sh Documentation

This document summarizes the main functions and commands available in your `util.sh` script for Kubernetes management.

---

## Namespace and Context Management

### `release <namespace>`
Sets the current release namespace.

### `kcd [namespace]`
Interactive namespace switcher. Lists namespaces and lets you select one by index, or switches to the provided namespace.

### `current`
Prints the current namespace.

---

## Pod and Resource Management

### `pods`
Lists all pods in the current namespace.

### `getpod`
Gets the name of a pod in the current namespace.

### `all`
Lists all resources in the current namespace.

### `secrets`
Lists all secrets in the current namespace.

### `desc <resource-type>`
Lists resources of the given type, lets you select one by index, and describes it.

### `edit <resource-type>`
Lists resources of the given type, lets you select one by index, and opens it for editing.

### `ns`
Lists all namespaces.

---

## Pod Terminal and Logs

### `bash`
Interactive pod/container selector. Opens a bash shell in the selected container.

### `ksh`
Interactive pod/container selector. Opens a sh shell in the selected container.

### `logs [pod-index,container-index]`
Interactive pod/container selector. Shows logs for the selected container.

### `ktail [pod-index,container-index]`
Interactive pod/container selector. Tails logs for the selected container.

### `kless [pod-index,container-index]`
Interactive pod/container selector. Views logs for the selected container with `less`.

---

## Certificate and Secret Utilities

### `viewcert <secret-content>`
Interactive secret/key selector. Decodes and displays certificate details from a secret.

### `decode <secret-content>`
Interactive secret/key selector. Decodes and displays secret data.

### `decodeSecret <secret> <namespace>`
Decodes and displays the TLS certificate from a secret.

---

## Subdomain and URL Utilities

### `subDomain [subdomain]`
Prints the subdomain, or the default if not provided.

### `rootDomain`
Prints the root domain for the cluster.

### `sedRootDomain`
Prints the root domain with dots replaced by dashes.

### `registrySubdomain`, `defaultSubdomain`, `keycloakSubdomain`
Prints the subdomain for the respective service.

### `fullDefaultUrl`, `fullRegistryUrl`, `fullKeycloakUrl`
Prints the full URL for the respective service.

---

## Miscellaneous Utilities

### `getLetsEncEnv`
Prints the Let's Encrypt environment.

### `getLetsEncryptUrl`
Prints the Let's Encrypt URL based on environment.

### `getClusterIssuerName`
Prints the cert-manager ClusterIssuer name based on challenge type.

### `getHostIp`
Interactive interface selector. Prints the IP address for the selected network interface.

---

## Patching and Helm Utilities

### `patchLdapSecure`
Patches LDAP ingress with security annotations.

### `patchCertManager <name> <namespace> [subdomain]`
Patches ingress for cert-manager TLS and updates host.

### `patchLocalTls <name> <namespace>`
Patches ingress for local TLS and updates host/annotations.

### `helmInst <release> <repo> <namespace>`
Uninstalls and installs a Helm chart, sets up image pull secrets, and waits for pods to be ready.

---

## Output Formatting

### `echoSuccess <message>`
Prints a success message in green.

### `echoFailed <message>`
Prints a failure message in red.

### `echoWarning <message>`
Prints a warning message in green.

---

## Environment Variable and File Utilities

### `replaceEnvVariable <url>`
Fetches a file from a URL and substitutes environment variables.

---

## Help

### `utilHelp`
Prints a summary of all available commands and their descriptions.

---

## Example Usage

```sh
# Switch to a namespace interactively
kcd

# Open a bash shell in a pod/container
bash

# View logs for a pod/container
logs

# Patch an ingress for cert-manager
patchCertManager my-ingress my-namespace my-subdomain
```

---

**For more details, run:**
```sh
utilHelp
```
