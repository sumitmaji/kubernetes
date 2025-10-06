#!/bin/bash

ADMIN_USERNAME=$1
ADMIN_PASSWORD=$2
# Validate Admin Username and Password
if [ -z "$ADMIN_USERNAME" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "Error: Admin username and password must be provided as arguments."
    echo "Usage: $0 <admin_username> <admin_password>"
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
LDAP_PROVIDER_NAME="ldap" # Name of the LDAP user federation provider
GROUP_MAPPER_NAME="groups"

# LDAP Group Mapper Configuration Variables
LDAP_GROUPS_DN="ou=groups,${DC}"
LDAP_GROUP_NAME_ATTRIBUTE="cn"
LDAP_GROUP_MEMBER_ATTRIBUTE="memberUid"
LDAP_GROUP_OBJECT_CLASSES="posixGroup,top"
LDAP_MODE="LDAP_ONLY"

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

# Fetch Components for the Realm
COMPONENTS=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components?parentId=${REALM_ID}&type=org.keycloak.storage.UserStorageProvider" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

if [ -z "$COMPONENTS" ]; then
  echo "Failed to fetch components for realm '${REALM_NAME}' with parentId '${REALM_ID}'."
  exit 1
fi

# Extract LDAP Provider ID from Components
LDAP_PROVIDER_ID=$(echo "$COMPONENTS" | jq -r --arg LDAP_PROVIDER_NAME "$LDAP_PROVIDER_NAME" '.[] | select(.name == $LDAP_PROVIDER_NAME) | .id')

if [ -z "$LDAP_PROVIDER_ID" ]; then
  echo "Failed to fetch LDAP Provider ID for provider '${LDAP_PROVIDER_NAME}'. Check if the LDAP user federation exists."
  exit 1
fi

echo "Fetched LDAP Provider ID: $LDAP_PROVIDER_ID"

# JSON Configuration for LDAP Group Mapper
GROUP_MAPPER_CONFIG=$(cat <<EOF
{
  "parentId": "${LDAP_PROVIDER_ID}",
  "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
  "name": "${GROUP_MAPPER_NAME}",
  "providerId": "group-ldap-mapper",
  "config": {
    "membership.attribute.type": ["UID"],
    "mode": ["${LDAP_MODE}"],
    "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
    "groups.dn": ["${LDAP_GROUPS_DN}"],
    "group.name.ldap.attribute": ["${LDAP_GROUP_NAME_ATTRIBUTE}"],
    "group.object.classes": ["${LDAP_GROUP_OBJECT_CLASSES}"],
    "preserve.group.inheritance": ["false"],
    "ignore.missing.groups": ["false"],
    "membership.ldap.attribute": ["${LDAP_GROUP_MEMBER_ATTRIBUTE}"],
    "membership.user.ldap.attribute": ["uid"],
    "groups.ldap.filter": [""],
    "memberof.ldap.attribute": ["memberOf"],
    "mapped.group.attributes": [""],
    "drop.non.existing.groups.during.sync": ["false"],
    "groups.path": ["/"]
  }
}
EOF
)

# Create LDAP Group Mapper
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/components" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${GROUP_MAPPER_CONFIG}")

if [ "$RESPONSE" -eq 201 ]; then
  echo "LDAP Group Mapper '${GROUP_MAPPER_NAME}' created successfully for the '${LDAP_PROVIDER_NAME}' provider in the '${REALM_NAME}' realm."
else
  echo "Failed to create LDAP Group Mapper. HTTP Response Code: $RESPONSE"
fi