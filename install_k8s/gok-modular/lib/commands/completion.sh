#!/bin/bash

# GOK Completion Command - Install and manage bash completion
# This module handles tab completion for gok-new commands

# Main completion command function
completionCmd() {
    local action="${1:-}"
    
    case "$action" in
        install)
            install_gok_completion "${2:-bash}"
            ;;
        uninstall|remove)
            uninstall_gok_completion "${2:-bash}"
            ;;
        status|show)
            show_completion_status
            ;;
        generate)
            generate_completion_script "${2:-bash}"
            ;;
        --help|-h|help)
            show_completion_help
            ;;
        "")
            show_completion_help
            ;;
        *)
            log_error "Unknown completion action: $action"
            echo "Run 'gok-new completion --help' for available actions"
            return 1
            ;;
    esac
}

# Install GOK completion for the specified shell
install_gok_completion() {
    local shell="${1:-bash}"
    local completion_script="${GOK_ROOT}/gok-completion.bash"
    
    log_header "Installing GOK-NEW Completion for $shell"
    
    if [[ ! -f "$completion_script" ]]; then
        log_error "Completion script not found: $completion_script"
        return 1
    fi
    
    case "$shell" in
        bash)
            install_bash_completion
            ;;
        zsh)
            log_warning "ZSH completion not yet implemented"
            log_info "You can still use bash completion in zsh by sourcing: $completion_script"
            ;;
        fish)
            log_warning "Fish completion not yet implemented"
            ;;
        *)
            log_error "Unsupported shell: $shell"
            log_info "Supported shells: bash, zsh, fish"
            return 1
            ;;
    esac
}

# Install bash completion
install_bash_completion() {
    local completion_script="${GOK_ROOT}/gok-completion.bash"
    local user_bashrc="$HOME/.bashrc"
    local user_bash_profile="$HOME/.bash_profile"
    local completion_line="source \"$completion_script\""
    
    # Check if already installed in bashrc
    if grep -q "gok-completion.bash" "$user_bashrc" 2>/dev/null; then
        log_info "GOK completion already installed in $user_bashrc"
    else
        log_info "Adding completion to $user_bashrc..."
        echo "" >> "$user_bashrc"
        echo "# GOK-NEW Bash Completion" >> "$user_bashrc"
        echo "$completion_line" >> "$user_bashrc"
        log_success "Added completion to $user_bashrc"
    fi
    
    # Also try system-wide installation if user has permissions
    local system_completion_dir="/etc/bash_completion.d"
    if [[ -d "$system_completion_dir" ]] && [[ -w "$system_completion_dir" ]]; then
        log_info "Installing system-wide completion..."
        cp "$completion_script" "$system_completion_dir/gok-new"
        log_success "Installed system-wide completion"
    elif [[ -d "$system_completion_dir" ]]; then
        log_info "System-wide installation available (requires sudo):"
        echo "  sudo cp '$completion_script' '$system_completion_dir/gok-new'"
    fi
    
    # Source the completion immediately if possible
    if [[ -n "$BASH_VERSION" ]]; then
        log_info "Loading completion for current session..."
        source "$completion_script"
        log_success "Completion loaded for current session"
    fi
    
    echo ""
    log_success "Installation complete!"
    echo ""
    echo "📋 To use completion:"
    echo "  1. Restart your terminal or run: source ~/.bashrc"
    echo "  2. Try: gok-new <TAB><TAB>"
    echo "  3. Try: gok-new remote <TAB><TAB>"
    echo "  4. Try: gok-new install <TAB><TAB>"
}

# Uninstall GOK completion
uninstall_gok_completion() {
    local shell="${1:-bash}"
    
    log_header "Uninstalling GOK-NEW Completion for $shell"
    
    case "$shell" in
        bash)
            uninstall_bash_completion
            ;;
        *)
            log_error "Unsupported shell: $shell"
            return 1
            ;;
    esac
}

