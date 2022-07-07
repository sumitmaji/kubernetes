# Cer-Manager

Installation of Cert-Manager

### Install commands
```shell
helm repo add jetstack https://charts.jetstack.io

helm repo update

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.crds.yaml

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.2 \
  # --set installCRDs=true
```

### Issuer and Certificate
```shell
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: "skmaji1@outlook.com"
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

```shell
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gokcloud-co-in-tls
spec:
  secretName: gokcloud-co-in
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: gokcloud.co.in
  dnsNames:
    - gokcloud.co.in
    - www.gokcloud.co.in
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
EOF
```

### An example of Ingress resource
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-service
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    certmanager.k8s.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - gokcloud.co.in
        - www.gokcloud.co.in
      secretName: gokcloud.co.in
  rules:
    - host: gokcloud.co.in
      http:
        paths:
          - path: /
            backend:
              serviceName: client-cluster-ip-service
              servicePort: 3000
          - path: /api/
            backend:
              serviceName: server-cluster-ip-service
              servicePort: 5000
    - host: www.gokcloud.co.in
      http:
        paths:
          - path: /
            backend:
              serviceName: client-cluster-ip-service
              servicePort: 3000
          - path: /api/
            backend:
              serviceName: server-cluster-ip-service
              servicePort: 5000
```



### Uninstall commands
```shell
# Delete the resources
kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces

helm --namespace cert-manager delete cert-manager

kubectl delete namespace cert-manager

kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.crds.yaml
```

### Useful Documents
- [`Stephen Grinder`](https://github.com/webmakaka/Docker-and-Kubernetes-The-Complete-Guide/tree/master/17_HTTPS_Setup_with_Kubernetes)
- Refer to `HTTPS Setup with Kubernetes` from `Stephen Grinder`