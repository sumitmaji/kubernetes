#!/bin/bash

ADMIN_USERNAME=$1
ADMIN_PASSWORD=$2
LDAP_BIND_CREDENTIAL=$3
if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ] || [ -z "$LDAP_BIND_CREDENTIAL" ]; then
  echo "Usage: $0 <admin-username> <admin-password> <ldap-bind-credential>"
  exit 1
fi

# The following lines are responsible for reading environment variables.
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

# Variables
KEYCLOAK_URL="https://$(fullKeycloakUrl)" # Keycloak URL
REALM_NAME="${REALM}" # Name of the realm
LDAP_PROVIDER_NAME="ldap"

# LDAP Configuration Variables
LDAP_CONNECTION_URL="ldap://ldap.ldap.svc.cloud.uat"
LDAP_BIND_DN="cn=admin,${DC}"
LDAP_USERS_DN="ou=users,${DC}"

# Get Admin Access Token
ACCESS_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USERNAME}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d 'grant_type=password' \
  -d 'client_id=admin-cli' | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to get access token. Check your admin credentials."
  exit 1
fi

# Fetch REALM_ID based on REALM_NAME
REALM_ID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" | jq -r --arg REALM_NAME "$REALM_NAME" '.[] | select(.realm == $REALM_NAME) | .id')

if [ -z "$REALM_ID" ]; then
  echo "Failed to fetch REALM_ID for realm '${REALM_NAME}'. Check if the realm exists."
  exit 1
fi

# JSON Configuration for LDAP User Federation
LDAP_CONFIG=$(cat <<EOF
{
  "config": {
    "enabled": ["true"],
    "vendor": ["other"],
    "connectionUrl": ["${LDAP_CONNECTION_URL}"],
    "startTls": ["false"],
    "useTruststoreSpi": ["always"],
    "connectionPooling": ["true"],
    "connectionTimeout": [""],
    "authType": ["simple"],
    "bindDn": ["${LDAP_BIND_DN}"],
    "bindCredential": ["${LDAP_BIND_CREDENTIAL}"],
    "editMode": ["READ_ONLY"],
    "usersDn": ["${LDAP_USERS_DN}"],
    "usernameLDAPAttribute": ["uid"],
    "rdnLDAPAttribute": ["uid"],
    "uuidLDAPAttribute": ["entryUUID"],
    "userObjectClasses": ["inetOrgPerson, posixAccount, top"],
    "customUserSearchFilter": [""],
    "searchScope": ["2"],
    "readTimeout": [""],
    "pagination": ["true"],
    "referral": [""],
    "importEnabled": ["true"],
    "syncRegistrations": ["true"],
    "batchSizeForSync": [""],
    "allowKerberosAuthentication": ["false"],
    "useKerberosForPasswordAuthentication": ["false"],
    "cachePolicy": ["DEFAULT"],
    "usePasswordModifyExtendedOp": ["false"],
    "validatePasswordPolicy": ["false"],
    "trustEmail": ["false"],
    "connectionTrace": ["false"],
    "krbPrincipalAttribute": ["krb5PrincipalName"],
    "changedSyncPeriod": ["-1"],
    "fullSyncPeriod": ["-1"]
  },
  "providerId": "ldap",
  "providerType": "org.keycloak.storage.UserStorageProvider",
  "parentId": "${REALM_ID}",
  "name": "${LDAP_PROVIDER_NAME}"
}
EOF
)

# Create LDAP User Federation
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${LDAP_CONFIG}")

if [ "$RESPONSE" -eq 201 ]; then
  echo "LDAP User Federation '${LDAP_PROVIDER_NAME}' created successfully in the '${REALM_NAME}' realm."
else
  echo "Failed to create LDAP User Federation. HTTP Response Code: $RESPONSE"
fi