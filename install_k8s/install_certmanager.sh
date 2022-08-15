#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/cert-manager

helm repo add jetstack https://charts.jetstack.io

helm repo update

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.crds.yaml

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.2

# Install godaddy webhook
kubectl apply -f ../godaddy-cert-webhook/webhook-all.yml --validate=false

echo "Provide godaddy apikey and secret <API_KEY:SECRET>"
# shellcheck disable=SC2162
read API_KEY

cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: godaddy-api-key-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-key: ${API_KEY}
EOF


cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: majisumitkumar@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        webhook:
          config:
            apiKeySecretRef:
              name: godaddy-api-key-secret
              key: api-key
            production: true
            ttl: 600
          groupName: acme.mycompany.com
          solverName: godaddy
      selector:
       dnsNames:
       - 'kube.gokcloud.co.in'
       - '*.gokcloud.co.in'
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gokcloud-co-in-tls
  namespace: default
spec:
  secretName: gokcloud-co-in
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: kube.gokcloud.co.in
  dnsNames:
    - kube.gokcloud.co.in
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
EOF

popd
