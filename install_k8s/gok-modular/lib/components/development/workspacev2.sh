#!/bin/bash

# GOK DevWorkspace V2 Management Module
# Enhanced DevWorkspace creation with predefined templates

# Create DevWorkspace V2 with template selection
create_devworkspace_v2() {
    log_component_start "workspacev2" "Creating DevWorkspace with template"
    
    # Prompt for username
    local USERNAME=$(promptUserInput "Enter username (user1): " "user1")
    
    # Display workspace type options
    log_substep "Available workspace templates:"
    echo "  1 => core-java"
    echo "  2 => springboot-web"
    echo "  3 => python-web"
    echo "  4 => springboot-backend"
    echo "  5 => tensorflow"
    echo "  6 => microservice-study"
    echo "  7 => javaparser"
    echo "  8 => nlp"
    echo "  9 => kubeauthentication"
    echo ""
    
    local WORKSPACE_TYPE_INDEX=$(promptUserInput "Enter workspace type index (1): " "1")
    local WORKSPACE_TYPE=""
    local WORKSPACE=""
    
    # Map index to workspace type
    case "$WORKSPACE_TYPE_INDEX" in
        1) WORKSPACE_TYPE="core-java"; WORKSPACE="java" ;;
        2) WORKSPACE_TYPE="springboot-web"; WORKSPACE="spring" ;;
        3) WORKSPACE_TYPE="python-web"; WORKSPACE="python" ;;
        4) WORKSPACE_TYPE="springboot-backend"; WORKSPACE="spring" ;;
        5) WORKSPACE_TYPE="tensorflow"; WORKSPACE="tensorflow" ;;
        6) WORKSPACE_TYPE="microservice-study"; WORKSPACE="microservice-study" ;;
        7) WORKSPACE_TYPE="javaparser"; WORKSPACE="javaparser" ;;
        8) WORKSPACE_TYPE="nlp"; WORKSPACE="nlp" ;;
        9) WORKSPACE_TYPE="kubeauthentication"; WORKSPACE="kubeauthentication" ;;
        *) WORKSPACE_TYPE="core-java"; WORKSPACE="java" ;;
    esac
    
    log_substep "Workspace configuration:"
    log_substep "  Username: ${COLOR_CYAN}${USERNAME}${COLOR_RESET}"
    log_substep "  Type: ${COLOR_CYAN}${WORKSPACE_TYPE}${COLOR_RESET}"
    log_substep "  Name: ${COLOR_CYAN}${WORKSPACE}${COLOR_RESET}"
    
    # Set environment variables for the Python script
    export CHE_USER_NAMESPACE="$USERNAME"
    export CHE_USER_NAME="$USERNAME"
    export CHE_WORKSPACE_NAME="$WORKSPACE"
    export WORKSPACE_TYPE="$WORKSPACE_TYPE"
    export DW_DELETE="false"
    
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
    log_substep "Creating DevWorkspace from template"
    local che_dir="$MOUNT_PATH/kubernetes/install_k8s/eclipseche"
    
    if [[ ! -d "$che_dir" ]]; then
        log_error "Eclipse Che directory not found: $che_dir"
        log_component_error "workspacev2" "Eclipse Che directory missing"
        return 1
    fi
    
    if execute_with_suppression pushd "$che_dir"; then
        if [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
            python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/create_devworkspace.py"
        else
            python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/create_devworkspace.py" 2>&1 | grep -E "ERROR|error|Error|Failed|failed" || true
        fi
        
        local result=$?
        execute_with_suppression popd
        
        if [[ $result -eq 0 ]]; then
            log_success "DevWorkspace created successfully"
            log_component_success "workspacev2" "DevWorkspace '$WORKSPACE' (type: $WORKSPACE_TYPE) created for user '$USERNAME'"
            return 0
        else
            log_error "DevWorkspace creation failed"
            log_component_error "workspacev2" "DevWorkspace creation failed"
            return 1
        fi
    else
        log_error "Failed to access Eclipse Che directory"
        return 1
    fi
}

