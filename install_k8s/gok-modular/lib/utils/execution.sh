#!/bin/bash

# GOK Execution Module - Command execution with logging and suppression
# This module provides enhanced command execution with error handling and output management

# Global variables for execution control
export GOK_SUPPRESS_OUTPUT="${GOK_SUPPRESS_OUTPUT:-false}"
export GOK_SHOW_COMMANDS="${GOK_SHOW_COMMANDS:-true}"
export GOK_TEMP_DIR="${GOK_TEMP_DIR:-/tmp/gok}"

# Ensure temp directory exists
mkdir -p "$GOK_TEMP_DIR"

# Update command display based on verbosity level
update_command_display_setting() {
    # Import verbosity level if available
    if declare -f is_verbose >/dev/null 2>&1 && declare -f is_debug >/dev/null 2>&1; then
        if is_verbose || is_debug || [[ "${GOK_VERBOSE:-false}" == "true" ]] || [[ "${GOK_DEBUG:-false}" == "true" ]]; then
            export GOK_SHOW_COMMANDS="true"
        else
            export GOK_SHOW_COMMANDS="false"
        fi
    else
        # Fallback: check environment variables directly
        if [[ "${GOK_VERBOSE:-false}" == "true" ]] || [[ "${GOK_DEBUG:-false}" == "true" ]]; then
            export GOK_SHOW_COMMANDS="true"
        else
            export GOK_SHOW_COMMANDS="false"
        fi
    fi
}

# Call this to ensure settings are up to date
update_command_display_setting

# Execute a command with suppressed output and return status
execute_with_suppression() {
    local temp_file="$GOK_TEMP_DIR/stdout_$(date +%s%N)"
    local error_file="$GOK_TEMP_DIR/stderr_$(date +%s%N)"
    local stdin_file=""
    local command_display="$*"

    # Update command display setting based on current verbosity
    update_command_display_setting
    
    # Show command being executed if verbose mode
    if [[ "$GOK_SHOW_COMMANDS" == "true" ]]; then
        log_debug "Executing: $command_display"
    fi

    # Check if stdin has content (not connected to terminal)
    local has_stdin=false
    if [[ ! -t 0 ]]; then
        has_stdin=true
        stdin_file="$GOK_TEMP_DIR/stdin_$(date +%s%N)"
    fi

    # Execute command with both stdout and stderr captured
    local exit_code=0
    if [[ "$has_stdin" == "true" ]]; then
        # Capture stdin while also passing it to the command
        if tee "$stdin_file" | "$@" >"$temp_file" 2>"$error_file"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        # No stdin, execute normally
        if "$@" >"$temp_file" 2>"$error_file"; then
            exit_code=0
        else
            exit_code=$?
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        # Success - clean up and return
        rm -f "$temp_file" "$error_file" "$stdin_file" 2>/dev/null
        return 0
    else
        # Show formatted error information
        show_execution_error "$command_display" "$exit_code" "$temp_file" "$error_file" "$stdin_file"

        # Clean up temp files
        rm -f "$temp_file" "$error_file" "$stdin_file" 2>/dev/null
        return $exit_code
    fi
}

# Show detailed error information when command fails
show_execution_error() {
    local command="$1"
    local exit_code="$2"
    local stdout_file="$3"
    local stderr_file="$4"
    local stdin_file="$5"

    echo >&2
    log_error "Command execution failed"
    echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
    echo -e "${COLOR_RED}${COLOR_BOLD}│ 🚨 COMMAND EXECUTION FAILED - DEBUGGING INFORMATION            │${COLOR_RESET}" >&2
    echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}" >&2

    echo -e "${COLOR_YELLOW}${COLOR_BOLD}⚙️  Failed Command:${COLOR_RESET}" >&2
    echo -e "${COLOR_WHITE}  $command${COLOR_RESET}" >&2
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}❌ Exit Code: ${COLOR_RED}$exit_code${COLOR_RESET}" >&2

    # Show input content if available and looks like YAML/JSON
    if [[ -n "$stdin_file" && -s "$stdin_file" ]]; then
        local content_type=$(detect_content_type "$stdin_file")
        if [[ "$content_type" == "yaml" || "$content_type" == "json" ]]; then
            echo -e "${COLOR_CYAN}${COLOR_BOLD}📄 Input ${content_type^^} Content:${COLOR_RESET}" >&2
            echo -e "${COLOR_CYAN}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
            cat "$stdin_file" >&2
            echo -e "${COLOR_CYAN}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
        fi
    fi

    # Show error output if available
    if [[ -s "$stderr_file" ]]; then
        echo -e "${COLOR_RED}${COLOR_BOLD}🚨 Error Output:${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
        cat "$stderr_file" >&2
        echo -e "${COLOR_RED}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
    fi

    # Show standard output if available (may contain useful debugging info)
    if [[ -s "$stdout_file" ]]; then
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}ℹ️  Standard Output:${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
        cat "$stdout_file" >&2
        echo -e "${COLOR_YELLOW}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
    fi

    # Show recent system logs for additional context
    show_recent_system_logs "$command"

    # Show debugging tips
    show_debugging_tips "$command"
    echo >&2
}

