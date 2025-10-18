#!/bin/bash

# Eclipse Che Validation Module

validate_che() {
    local CHE_NAMESPACE="eclipse-che"
    local errors=0
    
    # Check if namespace exists
    if ! kubectl get namespace "$CHE_NAMESPACE" &>/dev/null; then
        echo "❌ Namespace '$CHE_NAMESPACE' not found"
        ((errors++))
    else
        echo "✅ Namespace '$CHE_NAMESPACE' exists"
    fi
    
    # Check chectl
    if ! command -v chectl &>/dev/null; then
        echo "❌ chectl not installed"
        ((errors++))
    else
        echo "✅ chectl installed"
    fi
    
    # Check CheCluster CR
    if ! kubectl get checluster -n "$CHE_NAMESPACE" &>/dev/null; then
        echo "❌ CheCluster resource not found"
        ((errors++))
    else
        echo "✅ CheCluster resource exists"
    fi
    
    # Check Che pods
    local pods_ready=$(kubectl get pods -n "$CHE_NAMESPACE" --no-headers 2>/dev/null | grep -c "Running")
    if [[ $pods_ready -eq 0 ]]; then
        echo "❌ No Che pods running"
        ((errors++))
    else
        echo "✅ Che pods running: $pods_ready"
    fi
    
    return $errors
}

export -f validate_che
