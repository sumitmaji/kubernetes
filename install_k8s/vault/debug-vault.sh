#!/bin/bash

# Variables
NAMESPACE="default"  # Namespace where the application pod is running
POD_NAME="vault-secret-pod"  # Name of the application pod
VAULT_ROLE="my-role"  # Vault role name
VAULT_POLICY="my-policy"  # Vault policy name
VAULT_ADDR="https://vault.gokcloud.com"  # Vault server address
SECRET_PATH="secret/my-secret"  # Path to the secret in Vault
SAMPLE_VAULT_POLICY="my-vault-policy"
SAMPLE_VAULT_ROLE="my-vault-role"
SAMPLE_SERVICE_ACCOUNT="vault"
SAMPLE_NAMESPACE="vault"


# Function to print a header
print_header() {
  echo "========================================"
  echo "$1"
  echo "========================================"
}

# 1. Verify the Pod's Service Account
print_header "Step 1: Verifying Pod's Service Account"
SERVICE_ACCOUNT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "Error: Could not retrieve service account for pod $POD_NAME in namespace $NAMESPACE."
  echo "Skipping pod-specific tests..."
else
  echo "Service Account: $SERVICE_ACCOUNT"
fi

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

# 5. Test Authentication with Vault (Pod Test Case)
if [ -n "$SERVICE_ACCOUNT" ]; then
  print_header "Step 5: Testing Authentication with Vault (Pod Test Case)"
  echo "Retrieving service account token from the application pod..."
  TOKEN=$(kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    echo "Error: Could not retrieve service account token from pod $POD_NAME."
    echo "Skipping authentication test with pod."
  else
    echo "Testing authentication with Vault using the pod's service account token..."
    AUTH_RESPONSE=$(curl --silent --request POST --data '{"jwt": "'"$TOKEN"'", "role": "'"$VAULT_ROLE"'"}' "$VAULT_ADDR/v1/auth/kubernetes/login")
    if echo "$AUTH_RESPONSE" | grep -q '"errors"'; then
      echo "Error: Authentication with Vault failed."
      echo "Response: $AUTH_RESPONSE"
      exit 1
    fi
    CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')
    echo "Authentication successful. Client Token: $CLIENT_TOKEN"

    # Test Reading the Secret
    print_header "Step 6: Testing Secret Access"
    SECRET_RESPONSE=$(curl --silent --header "X-Vault-Token: $CLIENT_TOKEN" "$VAULT_ADDR/v1/$SECRET_PATH")
    if echo "$SECRET_RESPONSE" | grep -q '"errors"'; then
      echo "Error: Failed to read secret from Vault."
      echo "Response: $SECRET_RESPONSE"
      exit 1
    fi
    echo "Secret retrieved successfully: $SECRET_RESPONSE"
  fi
else
  echo "Skipping authentication test with pod as the pod is not running."
fi


# 6. Manually Test Authentication with Vault
print_header "Step 6: Testing Authentication with Vault"
echo "Creating policy and role in Vault..."
kubectl exec -it vault-0 -n vault -- vault policy write "$SAMPLE_VAULT_POLICY" - <<EOF
path "$SECRET_PATH" {
  capabilities = ["read", "list"]
}
EOF
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/"$SAMPLE_VAULT_POLICY" \
  bound_service_account_names="$SAMPLE_SERVICE_ACCOUNT" \
  bound_service_account_namespaces="$SAMPLE_NAMESPACE" \
  policies="$VAULT_POLICY" \
  ttl=1h || {
  echo "Error: Could not create role in Vault."
  exit 1
}
echo "Verifying role creation..."
kubectl exec -it vault-0 -n vault -- vault read auth/kubernetes/role/"$SAMPLE_VAULT_ROLE" || {
  echo "Error: Vault role $SAMPLE_VAULT_ROLE not found."
  exit 1
}
echo "Verifying policy creation..."
kubectl exec -it vault-0 -n vault -- vault policy read "$SAMPLE_VAULT_POLICY" || {
  echo "Error: Vault policy $SAMPLE_VAULT_POLICY not found."
  exit 1
}
echo "Verifying Kubernetes authentication configuration in Vault..."
kubectl exec -it vault-0 -n vault -- vault read auth/kubernetes/config || {
  echo "Error: Kubernetes authentication configuration in Vault is invalid."
  exit 1
}
echo "Retrieving service account token from the Vault pod..."
TOKEN=$(kubectl exec -it vault-0 -n vault -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "Error: Could not retrieve service account token from the Vault pod."
  exit 1
fi

echo "Testing authentication with Vault..."
AUTH_RESPONSE=$(curl --silent --request POST --data '{"jwt": "'"$TOKEN"'", "role": "'"$SAMPLE_VAULT_ROLE"'"}' "$VAULT_ADDR/v1/auth/kubernetes/login")
if echo "$AUTH_RESPONSE" | grep -q '"errors"'; then
  echo "Error: Authentication with Vault failed."
  echo "Response: $AUTH_RESPONSE"
  exit 1
fi
CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')
echo "Authentication successful. Client Token: $CLIENT_TOKEN"

# 7. Test Reading the Secret
print_header "Step 6: Testing Secret Access"
SECRET_RESPONSE=$(curl --silent --header "X-Vault-Token: $CLIENT_TOKEN" "$VAULT_ADDR/v1/$SECRET_PATH")
if echo "$SECRET_RESPONSE" | grep -q '"errors"'; then
  echo "Error: Failed to read secret from Vault."
  echo "Response: $SECRET_RESPONSE"
  exit 1
fi
echo "Secret retrieved successfully: $SECRET_RESPONSE"
kubectl exec -it vault-0 -n vault -- vault delete auth/kubernetes/role/$SAMPLE_VAULT_ROLE || {
  echo "Error: Could not delete role in Vault."
  exit 1
}
kubectl exec -it vault-0 -n vault -- vault policy delete $SAMPLE_VAULT_POLICY || {
  echo "Error: Could not delete policy in Vault."
  exit 1
}

kubectl exec -it vault-0 -n vault -- vault list auth/kubernetes/role || {
  echo "Error: Could not list roles in Vault."
  exit 1
}
kubectl exec -it vault-0 -n vault -- vault policy list || {
  echo "Error: Could not list policies in Vault."
  exit 1
}

# 8. Check Secrets Store CSI Driver Logs
print_header "Step 7: Checking Secrets Store CSI Driver Logs"
kubectl logs -n kube-system -l app=secrets-store-csi-driver || {
  echo "Error: Could not retrieve Secrets Store CSI Driver logs."
  exit 1
}

echo "All checks completed successfully!"