# Uninstall bash completion
uninstall_bash_completion() {
    local user_bashrc="$HOME/.bashrc"
    local system_completion="/etc/bash_completion.d/gok-new"
    
    # Remove from user bashrc
    if grep -q "gok-completion.bash" "$user_bashrc" 2>/dev/null; then
        log_info "Removing completion from $user_bashrc..."
        sed -i '/# GOK-NEW Bash Completion/,+1d' "$user_bashrc" 2>/dev/null || {
            # Fallback for systems without sed -i
            grep -v "gok-completion.bash" "$user_bashrc" > "${user_bashrc}.tmp" && mv "${user_bashrc}.tmp" "$user_bashrc"
        }
        log_success "Removed completion from $user_bashrc"
    fi
    
    # Remove system-wide installation
    if [[ -f "$system_completion" ]]; then
        if [[ -w "$system_completion" ]]; then
            rm -f "$system_completion"
            log_success "Removed system-wide completion"
        else
            log_info "System-wide removal available (requires sudo):"
            echo "  sudo rm -f '$system_completion'"
        fi
    fi
    
    log_success "Uninstallation complete!"
    echo "Please restart your terminal to apply changes."
}

# Show completion status
show_completion_status() {
    log_header "GOK-NEW Completion Status"
    
    local completion_script="${GOK_ROOT}/gok-completion.bash"
    local user_bashrc="$HOME/.bashrc"
    local system_completion="/etc/bash_completion.d/gok-new"
    
    # Check completion script exists
    if [[ -f "$completion_script" ]]; then
        log_success "Completion script found: $completion_script"
    else
        log_error "Completion script missing: $completion_script"
        return 1
    fi
    
    # Check user installation
    if grep -q "gok-completion.bash" "$user_bashrc" 2>/dev/null; then
        log_success "User completion installed in: $user_bashrc"
    else
        log_warning "User completion not installed in: $user_bashrc"
    fi
    
    # Check system installation
    if [[ -f "$system_completion" ]]; then
        log_success "System completion installed: $system_completion"
    else
        log_info "System completion not installed: $system_completion"
    fi
    
    # Check if completion is currently active
    if complete -p gok-new >/dev/null 2>&1; then
        log_success "Completion is active for current session"
        echo "  $(complete -p gok-new)"
    else
        log_warning "Completion not active for current session"
    fi
    
    echo ""
    log_info "To install completion: gok-new completion install"
    log_info "To test completion: gok-new <TAB><TAB>"
}

# Generate completion script for different shells  
generate_completion_script() {
    local shell="${1:-bash}"
    
    case "$shell" in
        bash)
            cat "${GOK_ROOT}/gok-completion.bash"
            ;;
        zsh)
            log_warning "ZSH completion generation not yet implemented"
            log_info "Use bash completion script for now"
            ;;
        fish)
            log_warning "Fish completion generation not yet implemented"
            ;;
        *)
            log_error "Unsupported shell: $shell"
            return 1
            ;;
    esac
}

# Show completion help
show_completion_help() {
    log_header "GOK-NEW Completion Management"
    
    echo "Manage tab completion for gok-new commands"
    echo ""
    echo "Usage:"
    echo "  gok-new completion <action> [shell]"
    echo ""
    echo "Actions:"
    echo "  install [shell]     Install completion for specified shell (default: bash)"
    echo "  uninstall [shell]   Uninstall completion for specified shell"
    echo "  status              Show completion installation status"
    echo "  generate [shell]    Generate completion script for shell"
    echo ""
    echo "Shells:"
    echo "  bash                Bash shell completion (fully supported)"
    echo "  zsh                 Z shell completion (planned)"
    echo "  fish                Fish shell completion (planned)"
    echo ""
    echo "Examples:"
    echo "  gok-new completion install          # Install bash completion"
    echo "  gok-new completion install bash     # Install bash completion"
    echo "  gok-new completion status           # Check installation status"
    echo "  gok-new completion uninstall        # Remove completion"
    echo ""
    echo "💡 Features:"
    echo ""
    echo "Multi-level completion:"
    echo "  gok-new <TAB><TAB>                  # Shows all commands"
    echo "  gok-new install <TAB><TAB>          # Shows all components"
    echo "  gok-new remote <TAB><TAB>           # Shows remote subcommands"
    echo "  gok-new remote setup <TAB><TAB>     # Shows setup options"
    echo ""
    echo "Smart completions:"
    echo "  • Component names for install/reset commands"
    echo "  • Remote host aliases for exec commands"
    echo "  • Kubernetes resource names (pods, services, etc.)"
    echo "  • File paths for copy operations"
    echo "  • Configuration options for each component"
}