# Show recent system logs for debugging failed commands
show_recent_system_logs() {
    local command="$1"
    
    # Show different amounts of logs based on verbosity
    local log_limit=10
    if [[ "${GOK_VERBOSE:-false}" != "true" && "${GOK_DEBUG:-false}" != "true" ]]; then
        log_limit=3  # Show fewer logs in non-verbose mode
    fi
    
    local header_text="📋 Recent System Logs (last ${log_limit} entries):"
    echo -e "${COLOR_MAGENTA}${COLOR_BOLD}${header_text}${COLOR_RESET}" >&2
    echo -e "${COLOR_MAGENTA}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
    
    # Try to show relevant system logs based on command type
    case "$command" in
        *kubectl*|*kubelet*)
            # Show kubelet logs
            if command -v journalctl >/dev/null 2>&1; then
                journalctl -u kubelet --no-pager -n $log_limit --since "5 minutes ago" 2>/dev/null | head -$log_limit >&2 || echo "No kubelet logs available" >&2
            else
                echo "journalctl not available for system logs" >&2
            fi
            ;;
        *docker*|*containerd*)
            # Show docker/containerd logs
            if command -v journalctl >/dev/null 2>&1; then
                (journalctl -u docker --no-pager -n $log_limit --since "5 minutes ago" 2>/dev/null || journalctl -u containerd --no-pager -n $log_limit --since "5 minutes ago" 2>/dev/null) | head -$log_limit >&2 || echo "No container runtime logs available" >&2
            else
                echo "journalctl not available for system logs" >&2
            fi
            ;;
        *systemctl*|*service*)
            # Show systemd logs
            if command -v journalctl >/dev/null 2>&1; then
                journalctl --no-pager -n $log_limit --since "5 minutes ago" 2>/dev/null | head -$log_limit >&2 || echo "No systemd logs available" >&2
            else
                echo "journalctl not available for system logs" >&2
            fi
            ;;
        *apt*|*dpkg*)
            # Show apt/dpkg logs
            if [[ -f "/var/log/apt/history.log" ]]; then
                echo "Recent apt operations:" >&2
                tail -5 /var/log/apt/history.log 2>/dev/null | grep -E "(Start-Date|Commandline|End-Date)" | head -$log_limit >&2 || echo "No apt logs available" >&2
            else
                echo "Apt logs not available at /var/log/apt/history.log" >&2
            fi
            ;;
        *)
            # Show general system logs
            if command -v journalctl >/dev/null 2>&1; then
                journalctl --no-pager -n $log_limit --since "2 minutes ago" --priority=err 2>/dev/null | head -$log_limit >&2 || echo "No recent error logs available" >&2
            else
                echo "System logs not available (journalctl not found)" >&2
            fi
            ;;
    esac
    
    echo -e "${COLOR_MAGENTA}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
}

# Show debugging tips based on command type
show_debugging_tips() {
    local command="$1"
    
    echo -e "${COLOR_CYAN}${COLOR_BOLD}💡 Debugging Tips:${COLOR_RESET}" >&2
    
    case "$command" in
        *kubectl*)
            echo -e "  ${COLOR_CYAN}• Check cluster: kubectl cluster-info${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Verify resources: kubectl get all -A${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Check events: kubectl get events --sort-by='.lastTimestamp'${COLOR_RESET}" >&2
            ;;
        *helm*)
            echo -e "  ${COLOR_CYAN}• Check helm status: helm list -A${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Verify values: helm get values <release>${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Check helm repo: helm repo list${COLOR_RESET}" >&2
            ;;
        *docker*)
            echo -e "  ${COLOR_CYAN}• Check docker: docker system info${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Verify service: systemctl status docker${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Check logs: journalctl -u docker${COLOR_RESET}" >&2
            ;;
        *)
            echo -e "  ${COLOR_CYAN}• Check system logs: journalctl -u kubelet${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Verify system resources: df -h && free -m${COLOR_RESET}" >&2
            echo -e "  ${COLOR_CYAN}• Check system status: systemctl status${COLOR_RESET}" >&2
            ;;
    esac
    
    echo -e "  ${COLOR_CYAN}• Run with debug: GOK_DEBUG=true gok-new <command>${COLOR_RESET}" >&2
}

