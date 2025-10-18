#!/bin/bash
# Validation logic for gok-controller (extracted/copied from original install validation section).

# Function to validate gok-controller install
validate_gok_controller() {
    echo "Validating gok-controller installation..."

    # Check if namespace exists
    if ! kubectl get namespace gok-controller >/dev/null 2>&1; then
        echo "❌ gok-controller namespace not found"
        return 1
    fi

    # Check if helm release exists
    if ! helm list -n gok-controller 2>/dev/null | grep -q "gok-controller"; then
        echo "❌ gok-controller helm release not found"
        return 1
    fi

    # Check if pods are running
    local ready_pods=$(kubectl get pods -n gok-controller -l app.kubernetes.io/name=gok-controller -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -c "Running" || echo "0")
    local total_pods=$(kubectl get pods -n gok-controller -l app.kubernetes.io/name=gok-controller --no-headers 2>/dev/null | wc -l)

    if [[ "$ready_pods" -eq "$total_pods" && "$total_pods" -gt 0 ]]; then
        echo "✅ gok-controller validation passed - $ready_pods/$total_pods pods running"
        return 0
    else
        echo "⚠️ gok-controller validation warning - $ready_pods/$total_pods pods running"
        return 1
    fi

    # Check ingress
    if kubectl get ingress gok-controller -n gok-controller >/dev/null 2>&1; then
        echo "✅ gok-controller ingress found"
    else
        echo "⚠️ gok-controller ingress not found"
    fi
}
export -f validate_gok_controller