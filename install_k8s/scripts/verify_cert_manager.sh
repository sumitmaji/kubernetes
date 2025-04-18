#!/bin/bash

# Function to check the status of Cert-Manager pods
check_pods() {
  echo "Checking Cert-Manager pods..."
  kubectl get pods -n cert-manager
  if [[ $(kubectl get pods -n cert-manager --no-headers | grep -c "Running") -eq 3 ]]; then
    echo "All Cert-Manager pods are running."
  else
    echo "Some Cert-Manager pods are not running. Please check the logs."
    exit 1
  fi
}

# Function to check the status of Cert-Manager CRDs
check_crds() {
  echo "Checking Cert-Manager CRDs..."
  REQUIRED_CRDS=("certificates.cert-manager.io" "clusterissuers.cert-manager.io" "issuers.cert-manager.io")
  for crd in "${REQUIRED_CRDS[@]}"; do
    if kubectl get crd "$crd" &>/dev/null; then
      echo "CRD $crd is installed."
    else
      echo "CRD $crd is missing. Please reinstall Cert-Manager."
      exit 1
    fi
  done
}

# Function to check if ClusterIssuer is present
check_clusterissuer() {
  echo "Checking if ClusterIssuer is present..."
  if kubectl get clusterissuer gokselfsign-ca-cluster-issuer &>/dev/null; then
    echo "ClusterIssuer 'gokselfsign-ca-cluster-issuer' is present."
  else
    echo "ClusterIssuer 'gokselfsign-ca-cluster-issuer' is missing. Please create it before proceeding."
    exit 1
  fi
}

# Function to test a self-signed certificate
test_selfsigned_certificate() {
  echo "Testing self-signed certificate creation..."
  cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-selfsigned-cert
  namespace: default
spec:
  secretName: test-selfsigned-cert-secret
  issuerRef:
    name: gokselfsign-ca-cluster-issuer
    kind: ClusterIssuer
  commonName: test.gokcloud.com
  dnsNames:
    - test.gokcloud.com
EOF

  echo "Waiting for the certificate to be ready..."
  kubectl wait --for=condition=Ready certificates.cert-manager.io/test-selfsigned-cert --timeout=60s -n default
  if [[ $? -eq 0 ]]; then
    echo "Self-signed certificate created successfully."
  else
    echo "Failed to create self-signed certificate. Please check the logs."
    exit 1
  fi

  echo "Verifying the secret for the test certificate..."
  if kubectl get secret test-selfsigned-cert-secret -n default &>/dev/null; then
    echo "Secret 'test-selfsigned-cert-secret' is present."
  else
    echo "Secret 'test-selfsigned-cert-secret' is missing. Please check the certificate creation process."
    exit 1
  fi

  echo "Cleaning up test certificate and secret..."
  kubectl delete certificate test-selfsigned-cert -n default
  kubectl delete secret test-selfsigned-cert-secret -n default
}

# Function to test the webhook
test_webhook() {
  echo "Testing Cert-Manager webhook..."
  kubectl exec -i -t curl -n default -- curl -kv \
      --cacert <(kubectl -n cert-manager get secret cert-manager-webhook-ca -ojsonpath='{.data.ca\.crt}' | base64 -d) \
      https://cert-manager-webhook.cert-manager.svc:443/validate 2>&1 -d@- <<'EOF' | sed '/^* /d; /bytes data]$/d; s/> //; s/< //'
{"kind":"AdmissionReview","apiVersion":"admission.k8s.io/v1","request":{"requestKind":{"group":"cert-manager.io","version":"v1","kind":"Certificate"},"requestResource":{"group":"cert-manager.io","version":"v1","resource":"certificates"},"name":"foo","namespace":"default","operation":"CREATE","object":{"apiVersion":"cert-manager.io/v1","kind":"Certificate","spec":{"dnsNames":["foo"],"issuerRef":{"group":"cert-manager.io","kind":"Issuer","name":"letsencrypt"},"secretName":"foo","usages":["digital signature"]}}}}
EOF
  if [[ $? -eq 0 ]]; then
    echo "Cert-Manager webhook is functioning correctly."
  else
    echo "Cert-Manager webhook test failed. Please check the logs."
    exit 1
  fi
}

# Main script execution
echo "Starting Cert-Manager verification..."
check_pods
check_crds
check_clusterissuer
test_selfsigned_certificate
test_webhook
echo "Cert-Manager verification completed successfully."
