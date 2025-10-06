#!/bin/bash

# Script to update component values files with centralized OAuth/OIDC configuration
# This script sources the keycloak/config file and updates values files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config"

# Source the centralized configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

source "$CONFIG_FILE"

echo "Updating component values files with centralized OAuth/OIDC configuration..."

# Update ArgoCD values.yaml
ARGOCD_VALUES="$SCRIPT_DIR/../argocd/values.yaml"
if [ -f "$ARGOCD_VALUES" ]; then
    echo "Updating ArgoCD values.yaml at $ARGOCD_VALUES..."
    echo "OIDC_ISSUE_URL: $OIDC_ISSUE_URL"
    # Use sed to replace the hardcoded issuer URL (with proper escaping)
    sed -i "s|https://keycloak\.gokcloud\.com/realms/GokDevelopers|$OIDC_ISSUE_URL|g" "$ARGOCD_VALUES"
    sed -i "s|gok-developers-client|$OIDC_CLIENT_ID|g" "$ARGOCD_VALUES"
    echo "ArgoCD values.yaml updated"
else
    echo "ArgoCD values.yaml not found at $ARGOCD_VALUES"
fi

# Update Cloud Shell values.yaml
CLOUD_SHELL_VALUES="$SCRIPT_DIR/../cloud-shell/gok/chart/values.yaml"
if [ -f "$CLOUD_SHELL_VALUES" ]; then
    echo "Updating Cloud Shell values.yaml..."
    sed -i "s|https://keycloak\.gokcloud\.com/realms/GokDevelopers|$OIDC_ISSUE_URL|g" "$CLOUD_SHELL_VALUES"
    sed -i "s|gok-developers-client|$OIDC_CLIENT_ID|g" "$CLOUD_SHELL_VALUES"
fi

# Update Console values.yaml
CONSOLE_VALUES="$SCRIPT_DIR/../console/app/chart/values.yaml"
if [ -f "$CONSOLE_VALUES" ]; then
    echo "Updating Console values.yaml..."
    sed -i "s|https://keycloak\.gokcloud\.com/realms/GokDevelopers|$OIDC_ISSUE_URL|g" "$CONSOLE_VALUES"
fi

# Update GOK Cloud components
GOK_AGENT_VALUES="$SCRIPT_DIR/../gok-cloud/agent/chart/values.yaml"
if [ -f "$GOK_AGENT_VALUES" ]; then
    echo "Updating GOK Agent values.yaml..."
    sed -i "s|https://keycloak\.gokcloud\.com/realms/GokDevelopers|$OIDC_ISSUE_URL|g" "$GOK_AGENT_VALUES"
fi

GOK_CONTROLLER_VALUES="$SCRIPT_DIR/../gok-cloud/controller/chart/values.yaml"
if [ -f "$GOK_CONTROLLER_VALUES" ]; then
    echo "Updating GOK Controller values.yaml..."
    sed -i "s|https://keycloak\.gokcloud\.com/realms/GokDevelopers|$OIDC_ISSUE_URL|g" "$GOK_CONTROLLER_VALUES"
fi

echo "Component values files updated successfully!"
echo ""
echo "To apply these changes, you may need to:"
echo "1. Reinstall the affected components"
echo "2. Or manually update the running deployments"
echo ""
echo "Current centralized configuration:"
echo "OIDC_ISSUE_URL: $OIDC_ISSUE_URL"
echo "OIDC_CLIENT_ID: $OIDC_CLIENT_ID"
echo "REALM: $REALM"