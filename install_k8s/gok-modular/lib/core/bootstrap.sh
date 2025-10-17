#!/bin/bash

# GOK Bootstrap Module - System initialization and module loading

# Initialize GOK environment variables and paths
init_gok_environment() {
    # Set base directories
    export GOK_ROOT_DIR="${GOK_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export GOK_ROOT="${GOK_ROOT:-$GOK_ROOT_DIR}"  # Alias for compatibility
    export GOK_LIB_DIR="${GOK_ROOT_DIR}/lib"
    export GOK_CONFIG_DIR="${GOK_ROOT_DIR}/config"
    export GOK_CACHE_DIR="${GOK_ROOT_DIR}/.cache"
    export GOK_LOGS_DIR="${GOK_ROOT_DIR}/logs"
    export GOK_LOG_DIR="${GOK_LOGS_DIR}"  # Alias for compatibility
    
    # Create necessary directories
    mkdir -p "$GOK_CACHE_DIR" "$GOK_LOGS_DIR"
    
    # Set default configuration
    export GOK_LOG_LEVEL="${GOK_LOG_LEVEL:-INFO}"
    export GOK_DEBUG="${GOK_DEBUG:-false}"
    export GOK_QUIET="${GOK_QUIET:-false}"
    
    # Tool paths
    export KUBECTL_PATH="${KUBECTL_PATH:-$(which kubectl 2>/dev/null || echo '/usr/local/bin/kubectl')}"
    export HELM_PATH="${HELM_PATH:-$(which helm 2>/dev/null || echo '/usr/local/bin/helm')}"
    export DOCKER_PATH="${DOCKER_PATH:-$(which docker 2>/dev/null || echo '/usr/bin/docker')}"
    
    return 0
}

# Load a single module with error handling
load_module() {
    local module_path="$1"
    local full_path="${GOK_ROOT_DIR}/${module_path}"
    
    if [[ -f "$full_path" ]]; then
        source "$full_path"
        return 0
    else
        echo "Error: Module not found: $full_path" >&2
        return 1
    fi
}

# Load core system modules
load_core_modules() {
    # First load colors utility to avoid readonly variable conflicts
    local colors_module_path="${GOK_LIB_DIR}/utils/colors.sh"
    if [[ -f "$colors_module_path" ]]; then
        source "$colors_module_path"
    fi
    
    local core_modules=(
        "constants"
        "config"
        "environment"
    )
    
    for module in "${core_modules[@]}"; do
        local module_path="${GOK_LIB_DIR}/core/${module}.sh"
        if [[ -f "$module_path" ]]; then
            source "$module_path"
        else
            echo "Warning: Core module $module not found at $module_path" >&2
        fi
    done
}

# Load utility modules
load_utility_modules() {
    local util_modules=(
        "logging"
        "verbosity"
        "helm"
        "kubectl"
        "tracking"
        "execution"
        "guidance"
        "repository_fix"
        "validation"
        "verification"
        "interactive"
        "system_update"
        "dependency_manager"
        "ha_validation"
        "summaries"
        "debug"
        "kubectl_helpers"
    )
    
    for module in "${util_modules[@]}"; do
        local module_path="${GOK_LIB_DIR}/utils/${module}.sh"
        if [[ -f "$module_path" ]]; then
            source "$module_path"
        else
            echo "Warning: Utility module $module not found at $module_path" >&2
        fi
    done
}

# Load validation modules (legacy - now integrated into utils)
load_validation_modules() {
    # Validation modules are now loaded as part of utility modules
    # This function is kept for backward compatibility
    if [[ "${GOK_DEBUG:-}" == "true" ]]; then
        echo "[DEBUG] Validation modules loaded via utility modules system" >&2
    fi
}

# Load command modules
load_command_modules() {
    local command_modules=(
        "install"
        "reset" 
        "start"
        "status"
        "utils"
        "create"
        "exec"
        "completion"
        "show"
        "summary"
        "debug"
    )
    
    for module in "${command_modules[@]}"; do
        local module_path="${GOK_LIB_DIR}/commands/${module}.sh"
        if [[ -f "$module_path" ]]; then
            source "$module_path"
        else
            echo "Warning: Command module $module not found at $module_path" >&2
        fi
    done
}

# Load component modules
load_component_modules() {
    local component_dirs=(
        "base"
        "platform"
        "infrastructure"
        "monitoring"
        "security"
        "development"
        "networking" 
        "storage"
        "ci-cd"
        "policy"
        "messaging"
        "registry"
    )
    
    for dir in "${component_dirs[@]}"; do
        local dir_path="${GOK_LIB_DIR}/components/${dir}"
        if [[ -d "$dir_path" ]]; then
            for component_file in "$dir_path"/*.sh; do
                if [[ -f "$component_file" ]]; then
                    if ! source "$component_file"; then
                        echo "Warning: Failed to source $component_file" >&2
                    fi
                fi
            done
        fi
    done
}

# Load modular support modules (reset, guidance, summaries)
load_support_modules() {
    local support_dirs=(
        "reset"
        "guidance"
        "summaries"
    )
    
    for dir in "${support_dirs[@]}"; do
        local dir_path="${GOK_LIB_DIR}/${dir}"
        if [[ -d "$dir_path" ]]; then
            for support_file in "$dir_path"/*.sh; do
                if [[ -f "$support_file" ]]; then
                    if ! source "$support_file"; then
                        echo "Warning: Failed to source $support_file" >&2
                    fi
                fi
            done
        fi
    done
}

# Load dispatcher module
load_dispatcher_module() {
    # Load modules first, then dispatcher
    load_utility_modules
    load_validation_modules
    load_command_modules
    load_component_modules
    load_support_modules
    
    local dispatcher_path="${GOK_LIB_DIR}/core/dispatcher.sh"
    
    if [[ -f "$dispatcher_path" ]]; then
        source "$dispatcher_path"
    else
        echo "ERROR: Dispatcher module not found at $dispatcher_path" >&2
        return 1
    fi
}

# Main bootstrap function
bootstrap_gok() {
    init_gok_environment || {
        echo "ERROR: Failed to initialize GOK environment" >&2
        return 1
    }
    
    load_core_modules || {
        echo "ERROR: Failed to load core modules" >&2
        return 1
    }
    
    # Initialize configuration system after core modules are loaded
    init_gok_configuration || {
        echo "ERROR: Failed to initialize GOK configuration" >&2
        return 1
    }
    
    load_dispatcher_module || {
        echo "ERROR: Failed to load dispatcher module" >&2
        return 1
    }
    
    # Initialize tracking system directories
    mkdir -p "${GOK_CACHE_DIR}"
    [[ ! -f "${GOK_CACHE_DIR}/component_status" ]] && touch "${GOK_CACHE_DIR}/component_status"
    
    # Initialize verbosity system
    init_verbosity || {
        echo "ERROR: Failed to initialize verbosity system" >&2
        return 1
    }
    
    # Use simple debug output to avoid logging conflicts
    if [[ "${GOK_DEBUG:-}" == "true" ]]; then
        echo "[DEBUG] GOK system initialized successfully" >&2
    fi
    return 0
}