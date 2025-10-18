#!/bin/bash

# DevWorkspace Reset Module

reset_workspace() {
    log_component_start "workspace" "Resetting DevWorkspaces"
    
    # List all workspaces
    log_substep "Finding all DevWorkspaces"
    local all_workspaces=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null)
    
    if [[ -z "$all_workspaces" ]]; then
        log_info "No DevWorkspaces found"
        log_component_success "workspace" "Nothing to reset"
        return 0
    fi
    
    # Display found workspaces
    echo -e "\n${COLOR_YELLOW}Found DevWorkspaces:${COLOR_RESET}"
    echo "$all_workspaces" | while read -r line; do
        local ns=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{print $2}')
        echo "  • $ns/$name"
    done
    echo
    
    # Confirm deletion
    read -p "Delete all DevWorkspaces? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Workspace deletion cancelled"
        return 0
    fi
    
    # Delete each workspace
    echo "$all_workspaces" | while read -r line; do
        local ns=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{print $2}')
        log_substep "Deleting $ns/$name"
        if execute_with_suppression kubectl delete devworkspace "$name" -n "$ns" --timeout=120s; then
            log_success "Deleted $ns/$name"
        else
            log_error "Failed to delete $ns/$name"
        fi
    done
    
    # Optional: Clean up user namespaces
    log_substep "Checking for empty user namespaces"
    local user_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "^che-user" | awk '{print $1}')
    
    if [[ -n "$user_namespaces" ]]; then
        echo -e "\n${COLOR_YELLOW}Found user namespaces:${COLOR_RESET}"
        echo "$user_namespaces" | while read -r ns; do
            local dw_count=$(kubectl get devworkspaces -n "$ns" --no-headers 2>/dev/null | wc -l)
            echo "  • $ns ($dw_count workspace(s))"
        done
        echo
        
        read -p "Delete empty user namespaces? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$user_namespaces" | while read -r ns; do
                local dw_count=$(kubectl get devworkspaces -n "$ns" --no-headers 2>/dev/null | wc -l)
                if [[ $dw_count -eq 0 ]]; then
                    log_substep "Deleting empty namespace: $ns"
                    if execute_with_suppression kubectl delete namespace "$ns" --timeout=120s; then
                        log_success "Deleted $ns"
                    else
                        log_error "Failed to delete $ns"
                    fi
                else
                    log_info "Skipping $ns (contains $dw_count workspace(s))"
                fi
            done
        else
            log_info "Skipping namespace deletion"
        fi
    fi
    
    log_component_success "workspace" "DevWorkspace reset complete"
}

export -f reset_workspace
