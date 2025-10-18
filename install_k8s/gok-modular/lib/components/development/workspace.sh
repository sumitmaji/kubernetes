#!/bin/bash

# GOK DevWorkspace Management Module
# Provides DevWorkspace creation and deletion for Eclipse Che

# Create DevWorkspace
create_devworkspace() {
    log_component_start "devworkspace" "Creating Che DevWorkspace"
    
    # Prompt for workspace details
    local NAMESPACE=$(promptUserInput "Enter namespace (che-user): " "che-user")
    local USERNAME=$(promptUserInput "Enter username (user1): " "user1")
    local WORKSPACE=$(promptUserInput "Enter workspace name (devworkspace1): " "devworkspace1")
    local MANIFEST_FILE=$(promptUserInput "Enter devworkspace manifest file path (devworkspace.yaml): " "devworkspace.yaml")
    
    export CHE_USER_NAMESPACE="$NAMESPACE"
    export CHE_USER_NAME="$USERNAME"
    export CHE_WORKSPACE_NAME="$WORKSPACE"
    export DW_FILE="$MANIFEST_FILE"
    export DW_DELETE="false"
    
    log_substep "Workspace details:"
    log_substep "  Namespace: ${COLOR_CYAN}${NAMESPACE}${COLOR_RESET}"
    log_substep "  Username: ${COLOR_CYAN}${USERNAME}${COLOR_RESET}"
    log_substep "  Workspace: ${COLOR_CYAN}${WORKSPACE}${COLOR_RESET}"
    log_substep "  Manifest: ${COLOR_CYAN}${MANIFEST_FILE}${COLOR_RESET}"
    
    # Check Python dependencies
    log_substep "Checking Python dependencies"
    if ! python3 -c "import kubernetes" &>/dev/null; then
        log_info "Installing python3-kubernetes"
        if execute_with_suppression apt-get install -y python3-kubernetes; then
            log_success "python3-kubernetes installed"
        else
            log_error "Failed to install python3-kubernetes"
            return 1
        fi
    else
        log_success "python3-kubernetes already installed"
    fi
    
    if ! python3 -c "import yaml" &>/dev/null; then
        log_info "Installing python3-yaml"
        if execute_with_suppression apt-get install -y python3-yaml; then
            log_success "python3-yaml installed"
        else
            log_error "Failed to install python3-yaml"
            return 1
        fi
    else
        log_success "python3-yaml already installed"
    fi
    
    # Execute DevWorkspace creation
    log_substep "Creating DevWorkspace"
    local che_dir="$MOUNT_PATH/kubernetes/install_k8s/eclipseche"
    
    if [[ ! -d "$che_dir" ]]; then
        log_error "Eclipse Che directory not found: $che_dir"
        log_component_error "devworkspace" "Eclipse Che directory missing"
        return 1
    fi
    
    if execute_with_suppression pushd "$che_dir"; then
        if execute_with_suppression python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/apply_devworkspace.py"; then
            log_success "DevWorkspace created successfully"
            execute_with_suppression popd
            log_component_success "devworkspace" "DevWorkspace '$WORKSPACE' created in namespace '$NAMESPACE'"
            return 0
        else
            log_error "DevWorkspace creation failed"
            execute_with_suppression popd
            log_component_error "devworkspace" "DevWorkspace creation failed"
            return 1
        fi
    else
        log_error "Failed to access Eclipse Che directory"
        return 1
    fi
}

# Delete DevWorkspace
delete_devworkspace() {
    log_component_start "devworkspace" "Deleting Che DevWorkspace"
    
    # Prompt for workspace details
    local NAMESPACE=$(promptUserInput "Enter namespace: " "che-user")
    local USERNAME=$(promptUserInput "Enter username: " "user1")
    local WORKSPACE=$(promptUserInput "Enter workspace name: " "devworkspace1")
    local MANIFEST_FILE=$(promptUserInput "Enter devworkspace manifest file path: " "devworkspace.yaml")
    
    export CHE_USER_NAMESPACE="$NAMESPACE"
    export CHE_USER_NAME="$USERNAME"
    export CHE_WORKSPACE_NAME="$WORKSPACE"
    export DW_FILE="$MANIFEST_FILE"
    export DW_DELETE="true"
    
    log_substep "Workspace details:"
    log_substep "  Namespace: ${COLOR_CYAN}${NAMESPACE}${COLOR_RESET}"
    log_substep "  Username: ${COLOR_CYAN}${USERNAME}${COLOR_RESET}"
    log_substep "  Workspace: ${COLOR_CYAN}${WORKSPACE}${COLOR_RESET}"
    
    # Execute DevWorkspace deletion
    log_substep "Deleting DevWorkspace"
    local che_dir="$MOUNT_PATH/kubernetes/install_k8s/eclipseche"
    
    if [[ ! -d "$che_dir" ]]; then
        log_error "Eclipse Che directory not found: $che_dir"
        log_component_error "devworkspace" "Eclipse Che directory missing"
        return 1
    fi
    
    if execute_with_suppression pushd "$che_dir"; then
        if execute_with_suppression python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/apply_devworkspace.py"; then
            log_success "DevWorkspace deleted successfully"
            execute_with_suppression popd
            log_component_success "devworkspace" "DevWorkspace '$WORKSPACE' deleted from namespace '$NAMESPACE'"
            return 0
        else
            log_error "DevWorkspace deletion failed"
            execute_with_suppression popd
            log_component_error "devworkspace" "DevWorkspace deletion failed"
            return 1
        fi
    else
        log_error "Failed to access Eclipse Che directory"
        return 1
    fi
}

# Install workspace (alias for create_devworkspace)
install_workspace() {
    create_devworkspace
}

# Export functions
export -f create_devworkspace
export -f delete_devworkspace
export -f install_workspace
