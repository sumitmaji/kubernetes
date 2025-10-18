#!/bin/bash

# DevWorkspace V2 Validation Module

validate_workspacev2() {
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
    
    # Check Eclipse Che directory structure
    if [[ ! -d "$MOUNT_PATH/kubernetes/install_k8s/eclipseche" ]]; then
        echo "❌ Eclipse Che directory not found"
        ((errors++))
    else
        echo "✅ Eclipse Che directory exists"
    fi
    
    # Check for create_devworkspace.py script
    if [[ ! -f "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/create_devworkspace.py" ]]; then
        echo "❌ create_devworkspace.py script not found"
        ((errors++))
    else
        echo "✅ create_devworkspace.py script exists"
    fi
    
    # Check for existing DevWorkspaces
    local workspace_count=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [[ $workspace_count -eq 0 ]]; then
        echo "ℹ️  No DevWorkspaces found (this is normal for new installations)"
    else
        echo "✅ DevWorkspaces found: $workspace_count"
    fi
    
    # Check Eclipse Che installation
    if ! kubectl get namespace eclipse-che &>/dev/null; then
        echo "⚠️  Eclipse Che namespace not found (install Eclipse Che first)"
        ((errors++))
    else
        echo "✅ Eclipse Che namespace exists"
    fi
    
    return $errors
}

export -f validate_workspacev2
