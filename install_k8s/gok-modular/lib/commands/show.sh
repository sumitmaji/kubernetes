#!/bin/bash

# GOK Show Command Module - Display system information and configuration

# Main show command handler
showCmd() {
    local subcommand="$1"

    if [[ -z "$subcommand" || "$subcommand" == "help" || "$subcommand" == "--help" ]]; then
        show_show_help
        return 0
    fi

    case "$subcommand" in
        "configuration"|"config")
            show_configuration
            ;;
        *)
            log_error "Unknown show subcommand: $subcommand"
            echo
            show_show_help
            return 1
            ;;
    esac
}

# Display all environment variables
show_configuration() {
    log_header "System Configuration" "Environment Variables"

    echo "Current environment variables:"
    echo "=============================="
    env | sort
    echo
    echo "GOK-specific variables:"
    echo "======================="
    env | grep "^GOK_" | sort || echo "No GOK-specific variables found"
}

# Show help for show command
show_show_help() {
    echo "Usage: gok-new show <subcommand> [options]"
    echo
    echo "Display system information and configuration"
    echo
    echo "Subcommands:"
    echo "  configuration, config    Display all environment variables"
    echo
    echo "Examples:"
    echo "  gok-new show configuration    Show all environment variables"
    echo "  gok-new show config           Same as above"
    echo
    echo "Run 'gok-new help' for more information about other commands"
}