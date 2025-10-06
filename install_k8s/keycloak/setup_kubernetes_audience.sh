#!/bin/bash

ADMIN_USERNAME=$1
ADMIN_PASSWORD=$2

if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "Usage: $0 <admin_username> <admin_password>"
    exit 1
fi

# Load environment/config if needed
source ${MOUNT_PATH}/kubernetes/install_k8s/util
source ${MOUNT_PATH}/kubernetes/install_k8s/config
source ${MOUNT_PATH}/kubernetes/install_k8s/ldap/config/config

# Define required variables and functions inline to avoid sourcing gok (which has main execution)
export KEYCLOAK=keycloak

getKeycloakConfig(){
  # Source the centralized OAuth/OIDC configuration
  source "$(dirname "$0")/config"

  # Export the OAuth/OIDC configuration values
  IFS='' read -r -d '' OAUTH <<"EOF"
export OIDC_ISSUE_URL=$OIDC_ISSUE_URL
export OIDC_CLIENT_ID=$OIDC_CLIENT_ID
export OIDC_USERNAME_CLAIM=$OIDC_USERNAME_CLAIM
export OIDC_GROUPS_CLAIM=$OIDC_GROUPS_CLAIM
export REALM=$REALM
export AUTH0_DOMAIN=$AUTH0_DOMAIN
export APP_HOST=$APP_HOST
export JWKS_URL=$JWKS_URL
EOF
echo "$OAUTH"
}

fullKeycloakUrl(){
  echo "${KEYCLOAK}.${GOK_ROOT_DOMAIN}"
}

# Load keycloak config for REALM
source ${MOUNT_PATH}/kubernetes/install_k8s/keycloak/config

echo "$(getKeycloakConfig)"

KEYCLOAK_URL="https://$(fullKeycloakUrl)" # Keycloak URL
REALM_NAME="${REALM}" # Name of the realm
CLIENT_ID="gok-developers-client"
SCOPE_NAME="untrusted-audience"

# Get admin access token
ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USERNAME}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "Failed to get access token. Check your admin credentials."
  exit 1
fi

# Create the client scope
SCOPE_CONFIG=$(cat <<EOF
{
  "name": "${SCOPE_NAME}",
  "description": "Custom scope of gok-login to include kubernetes as its intended audience",
  "protocol": "openid-connect",
  "attributes": {
    "display.on.consent.screen": "false",
    "include.in.token.scope": "true"
  }
}
EOF
)

SCOPE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/client-scopes" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${SCOPE_CONFIG}")

if [ "$SCOPE_RESPONSE" -ne 201 ]; then
  echo "Failed to create client scope. HTTP Response Code: $SCOPE_RESPONSE"
  exit 1
fi

# Get the ID of the new scope
SCOPE_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/client-scopes" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" | jq -r ".[] | select(.name==\"${SCOPE_NAME}\") | .id")

# Add the audience protocol mapper
MAPPER_CONFIG=$(cat <<EOF
{
  "name": "kubernetes-as-audience",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-audience-mapper",
  "config": {
    "included.client.audience": "${CLIENT_ID}",
    "id.token.claim": "true",
    "access.token.claim": "true"
  }
}
EOF
)

curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/client-scopes/${SCOPE_ID}/protocol-mappers/models" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${MAPPER_CONFIG}"

# Get the client UUID
CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.[0].id')

# Assign the scope as a default client scope
curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients/${CLIENT_UUID}/default-client-scopes/${SCOPE_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json"

echo "Scope '${SCOPE_NAME}' with audience mapper added and assigned as default to client '${CLIENT_ID}'."