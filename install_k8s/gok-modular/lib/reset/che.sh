#!/bin/bash

# Eclipse Che Reset Module

reset_che() {
    local CHE_NAMESPACE="eclipse-che"
    
    log_component_start "che" "Resetting Eclipse Che"
    
    # Delete CheCluster CR
    log_substep "Deleting CheCluster resource"
    if kubectl get checluster -n "$CHE_NAMESPACE" &>/dev/null; then
        if execute_with_suppression kubectl delete checluster --all -n "$CHE_NAMESPACE" --timeout=300s; then
            log_success "CheCluster deleted"
        else
            log_error "Failed to delete CheCluster"
        fi
    else
        log_info "CheCluster not found"
    fi
    
    # Wait for pods to terminate
    log_substep "Waiting for pods to terminate"
    local timeout=300
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local pod_count=$(kubectl get pods -n "$CHE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
        if [[ $pod_count -eq 0 ]]; then
            log_success "All pods terminated"
            break
        fi
        sleep 5
        ((elapsed+=5))
    done
    
    # Delete namespace
    log_substep "Deleting namespace"
    if kubectl get namespace "$CHE_NAMESPACE" &>/dev/null; then
        if execute_with_suppression kubectl delete namespace "$CHE_NAMESPACE" --timeout=300s; then
            log_success "Namespace deleted"
        else
            log_error "Failed to delete namespace"
        fi
    else
        log_info "Namespace not found"
    fi
    
    # Uninstall chectl
    log_substep "Uninstalling chectl"
    if command -v chectl &>/dev/null; then
        if execute_with_suppression bash <(curl -sL https://che-incubator.github.io/chectl/uninstall.sh); then
            log_success "chectl uninstalled"
        else
            log_error "Failed to uninstall chectl"
        fi
    else
        log_info "chectl not installed"
    fi
    
    # Clean up user namespaces (optional)
    log_substep "Checking for user namespaces"
    local user_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "^che-user" | awk '{print $1}')
    if [[ -n "$user_namespaces" ]]; then
        log_info "Found user namespaces: $(echo $user_namespaces | tr '\n' ' ')"
        read -p "Delete user namespaces? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$user_namespaces" | while read -r ns; do
                log_substep "Deleting namespace: $ns"
                execute_with_suppression kubectl delete namespace "$ns" --timeout=300s
            done
            log_success "User namespaces deleted"
        else
            log_info "Skipping user namespace deletion"
        fi
    else
        log_info "No user namespaces found"
    fi
    
    log_component_success "che" "Eclipse Che reset complete"
}

export -f reset_che
