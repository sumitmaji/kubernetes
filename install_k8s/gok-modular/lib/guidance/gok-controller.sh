#!/bin/bash
# Vault reset logic for gok-controller (added/merged from original vault reset section).

# Function to reset vault for gok-controller
reset_vault_gok_controller() {
    echo "Resetting vault integration for gok-controller..."

    # Check if gok-controller namespace exists
    if kubectl get namespace gok-controller >/dev/null 2>&1; then
        echo "Cleaning up gok-controller vault secrets..."

        # Remove vault-related secrets and configmaps
        kubectl delete secret --all -n gok-controller --selector=app=gok-controller,vault=true --ignore-not-found=true
        kubectl delete configmap --all -n gok-controller --selector=app=gok-controller,vault=true --ignore-not-found=true

        # Remove SecretProviderClass if it exists
        kubectl delete secretproviderclass gok-controller-provider -n gok-controller --ignore-not-found=true

        echo "✅ Vault integration reset for gok-controller completed"
    else
        echo "ℹ️ gok-controller namespace not found, vault integration already cleaned"
    fi
}
export -f reset_vault_gok_controller

# Function to reset gok-controller (copied from original gokControllerReset)
reset_gok_controller() {
    echo "Resetting gok-controller..."

    # Uninstall gok-controller using Helm
    helm uninstall gok-controller -n gok-controller --ignore-not-found=true

    # Delete the gok-controller namespace
    kubectl delete ns gok-controller --ignore-not-found=true

    echo "✅ gok-controller reset completed"
}
export -f reset_gok_controller