# Delete DevWorkspace V2
delete_devworkspace_v2() {
    log_component_start "workspacev2" "Deleting DevWorkspace"
    
    # Prompt for username
    local USERNAME=$(promptUserInput "Enter username (user1): " "user1")
    
    # Display workspace type options
    log_substep "Available workspace templates:"
    echo "  1 => core-java"
    echo "  2 => springboot-web"
    echo "  3 => python-web"
    echo "  4 => springboot-backend"
    echo "  5 => tensorflow"
    echo "  6 => microservice-study"
    echo "  7 => javaparser"
    echo "  8 => nlp"
    echo "  9 => kubeauthentication"
    echo ""
    
    local WORKSPACE_TYPE_INDEX=$(promptUserInput "Enter workspace type index (1): " "1")
    local WORKSPACE_TYPE=""
    local WORKSPACE=""
    
    # Map index to workspace type
    case "$WORKSPACE_TYPE_INDEX" in
        1) WORKSPACE_TYPE="core-java"; WORKSPACE="java" ;;
        2) WORKSPACE_TYPE="springboot-web"; WORKSPACE="spring" ;;
        3) WORKSPACE_TYPE="python-web"; WORKSPACE="python" ;;
        4) WORKSPACE_TYPE="springboot-backend"; WORKSPACE="spring" ;;
        5) WORKSPACE_TYPE="tensorflow"; WORKSPACE="tensorflow" ;;
        6) WORKSPACE_TYPE="microservice-study"; WORKSPACE="microservice-study" ;;
        7) WORKSPACE_TYPE="javaparser"; WORKSPACE="javaparser" ;;
        8) WORKSPACE_TYPE="nlp"; WORKSPACE="nlp" ;;
        9) WORKSPACE_TYPE="kubeauthentication"; WORKSPACE="kubeauthentication" ;;
        *) WORKSPACE_TYPE="core-java"; WORKSPACE="java" ;;
    esac
    
    log_substep "Workspace configuration:"
    log_substep "  Username: ${COLOR_CYAN}${USERNAME}${COLOR_RESET}"
    log_substep "  Type: ${COLOR_CYAN}${WORKSPACE_TYPE}${COLOR_RESET}"
    log_substep "  Name: ${COLOR_CYAN}${WORKSPACE}${COLOR_RESET}"
    
    # Set environment variables for the Python script
    export CHE_USER_NAMESPACE="$USERNAME"
    export CHE_USER_NAME="$USERNAME"
    export CHE_WORKSPACE_NAME="$WORKSPACE"
    export WORKSPACE_TYPE="$WORKSPACE_TYPE"
    export DW_DELETE="true"
    
    # Execute DevWorkspace deletion
    log_substep "Deleting DevWorkspace"
    local che_dir="$MOUNT_PATH/kubernetes/install_k8s/eclipseche"
    
    if [[ ! -d "$che_dir" ]]; then
        log_error "Eclipse Che directory not found: $che_dir"
        log_component_error "workspacev2" "Eclipse Che directory missing"
        return 1
    fi
    
    if execute_with_suppression pushd "$che_dir"; then
        if [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
            python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/create_devworkspace.py"
        else
            python3 "$MOUNT_PATH/kubernetes/install_k8s/eclipseche/create_devworkspace.py" 2>&1 | grep -E "ERROR|error|Error|Failed|failed" || true
        fi
        
        local result=$?
        execute_with_suppression popd
        
        if [[ $result -eq 0 ]]; then
            log_success "DevWorkspace deleted successfully"
            log_component_success "workspacev2" "DevWorkspace '$WORKSPACE' deleted from user '$USERNAME' namespace"
            return 0
        else
            log_error "DevWorkspace deletion failed"
            log_component_error "workspacev2" "DevWorkspace deletion failed"
            return 1
        fi
    else
        log_error "Failed to access Eclipse Che directory"
        return 1
    fi
}

# Install workspacev2 (alias for create_devworkspace_v2)
install_workspacev2() {
    create_devworkspace_v2
}

# Export functions
export -f create_devworkspace_v2
export -f delete_devworkspace_v2
export -f install_workspacev2
