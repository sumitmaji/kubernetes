#!/bin/bash

# DevWorkspace Validation Module

validate_workspace() {
    local errors=0
    
    # Check Python dependencies
    if ! python3 -c "import kubernetes" &>/dev/null; then
        echo "❌ python3-kubernetes not installed"
        ((errors++))
    else
        echo "✅ python3-kubernetes installed"
    fi
    
    if ! python3 -c "import yaml" &>/dev/null; then
        echo "❌ python3-yaml not installed"
        ((errors++))
    else
        echo "✅ python3-yaml installed"
    fi
    
    # Check DevWorkspace CRD
    if ! kubectl get crd devworkspaces.workspace.devfile.io &>/dev/null; then
        echo "❌ DevWorkspace CRD not found"
        ((errors++))
    else
        echo "✅ DevWorkspace CRD exists"
    fi
    
    # Check for existing DevWorkspaces
    local workspace_count=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [[ $workspace_count -eq 0 ]]; then
        echo "ℹ️  No DevWorkspaces found"
    else
        echo "✅ DevWorkspaces found: $workspace_count"
    fi
    
    return $errors
}

export -f validate_workspace
