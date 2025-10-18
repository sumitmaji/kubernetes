#!/bin/bash

# DevWorkspace V2 Reset Module

reset_workspacev2() {
    log_component_start "workspacev2" "Resetting DevWorkspaces V2"
    
    # Option 1: Delete specific workspace
    echo ""
    echo "Select reset option:"
    echo "  1) Delete specific workspace (by template)"
    echo "  2) Delete all workspaces for a user"
    echo "  3) Delete all workspaces (all users)"
    echo ""
    
    local reset_option=$(promptUserInput "Enter option (1): " "1")
    
    case "$reset_option" in
        1)
            # Delete specific workspace using the delete function
            log_info "Deleting specific workspace"
            delete_devworkspace_v2
            ;;
            
        2)
            # Delete all workspaces for a specific user
            local USERNAME=$(promptUserInput "Enter username: " "user1")
            log_substep "Finding workspaces for user: $USERNAME"
            
            local user_workspaces=$(kubectl get devworkspaces -n "$USERNAME" --no-headers 2>/dev/null)
            
            if [[ -z "$user_workspaces" ]]; then
                log_info "No workspaces found for user '$USERNAME'"
                log_component_success "workspacev2" "Nothing to reset"
                return 0
            fi
            
            echo -e "\n${COLOR_YELLOW}Workspaces for user $USERNAME:${COLOR_RESET}"
            echo "$user_workspaces" | while read -r line; do
                local name=$(echo "$line" | awk '{print $1}')
                echo "  • $name"
            done
            echo
            
            read -p "Delete all workspaces for user '$USERNAME'? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Workspace deletion cancelled"
                return 0
            fi
            
            # Delete each workspace
            echo "$user_workspaces" | while read -r line; do
                local name=$(echo "$line" | awk '{print $1}')
                log_substep "Deleting workspace: $name"
                if execute_with_suppression kubectl delete devworkspace "$name" -n "$USERNAME" --timeout=120s; then
                    log_success "Deleted $name"
                else
                    log_error "Failed to delete $name"
                fi
            done
            
            # Ask about namespace deletion
            local remaining=$(kubectl get devworkspaces -n "$USERNAME" --no-headers 2>/dev/null | wc -l)
            if [[ $remaining -eq 0 ]]; then
                echo
                read -p "Delete empty namespace '$USERNAME'? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_substep "Deleting namespace: $USERNAME"
                    if execute_with_suppression kubectl delete namespace "$USERNAME" --timeout=120s; then
                        log_success "Namespace deleted"
                    else
                        log_error "Failed to delete namespace"
                    fi
                fi
            fi
            
            log_component_success "workspacev2" "User workspaces reset complete"
            ;;
            
        3)
            # Delete all workspaces across all users
            log_substep "Finding all DevWorkspaces"
            local all_workspaces=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null)
            
            if [[ -z "$all_workspaces" ]]; then
                log_info "No DevWorkspaces found"
                log_component_success "workspacev2" "Nothing to reset"
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
            read -p "Delete ALL DevWorkspaces? (y/N): " -n 1 -r
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
            local user_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "^(user[0-9]+|che-user)" | awk '{print $1}')
            
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
            
            log_component_success "workspacev2" "DevWorkspace V2 reset complete"
            ;;
            
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
}

export -f reset_workspacev2
