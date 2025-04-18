# Cert-Manager Challenge Types and Certificate Creation Process

This document explains how different challenge types are configured in Cert-Manager and the process through which certificates are created and imported.

## Challenge Types

Cert-Manager supports three types of challenges for certificate issuance: `dns`, `http`, and `selfsigned`. Each challenge type has its own configuration and validation process.

### 1. DNS Challenge

- **Description:**
  - The DNS challenge uses a DNS provider to validate domain ownership by creating a DNS TXT record.
  - This is useful for wildcard certificates or when HTTP validation is not feasible.

- **Configuration:**
  - A `ClusterIssuer` is created with the `dns01` solver.
  - A DNS provider webhook (e.g., GoDaddy) is used for validation.
  - Requires an API key stored in a Kubernetes secret (`godaddy-api-key-secret`).

- **Example YAML:**
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

### 2. HTTP Challenge

- **Description:**
  - The HTTP challenge uses HTTP validation by creating a temporary file in the `.well-known/acme-challenge` directory.
  - This is useful when the domain is accessible over HTTP.

- **Configuration:**
  - A `ClusterIssuer` is created with the `http01` solver.
  - Requires an ingress controller (e.g., `nginx`) to handle the HTTP challenge.

- **Role of the Ingress Controller:**
  - The ingress controller is responsible for routing HTTP requests to the appropriate backend services in the Kubernetes cluster.
  - During the HTTP challenge process:
    1. Cert-Manager creates a temporary ingress resource for the domain being validated.
    2. The ingress resource routes requests to a special Cert-Manager validation service.
    3. When the ACME server sends an HTTP request to the domain (e.g., `http://example.com/.well-known/acme-challenge/<token>`), the ingress controller forwards the request to the Cert-Manager validation service.
    4. The validation service responds with the expected token, proving ownership of the domain.

- **Details of the Temporary Ingress Resource:**
  - Cert-Manager dynamically creates a temporary ingress resource in the namespace where the certificate request is made.
  - The ingress resource includes a rule to route requests for the `.well-known/acme-challenge` path to a specific service (`cert-manager-webhook`).
  - Example of the temporary ingress resource:
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: cm-acme-http-solver-<random-id>
      namespace: <namespace>
      labels:
        acme.cert-manager.io/http-domain: "<domain>"
        acme.cert-manager.io/http-token: "<token>"
    spec:
      rules:
      - host: <domain>
        http:
          paths:
          - path: /.well-known/acme-challenge/<token>
            pathType: ImplementationSpecific
            backend:
              service:
                name: cm-acme-http-solver-<random-id>
                port:
                  number: 8089
    ```

- **Where `.well-known` is Located:**
  - The `.well-known/acme-challenge` directory is not physically present on a pod or file system.
  - Instead, Cert-Manager runs a temporary pod (`cm-acme-http-solver-<random-id>`) that serves the challenge token dynamically.
  - The temporary pod listens on port `8089` and responds to requests for the `.well-known/acme-challenge/<token>` path with the expected token.

- **Temporary Pod Details:**
  - The temporary pod is created in the same namespace as the certificate request.
  - It runs a lightweight HTTP server that serves the challenge token.
  - Example of the temporary pod:
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: cm-acme-http-solver-<random-id>
      namespace: <namespace>
      labels:
        acme.cert-manager.io/http-domain: "<domain>"
        acme.cert-manager.io/http-token: "<token>"
    spec:
      containers:
      - name: acmesolver
        image: quay.io/jetstack/cert-manager-acmesolver:v1.14.5
        args:
        - --domain=<domain>
        - --token=<token>
        - --key=<key>
        ports:
        - containerPort: 8089
    ```

- **Ingress Controller Requirements:**
  - The ingress controller must be configured to handle HTTP traffic for the domain.
  - The ingress class specified in the `ClusterIssuer` (e.g., `nginx`) must match the ingress controller's class.
  - The ingress controller must allow traffic to the `.well-known/acme-challenge` path without additional authentication or restrictions.

- **Troubleshooting:**
  - If the ACME server cannot reach the `.well-known/acme-challenge` path, check the following:
    1. Ensure the ingress controller is running and properly configured.
    2. Verify that the domain's DNS records point to the ingress controller's external IP or load balancer.
    3. Check the temporary ingress resource created by Cert-Manager for any misconfigurations.
    4. Ensure the temporary pod (`cm-acme-http-solver-<random-id>`) is running and accessible.

### 3. Self-Signed Certificates

- **Description:**
  - Self-signed certificates are used for internal or testing purposes.
  - A self-signed CA certificate is created and used to issue certificates.

- **Configuration:**
  - A `ClusterIssuer` is created with the `ca` solver.
  - The CA certificate is added to the trusted CA store on the system.

- **Example YAML:**
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: gokselfsign-ca-cluster-issuer
  spec:
    ca:
      secretName: gokselfsign-ca
  ```

## Certificate Creation Process

The process of creating and importing certificates involves the following steps:

1. **ClusterIssuer Setup:**
   - Based on the challenge type, a `ClusterIssuer` is created using the appropriate solver (`dns01`, `http01`, or `ca`).

2. **Certificate Request:**
   - A `Certificate` resource is created in the desired namespace.
   - The `Certificate` specifies the `ClusterIssuer` to use, along with the domain names and secret name for storing the certificate.

   **Example YAML:**
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

3. **Validation:**
   - Cert-Manager performs the validation process based on the challenge type:
     - For DNS challenges, it creates a DNS TXT record.
     - For HTTP challenges, it creates a temporary file in the `.well-known/acme-challenge` directory.
     - For self-signed certificates, no external validation is required.

4. **Certificate Issuance:**
   - Once validation is successful, Cert-Manager requests a certificate from the ACME server or generates a self-signed certificate.
   - The certificate is stored in the specified Kubernetes secret.

5. **Certificate Import:**
   - The issued certificate can be imported into the trusted CA store or used directly by applications.
   - For self-signed certificates, the CA certificate is added to the trusted CA store on the system.

   **Example Command:**
   ```bash
   kubectl get secret gokcloud -n default -o jsonpath='{.data.tls\.crt}' | base64 -d > /usr/local/share/ca-certificates/gokcloud.crt
   update-ca-certificates
   ```

## Additional Notes

- For DNS challenges, ensure that the DNS provider webhook is properly configured and accessible.
- For HTTP challenges, ensure that the ingress controller is correctly set up to handle the `.well-known/acme-challenge` path.
- For self-signed certificates, ensure that the CA certificate is distributed to all systems that need to trust the certificates.
