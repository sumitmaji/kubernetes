#!/bin/bash

# Variables
NAMESPACE="default"  # Namespace where the application pod is running
POD_NAME="vault-secret-pod"  # Name of the application pod
VAULT_ROLE="my-role"  # Vault role name
VAULT_POLICY="my-policy"  # Vault policy name
VAULT_ADDR="https://vault.gokcloud.com"  # Vault server address
SECRET_PATH="secret/my-secret"  # Path to the secret in Vault

# Function to print a header
print_header() {
  echo "========================================"
  echo "$1"
  echo "========================================"
}

# 1. Verify the Pod's Service Account
print_header "Step 1: Verifying Pod's Service Account"
SERVICE_ACCOUNT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.serviceAccountName}')
if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "Error: Could not retrieve service account for pod $POD_NAME in namespace $NAMESPACE."
  exit 1
fi
echo "Service Account: $SERVICE_ACCOUNT"

# 2. Verify the Vault Role
print_header "Step 2: Verifying Vault Role"
kubectl exec -it vault-0 -n vault -- vault read auth/kubernetes/role/"$VAULT_ROLE" || {
  echo "Error: Vault role $VAULT_ROLE not found."
  exit 1
}

# 3. Verify the Vault Policy
print_header "Step 3: Verifying Vault Policy"
kubectl exec -it vault-0 -n vault -- vault policy read "$VAULT_POLICY" || {
  echo "Error: Vault policy $VAULT_POLICY not found."
  exit 1
}

# 4. Verify the Kubernetes Authentication Configuration in Vault
print_header "Step 4: Verifying Kubernetes Authentication Configuration in Vault"
kubectl exec -it vault-0 -n vault -- vault read auth/kubernetes/config || {
  echo "Error: Kubernetes authentication configuration in Vault is invalid."
  exit 1
}

# 5. Test Authentication with Vault
print_header "Step 5: Testing Authentication with Vault"
TOKEN=$(kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
if [ -z "$TOKEN" ]; then
  echo "Error: Could not retrieve service account token from pod $POD_NAME."
  exit 1
fi

AUTH_RESPONSE=$(curl --silent --request POST --data '{"jwt": "'"$TOKEN"'", "role": "'"$VAULT_ROLE"'"}' "$VAULT_ADDR/v1/auth/kubernetes/login")
if echo "$AUTH_RESPONSE" | grep -q '"errors"'; then
  echo "Error: Authentication with Vault failed."
  echo "Response: $AUTH_RESPONSE"
  exit 1
fi
CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')
echo "Authentication successful. Client Token: $CLIENT_TOKEN"

# 6. Test Reading the Secret
print_header "Step 6: Testing Secret Access"
SECRET_RESPONSE=$(curl --silent --header "X-Vault-Token: $CLIENT_TOKEN" "$VAULT_ADDR/v1/$SECRET_PATH")
if echo "$SECRET_RESPONSE" | grep -q '"errors"'; then
  echo "Error: Failed to read secret from Vault."
  echo "Response: $SECRET_RESPONSE"
  exit 1
fi
echo "Secret retrieved successfully: $SECRET_RESPONSE"

# 7. Check Secrets Store CSI Driver Logs
print_header "Step 7: Checking Secrets Store CSI Driver Logs"
kubectl logs -n kube-system -l app=secrets-store-csi-driver || {
  echo "Error: Could not retrieve Secrets Store CSI Driver logs."
  exit 1
}

echo "All checks completed successfully!"