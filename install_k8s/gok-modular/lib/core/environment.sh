#!/bin/bash

# GOK Environment Module - Domain and URL configuration functions

# OAuth and OIDC configurations
getOAuth0Config() {
    IFS='' read -r -d '' OAUTH <<"EOF"
export OIDC_ISSUE_URL=https://skmaji.auth0.com/
export OIDC_CLIENT_ID=C3UHISO3z60iF1JLG8L7VPUSWOASrJfO
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=http://localhost:8080/claims/groups
export AUTH0_DOMAIN=skmaji.auth0.com
export APP_HOST=kube.gokcloud.com
export JWKS_URL=$OIDC_ISSUE_URL/.well-known/jwks.json
EOF
    echo "$OAUTH"
}

getKeycloakConfig() {
    # Source the centralized OAuth/OIDC configuration from keycloak/config (if exists)
    local keycloak_config="${MOUNT_PATH}/kubernetes/install_k8s/keycloak/config"
    if [[ -f "$keycloak_config" ]]; then
        source "$keycloak_config"
    fi

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

# Generate root configuration
generate_root_config() {
    local config_output
    case ${IDENTITY_PROVIDER:-keycloak} in
        "auth0")
            config_output=$(getOAuth0Config)
            ;;
        "keycloak"|*)
            config_output=$(getKeycloakConfig)
            ;;
    esac
    
    # Create root_config if MOUNT_PATH is writable
    if [ -w "${MOUNT_PATH}" ]; then
        cat <<EOF > ${MOUNT_PATH}/root_config
${config_output}
EOF
    fi
    
    echo "$config_output"
}

# Domain helper functions
rootDomain() {
    echo "$ROOT_DOMAIN"
}

sedRootDomain() {
    echo "${ROOT_DOMAIN//\./\\.}"
}

registrySubdomain() {
    echo "$REGISTRY_SUBDOMAIN"
}

defaultSubdomain() {
    echo "$DEFAULT_SUBDOMAIN" 
}

keycloakSubdomain() {
    echo "$KEYCLOAK_SUBDOMAIN"
}

argocdSubdomain() {
    echo "$ARGOCD_SUBDOMAIN"
}

jupyterHubSubdomain() {
    echo "$JUPYTERHUB_SUBDOMAIN"
}

# Full URL generators
fullDefaultUrl() {
    echo "https://$(defaultSubdomain).$(rootDomain)"
}

fullRegistryUrl() {
    echo "https://$(registrySubdomain).$(rootDomain)"
}

fullKeycloakUrl() {
    echo "https://$(keycloakSubdomain).$(rootDomain)"
}

fullVaultUrl() {
    echo "https://vault.$(rootDomain)"
}

fullSpinnakerUrl() {
    echo "https://spinnaker.$(rootDomain)"
}

fullArgocdUrl() {
    echo "https://$(argocdSubdomain).$(rootDomain)"
}

fullJupyterUrl() {
    echo "https://$(jupyterHubSubdomain).$(rootDomain)"
}

fullGrafanaUrl() {
    echo "https://grafana.$(rootDomain)"
}

fullPrometheusUrl() {
    echo "https://prometheus.$(rootDomain)"
}

# Environment validation
validate_environment() {
    local required_vars=(
        "ROOT_DOMAIN"
        "DEFAULT_SUBDOMAIN"
        "REGISTRY_SUBDOMAIN"
        "KEYCLOAK_SUBDOMAIN"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Set default environment values if not provided
set_default_environment() {
    # Set defaults for common variables
    : ${ROOT_DOMAIN:="gokcloud.com"}
    : ${DEFAULT_SUBDOMAIN:="kube"}
    : ${REGISTRY_SUBDOMAIN:="registry"}
    : ${KEYCLOAK_SUBDOMAIN:="keycloak"}
    : ${ARGOCD_SUBDOMAIN:="argocd"}
    : ${JUPYTERHUB_SUBDOMAIN:="jupyter"}
    : ${IDENTITY_PROVIDER:="keycloak"}
    : ${CERTMANAGER_CHALLENGE_TYPE:="http01"}
    
    # Export the variables
    export ROOT_DOMAIN DEFAULT_SUBDOMAIN REGISTRY_SUBDOMAIN
    export KEYCLOAK_SUBDOMAIN ARGOCD_SUBDOMAIN JUPYTERHUB_SUBDOMAIN
    export IDENTITY_PROVIDER CERTMANAGER_CHALLENGE_TYPE
}

# Initialize environment
init_environment() {
    set_default_environment
    generate_root_config >/dev/null
    
    # Skip validation for help commands
    if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
        return 0
    fi
    
    validate_environment
}