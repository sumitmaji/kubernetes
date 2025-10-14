#!/bin/bash

# GOK Dispatcher Module - Command routing and execution

# Main command dispatcher
dispatch_command() {
    local command="${1:-}"
    
    # Handle no arguments - show help
    if [[ -z "$command" ]]; then
        helpCmd
        return 0
    fi
    
    # Handle help flags
    case "$command" in
        "-h"|"--help"|"help")
            helpCmd "$@"
            return 0
            ;;
    esac
    
    # Shift to get remaining arguments
    shift
    
    # Check for verbose flag after command
    if [[ "$1" == "--verbose" || "$1" == "-v" ]]; then
        export GOK_VERBOSE=true
        shift
    fi
    
    # Handle command aliases and dispatch to appropriate handlers
    case "$command" in
        # Core commands
        "install")
            installCmd "$@"
            ;;
        "reset"|"uninstall")
            resetCmd "$@"
            ;;
        "start")
            startCmd "$@"
            ;;
        "deploy")
            deployCmd "$@"
            ;;
        "patch")
            patchCmd "$@"
            ;;
        "create")
            createCmd "$@"
            ;;
        "generate")
            generateCmd "$@"
            ;;
        "status")
            statusCmd "$@"
            ;;
        
        # Utility commands
        "desc"|"describe")
            descCmd "$@"
            ;;
        "logs")
            logsCmd "$@"
            ;;
        "bash"|"shell")
            bashCmd "$@"
            ;;
        "exec")
            execCmd "$@"
            ;;
        
        # Remote operations
        "remote")
            remoteCmd "$@"
            ;;
        
        # System operations
        "completion")
            completionCmd "$@"
            ;;
        "cache")
            cacheCmd "$@"
            ;;
        "show")
            showCmd "$@"
            ;;
        "summary")
            summaryCmd "$@"
            ;;
        "taint-node")
            taintNodeCmd "$@"
            ;;
        
        # Network utilities
        "checkDns")
            checkDns "$@"
            ;;
        "checkCurl")
            checkCurl "$@"
            ;;
        
        # Debug and troubleshooting
        "debug"|"troubleshoot")
            debugCmd "$@"
            ;;
        
        # Legacy commands for backward compatibility
        "fix")
            log_info "The 'fix' command has been integrated into component-specific operations"
            log_info "Try: gok-new install <component> or gok-new reset <component>"
            ;;
        
        # Help and documentation
        "help")
            helpCmd "$@"
            ;;
        
        *)
            # Check if the command is a valid function for backward compatibility
            if declare -f "$command" >/dev/null 2>&1; then
                log_warning "Direct function call detected. Consider using: gok <command> <component>"
                "$command" "$@"
            else
                log_error "Unknown command '$command'"
                echo
                echo "Available commands:"
                echo "  install, reset, start, deploy, patch, create, generate, status"
                echo "  desc, logs, bash, remote, completion, cache"
                echo ""
                echo "Run 'gok-new help' for detailed information"
                return 1
            fi
            ;;
    esac
}

# Validate command arguments
validate_command_args() {
    local command="$1"
    local required_args="$2"
    local actual_args="$3"
    
    if [[ $actual_args -lt $required_args ]]; then
        log_error "$command requires at least $required_args argument(s)"
        echo "Run 'gok $command --help' for usage information"
        return 1
    fi
    return 0
}

# Show command usage information
show_command_usage() {
    local command="$1"
    
    case "$command" in
        "install")
            echo "Usage: gok-new install <component> [options]"
            echo "Install and configure Kubernetes components"
            echo ""
            echo "Examples:"
            echo "  gok-new install kubernetes"
            echo "  gok-new install monitoring"
            echo "  gok-new install keycloak --verbose"
            ;;
        "reset")
            echo "Usage: gok-new reset <component>"
            echo "Reset and uninstall components"
            echo ""
            echo "Examples:"
            echo "  gok-new reset kubernetes"
            echo "  gok-new reset monitoring"
            ;;
        "create")
            echo "Usage: gok-new create <resource> <name> [options]"
            echo "Create Kubernetes resources"
            echo ""
            echo "Examples:"
            echo "  gok-new create secret myapp-secret"
            echo "  gok-new create certificate mydomain-cert"
            ;;
        *)
            echo "Usage: gok $command [options]"
            echo "Run 'gok-new help' for more information"
            ;;
    esac
}

# Check if command is available
is_command_available() {
    local command="$1"
    local available_commands=(
        "install" "reset" "start" "deploy" "patch" "create" "generate" "status"
        "desc" "logs" "bash" "remote" "completion" "cache" "show" "help"
    )
    
    for cmd in "${available_commands[@]}"; do
        if [[ "$cmd" == "$command" ]]; then
            return 0
        fi
    done
    return 1
}