#!/bin/bash
# Usage: ./login.sh <username> <password>

API_URL="https://gok-login.gokcloud.com/login"
USERNAME="$1"
PASSWORD="$2"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <username> <password>"
  exit 1
fi


echo "API URL: $API_URL"
echo "Username: $USERNAME"
echo "Password: [hidden]"

if [ "$VERBOSE" = "1" ]; then
  echo "Curl verbose mode enabled."
  RESPONSE=$(curl -vk -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")
else
  RESPONSE=$(curl -sk -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")
fi


# Extract access_token from response
ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: access_token not found in response."
  exit 2
fi

echo "access_token extracted."

USER_HOME=$(eval echo "~$USER")
KUBE_DIR="$USER_HOME/.kube"
mkdir -p "$KUBE_DIR"

# Create config file
cat <<EOF > "$KUBE_DIR/config"
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://10.0.0.244:6443
    insecure-skip-tls-verify: true
  name: k8s
users:
- name: user
  user:
    token: $ACCESS_TOKEN
contexts:
- context:
    cluster: k8s
    user: user
    namespace: $USERNAME
  name: k8s
current-context: k8s
EOF

echo "Kubeconfig created at $KUBE_DIR/config"