# Detect if content is YAML or JSON
detect_content_type() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return
    fi

    # Read first few lines to detect format
    local first_lines=$(head -10 "$file" 2>/dev/null)

    # Check for YAML indicators
    if echo "$first_lines" | grep -qE "^apiVersion:\|^kind:\|^metadata:\|^spec:\|^status:"; then
        echo "yaml"
        return
    fi

    # Check for JSON indicators
    if echo "$first_lines" | grep -qE '^\s*{\s*"|^}\s*$|^\s*\[\s*|^]\s*$'; then
        echo "json"
        return
    fi

    # Check for YAML list items or mappings
    if echo "$first_lines" | grep -qE "^\s*-\s|^[a-zA-Z_][a-zA-Z0-9_]*:\s"; then
        echo "yaml"
        return
    fi

    echo "unknown"
}

# Execute helm install with log suppression and summary
helm_install_with_summary() {
    local component="$1"
    local namespace="${2:-default}"
    shift 2
    
    log_info "Installing $component via Helm..."
    local temp_file="$GOK_TEMP_DIR/helm_stdout_$(date +%s%N)"
    local error_file="$GOK_TEMP_DIR/helm_stderr_$(date +%s%N)"
    local start_time=$(date +%s)
    
    # Use spinner for helm install command
    if execute_with_spinner "Installing $component via Helm" helm install "$@" >"$temp_file" 2>"$error_file"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Extract useful information from output
        local release_info=$(grep -E "NAME:|NAMESPACE:|STATUS:|REVISION:" "$temp_file" 2>/dev/null || echo "")
        
        # Success message already shown by spinner, just show summary
        show_helm_summary "$component" "$namespace" "$duration" "$release_info"
        
        rm -f "$temp_file" "$error_file" 2>/dev/null
        return 0
    else
        local exit_code=$?
        show_execution_error "helm install $*" "$exit_code" "$temp_file" "$error_file"
        rm -f "$temp_file" "$error_file" 2>/dev/null
        return $exit_code
    fi
}

# Show helm installation summary
show_helm_summary() {
    local component="$1"
    local namespace="$2"
    local duration="$3"
    local release_info="$4"
    
    echo -e "${COLOR_CYAN}${COLOR_BOLD}📋 Installation Summary:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}• Component: ${COLOR_BOLD}$component${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}• Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}• Duration: ${COLOR_BOLD}${duration}s${COLOR_RESET}"
    
    if [[ -n "$release_info" ]]; then
        echo -e "  ${COLOR_GREEN}• Release Info:${COLOR_RESET}"
        echo "$release_info" | sed 's/^/    /'
    fi
}

# Execute kubectl apply with enhanced error reporting
kubectl_apply_with_summary() {
    local description="$1"
    shift
    
    log_info "Applying Kubernetes resources: $description"
    local temp_file="$GOK_TEMP_DIR/kubectl_stdout_$(date +%s%N)"
    local error_file="$GOK_TEMP_DIR/kubectl_stderr_$(date +%s%N)"
    
    if kubectl apply "$@" >"$temp_file" 2>"$error_file"; then
        # Show applied resources summary
        local resources_applied=$(grep -c "configured\|created\|unchanged" "$temp_file" 2>/dev/null || echo "0")
        log_success "Applied $resources_applied Kubernetes resources"
        
        # Show details if verbose
        if [[ "$GOK_VERBOSE" == "true" ]]; then
            cat "$temp_file"
        fi
        
        rm -f "$temp_file" "$error_file" 2>/dev/null
        return 0
    else
        local exit_code=$?
        show_execution_error "kubectl apply $*" "$exit_code" "$temp_file" "$error_file"
        rm -f "$temp_file" "$error_file" 2>/dev/null
        return $exit_code
    fi
}

# Execute command with retry mechanism
execute_with_retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2
    
    local attempt=1
    local exit_code=0
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: $*"
        
        if execute_with_suppression "$@"; then
            return 0
        else
            exit_code=$?
            if [[ $attempt -lt $max_attempts ]]; then
                log_warning "Attempt $attempt failed, retrying in ${delay}s..."
                sleep "$delay"
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "All $max_attempts attempts failed"
    return $exit_code
}

# Cleanup temporary files on exit
cleanup_execution_temp_files() {
    if [[ -d "$GOK_TEMP_DIR" ]]; then
        find "$GOK_TEMP_DIR" -name "stdout_*" -o -name "stderr_*" -o -name "helm_*" -o -name "kubectl_*" -mmin +60 -delete 2>/dev/null || true
    fi
}

# Register cleanup trap
trap cleanup_execution_temp_files EXIT

# Export functions for use by other modules
export -f execute_with_suppression
export -f helm_install_with_summary
export -f kubectl_apply_with_summary
export -f execute_with_retry