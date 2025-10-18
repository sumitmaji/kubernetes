#!/bin/bash
# Validation logic for gok-agent (extracted/copied from original install validation section).

# Function to validate gok-agent install
validate_gok_agent() {
    echo "Validating gok-agent installation..."

    # Check if namespace exists
    if ! kubectl get namespace gok-agent >/dev/null 2>&1; then
        echo "❌ gok-agent namespace not found"
        return 1
    fi

    # Check if helm release exists
    if ! helm list -n gok-agent 2>/dev/null | grep -q "gok-agent"; then
        echo "❌ gok-agent helm release not found"
        return 1
    fi

    # Check if pods are running
    local ready_pods=$(kubectl get pods -n gok-agent -l app.kubernetes.io/name=gok-agent -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -c "Running" || echo "0")
    local total_pods=$(kubectl get pods -n gok-agent -l app.kubernetes.io/name=gok-agent --no-headers 2>/dev/null | wc -l)

    if [[ "$ready_pods" -eq "$total_pods" && "$total_pods" -gt 0 ]]; then
        echo "✅ gok-agent validation passed - $ready_pods/$total_pods pods running"
        return 0
    else
        echo "⚠️ gok-agent validation warning - $ready_pods/$total_pods pods running"
        return 1
    fi
}
export -f validate_gok_agent