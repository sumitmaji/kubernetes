#!/bin/bash
# Vault reset logic for gok-agent (added/merged from original vault reset section).

# Function to reset vault for gok-agent
reset_vault_gok_agent() {
    echo "Resetting vault integration for gok-agent..."

    # Check if gok-agent namespace exists
    if kubectl get namespace gok-agent >/dev/null 2>&1; then
        echo "Cleaning up gok-agent vault secrets..."

        # Remove vault-related secrets and configmaps
        kubectl delete secret --all -n gok-agent --selector=app=gok-agent,vault=true --ignore-not-found=true
        kubectl delete configmap --all -n gok-agent --selector=app=gok-agent,vault=true --ignore-not-found=true

        # Remove SecretProviderClass if it exists
        kubectl delete secretproviderclass gok-agent-provider -n gok-agent --ignore-not-found=true

        echo "✅ Vault integration reset for gok-agent completed"
    else
        echo "ℹ️ gok-agent namespace not found, vault integration already cleaned"
    fi
}
export -f reset_vault_gok_agent

# Function to reset gok-agent (copied from original gokAgentReset)
reset_gok_agent() {
    echo "Resetting gok-agent..."

    # Uninstall gok-agent using Helm
    helm uninstall gok-agent -n gok-agent --ignore-not-found=true

    # Delete the gok-agent namespace
    kubectl delete ns gok-agent --ignore-not-found=true

    echo "✅ gok-agent reset completed"
}
export -f reset_gok_agent