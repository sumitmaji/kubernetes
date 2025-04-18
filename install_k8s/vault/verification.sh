#!/bin/bash

# Variables
VAULT_NAMESPACE="vault"  # Namespace where Vault is running
VAULT_POD="vault-0"      # Name of the Vault pod
VAULT_ROLE="my-vault-role"  # Name of the Vault role to verify
VAULT_POLICY="my-vault-policy"  # Name of the Vault policy to verify
SECRET_PATH="secret/my-secret"  # Path to the secret in Vault
KUBERNETES_API_SERVER="https://11.0.0.1:6643"  # Replace with your Kubernetes API server URL

# Function to print a header
print_header() {
  echo "========================================"
  echo "$1"
  echo "========================================"
}

# 1. Verify Vault Policy
print_header "Step 1: Verifying Vault Policy"
kubectl exec -it "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault policy read "$VAULT_POLICY" > /tmp/vault_policy_output 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: Vault policy '$VAULT_POLICY' does not exist."
  exit 1
fi

# Check if the policy grants "read" capability
grep "$SECRET_PATH" /tmp/vault_policy_output | grep -q "read"
if [ $? -ne 0 ]; then
  echo "Error: Vault policy '$VAULT_POLICY' does not grant 'read' capability for the secret path '$SECRET_PATH'."
  exit 1
fi

# Check if the policy grants "list" capability
grep "$SECRET_PATH" /tmp/vault_policy_output | grep -q "list"
if [ $? -ne 0 ]; then
  echo "Error: Vault policy '$VAULT_POLICY' does not grant 'list' capability for the secret path '$SECRET_PATH'."
  exit 1
fi

echo "Vault policy '$VAULT_POLICY' is properly configured with 'read' and 'list' capabilities for the secret path '$SECRET_PATH'."

# 2. Verify Vault Role
print_header "Step 2: Verifying Vault Role"
kubectl exec -it "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault read auth/kubernetes/role/"$VAULT_ROLE" > /tmp/vault_role_output 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: Vault role '$VAULT_ROLE' does not exist."
  exit 1
fi

# Check if the role is bound to the correct service account and namespace
grep "bound_service_account_names" /tmp/vault_role_output | grep -q "vault"
if [ $? -ne 0 ]; then
  echo "Error: Vault role '$VAULT_ROLE' is not bound to the correct service account."
  exit 1
fi

grep "bound_service_account_namespaces" /tmp/vault_role_output | grep -q "$VAULT_NAMESPACE"
if [ $? -ne 0 ]; then
  echo "Error: Vault role '$VAULT_ROLE' is not bound to the correct namespace '$VAULT_NAMESPACE'."
  exit 1
fi

# Check if the role references the correct policy
grep "policies" /tmp/vault_role_output | grep -q "$VAULT_POLICY"
if [ $? -ne 0 ]; then
  echo "Error: Vault role '$VAULT_ROLE' does not reference the policy '$VAULT_POLICY'."
  exit 1
fi
echo "Vault role '$VAULT_ROLE' is properly configured."

# 3. Verify Kubernetes Authentication Configuration
print_header "Step 3: Verifying Kubernetes Authentication Configuration"
kubectl exec -it "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault read auth/kubernetes/config > /tmp/vault_k8s_config_output 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: Kubernetes authentication is not configured in Vault."
  exit 1
fi

# Check if the Kubernetes API server is correctly configured
grep "kubernetes_host" /tmp/vault_k8s_config_output | grep -q "$KUBERNETES_API_SERVER"
if [ $? -ne 0 ]; then
  echo "Error: Kubernetes API server is not correctly configured in Vault."
  exit 1
fi

# Check if the CA certificate is present
grep -q "kubernetes_ca_cert" /tmp/vault_k8s_config_output
if [ $? -ne 0 ]; then
  echo "Error: Kubernetes CA certificate is not configured in Vault."
  exit 1
fi

# Check if the token reviewer JWT is set
grep -q "token_reviewer_jwt_set" /tmp/vault_k8s_config_output
if [ $? -ne 0 ]; then
  echo "Error: Token reviewer JWT is not set in Vault."
  exit 1
fi
echo "Kubernetes authentication configuration is properly set up in Vault."

# 4. Verify Secret Exists in Vault
print_header "Step 4: Verifying Secret in Vault"
kubectl exec -it "$VAULT_POD" -n "$VAULT_NAMESPACE" -- vault kv get "$SECRET_PATH" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: Secret '$SECRET_PATH' does not exist in Vault."
  exit 1
fi
echo "Secret '$SECRET_PATH' exists in Vault."

# Final Success Message
print_header "All Checks Passed"
echo "Vault policy, role, Kubernetes authentication configuration, and secret are properly configured."