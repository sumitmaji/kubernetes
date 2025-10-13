#!/bin/bash
# lib/core/config.sh
# Simplified Configuration Loading for GOK Modular System

# Ensure this module is loaded only once
if [[ "${GOK_CONFIG_LOADED:-}" == "true" ]]; then
    return 0
fi

# Set default paths if not provided
: ${MOUNT_PATH:=/home/sumit/Documents/repository}
: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

# OAuth/OIDC configuration functions
getOAuth0Config(){
 IFS='' read -r -d '' OAUTH <<"EOL"
export OIDC_ISSUE_URL=https://skmaji.auth0.com/
export OIDC_CLIENT_ID=C3UHISO3z60iF1JLG8L7VPUSWOASrJfO
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=http://localhost:8080/claims/groups
export AUTH0_DOMAIN=skmaji.auth0.com
export APP_HOST=kube.gokcloud.com
export JWKS_URL=$OIDC_ISSUE_URL/.well-known/jwks.json
EOL
echo "$OAUTH"
}

getKeycloakConfig(){
  # Source the centralized OAuth/OIDC configuration from keycloak/config
  if [ -f "${MOUNT_PATH}/kubernetes/install_k8s/keycloak/config" ]; then
    source "${MOUNT_PATH}/kubernetes/install_k8s/keycloak/config"
  fi

  # Export the OAuth/OIDC configuration values
  IFS='' read -r -d '' OAUTH <<"EOL"
export OIDC_ISSUE_URL=$OIDC_ISSUE_URL
export OIDC_CLIENT_ID=$OIDC_CLIENT_ID
export OIDC_USERNAME_CLAIM=$OIDC_USERNAME_CLAIM
export OIDC_GROUPS_CLAIM=$OIDC_GROUPS_CLAIM
export REALM=$REALM
export AUTH0_DOMAIN=$AUTH0_DOMAIN
export APP_HOST=$APP_HOST
export JWKS_URL=$JWKS_URL
EOL
echo "$OAUTH"
}

# Initialize GOK configuration system (simplified)
init_gok_configuration() {
    # Source config files with error handling (same as original GOK)
    if [ -f "$WORKING_DIR/config" ]; then
        source "$WORKING_DIR/config"
    else
        echo "Warning: Config file not found at $WORKING_DIR/config" >&2
    fi

    # Create root_config if MOUNT_PATH is writable
    if [ -w "${MOUNT_PATH}" ]; then
        cat > ${MOUNT_PATH}/root_config << 'EOL'
export LETS_ENCRYPT_PROD_URL=https://acme-v02.api.letsencrypt.org/directory
export LETS_ENCRYPT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory
#dns, http, selfsigned
export CERTMANAGER_CHALANGE_TYPE=selfsigned
#staging, prod
export LETS_ENCRYPT_ENV=staging
export REGISTRY=registry
export KEYCLOAK=keycloak
export SPINNAKER=spinnaker
export VAULT=vault
export JUPYTERHUB=jupyterhub
export ARGOCD=argocd
export DEFAULT_SUBDOMAIN=kube
export GROUP_NAME=$GOK_ROOT_DOMAIN
#ldap, oidc
export AUTHENTICATION_METHOD=oidc
export IDENTITY_PROVIDER=${IDENTITY_PROVIDER}
$(
case ${IDENTITY_PROVIDER} in
  "oauth0")
    echo "$(getOAuth0Config)"
    ;;
  "keycloak")
    echo "$(getKeycloakConfig)"
    ;;
  *)
    echo "Unsupported identity provider: ${IDENTITY_PROVIDER}"
    ;;
esac
)
EOL
    fi

    # Source root_config if it exists
    if [ -f "${MOUNT_PATH}/root_config" ]; then
        source ${MOUNT_PATH}/root_config
    fi
}

# Mark configuration as loaded
export GOK_CONFIG_LOADED="true"
