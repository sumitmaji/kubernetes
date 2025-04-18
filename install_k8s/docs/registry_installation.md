# Registry Installation Guide

This guide provides step-by-step instructions to install and configure a Docker registry in your Kubernetes cluster.

## Prerequisites

1. Ensure Kubernetes is installed and running.
2. Install Helm package manager.
3. Cert-Manager must be installed and configured for issuing certificates.

## Steps to Install the Registry

### 1. Create Local Storage Class and Persistent Volume

Run the following command to create a storage class and persistent volume for the registry:

```bash
createLocalStorageClassAndPV "registry-storage" "registry-pv" "/data/volumes/pv4"
```

### 2. Generate Registry Credentials

Run the following commands to generate credentials for the Docker registry:

```bash
export REGISTRY_USER="your-username"
export REGISTRY_PASS="your-password"
export DESTINATION_FOLDER=./registry-creds

mkdir -p ${DESTINATION_FOLDER}
echo ${REGISTRY_USER} > ${DESTINATION_FOLDER}/registry-user.txt
echo ${REGISTRY_PASS} > ${DESTINATION_FOLDER}/registry-pass.txt

docker run --entrypoint htpasswd registry:2.7.0 \
    -Bbn ${REGISTRY_USER} ${REGISTRY_PASS} \
    > ${DESTINATION_FOLDER}/htpasswd
```

### 3. Deploy the Docker Registry

Run the following command to deploy the Docker registry using Helm:

```bash
helm repo add twuni https://helm.twun.io
helm upgrade --install registry \
    --namespace registry \
    --create-namespace \
    --set replicaCount=1 \
    --set persistence.enabled=true \
    --set persistence.size=10Gi \
    --set persistence.deleteEnabled=true \
    --set persistence.storageClass=registry-storage \
    --set secrets.htpasswd="$(cat ./registry-creds/htpasswd)" \
    --values https://github.com/sumitmaji/kubernetes/raw/master/install_k8s/registry/values.yaml \
    twuni/docker-registry
```

### 4. Patch the Ingress with Let's Encrypt

Run the following command to patch the ingress for the registry with Let's Encrypt:

```bash
gok patch ingress registry-docker-registry registry letsencrypt $(registrySubdomain)
```

### 5. Configure Docker to Trust the Registry's Certificate

Run the following commands to configure Docker to trust the registry's certificate:

```bash
rm /etc/docker/certs.d/$(registrySubdomain).$(rootDomain)/ca.crt
mkdir -p /etc/docker/certs.d/$(registrySubdomain).$(rootDomain)/
kubectl get secret $(registrySubdomain)-$(sedRootDomain) -n registry -o jsonpath="{['data']['tls\.crt']}" | base64 --decode > /etc/docker/certs.d/$(registrySubdomain).$(rootDomain)/ca.crt
kubectl get secret $(registrySubdomain)-$(sedRootDomain) -n registry -o jsonpath="{['data']['ca\.crt']}" | base64 --decode >> /etc/docker/certs.d/$(registrySubdomain).$(rootDomain)/ca.crt
systemctl restart docker
```

### 6. Restart HAProxy (if applicable)

Restart HAProxy to ensure it is running after Docker restarts:

```bash
gok start proxy
```

### 7. Verify the Registry Installation

Run the following commands to verify the registry installation:

```bash
docker login $(registrySubdomain).$(rootDomain)
openssl s_client -connect $(registrySubdomain).$(rootDomain):443 -showcerts </dev/null | grep 'Verify return code: 0 (ok)'
```

If the commands return successfully, the registry is installed and configured correctly.

## Notes

- Ensure that the registry ingress is accessible via DNS.
- Restarting Docker may stop other services; ensure to restart them if necessary.
- The registry credentials are stored in the `./registry-creds` directory for future reference.
- Verify the registry certificate using `openssl` to ensure it is trusted.
