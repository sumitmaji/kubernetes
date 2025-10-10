#!/bin/bash
# lib/utils/verbosity.sh
# Centralized verbosity and output control system for GOK modular design
#
# This module provides a unified way to control command output, system logs,
# and error handling across all GOK commands. It ensures clean output by default
# while providing detailed information when needed.
#
# Usage:
#   source_gok_module "verbosity"
#   execute_silent "apt-get update"
#   execute_with_output "docker build ."
#   execute_verbose_only "echo 'Debug info'"
# =============================================================================

# Ensure this module is loaded only once
if [[ "${GOK_VERBOSITY_LOADED:-}" == "true" ]]; then
    return 0
fi

# Load required dependencies
if [[ "${GOK_LOGGING_LOADED:-}" != "true" ]]; then
    # Try to source logging module from relative path
    local_logging_path="$(dirname "${BASH_SOURCE[0]}")/logging.sh"
    if [[ -f "$local_logging_path" ]]; then
        source "$local_logging_path"
    fi
fi

# =============================================================================
# VERBOSITY CONFIGURATION
# =============================================================================

# Verbosity levels
readonly VERBOSITY_SILENT=0      # No output except errors
readonly VERBOSITY_NORMAL=1      # Standard progress indicators 
readonly VERBOSITY_VERBOSE=2     # Detailed operation logs
readonly VERBOSITY_DEBUG=3       # Full debug information

# Current verbosity level
GOK_VERBOSITY_LEVEL=${GOK_VERBOSITY_LEVEL:-$VERBOSITY_NORMAL}

# Temporary files for output capture
GOK_TEMP_DIR="${GOK_TEMP_DIR:-/tmp/gok-$$}"
mkdir -p "$GOK_TEMP_DIR"

# =============================================================================
# VERBOSITY LEVEL MANAGEMENT
# =============================================================================

# Set verbosity level from environment or flags
init_verbosity() {
    # Check environment variables
    if [[ "${GOK_VERBOSE:-}" == "true" ]]; then
        GOK_VERBOSITY_LEVEL=$VERBOSITY_VERBOSE
    elif [[ "${GOK_DEBUG:-}" == "true" ]]; then
        GOK_VERBOSITY_LEVEL=$VERBOSITY_DEBUG
    elif [[ "${GOK_QUIET:-}" == "true" ]]; then
        GOK_VERBOSITY_LEVEL=$VERBOSITY_SILENT
    fi
    
    export GOK_VERBOSITY_LEVEL
}

# Set verbosity level programmatically
set_verbosity_level() {
    local level="$1"
    case "$level" in
        "silent"|"quiet"|0)
            GOK_VERBOSITY_LEVEL=$VERBOSITY_SILENT
            ;;
        "normal"|"standard"|1)
            GOK_VERBOSITY_LEVEL=$VERBOSITY_NORMAL
            ;;
        "verbose"|"detailed"|2)
            GOK_VERBOSITY_LEVEL=$VERBOSITY_VERBOSE
            export GOK_VERBOSE=true
            ;;
        "debug"|3)
            GOK_VERBOSITY_LEVEL=$VERBOSITY_DEBUG
            export GOK_DEBUG=true
            ;;
        *)
            log_error "Invalid verbosity level: $level"
            return 1
            ;;
    esac
    export GOK_VERBOSITY_LEVEL
}

# Check if current verbosity level meets minimum requirement
is_verbosity_level() {
    local required_level="$1"
    [[ $GOK_VERBOSITY_LEVEL -ge $required_level ]]
}

# Convenience functions
is_silent() { is_verbosity_level $VERBOSITY_SILENT; }
is_normal() { is_verbosity_level $VERBOSITY_NORMAL; }
is_verbose() { is_verbosity_level $VERBOSITY_VERBOSE; }
is_debug() { is_verbosity_level $VERBOSITY_DEBUG; }

# =============================================================================
# COMMAND EXECUTION WITH OUTPUT CONTROL
# =============================================================================

# Execute command silently unless error occurs or in verbose mode
execute_silent() {
    local description="$1"
    shift
    local command="$*"
    
    local stdout_file="$GOK_TEMP_DIR/stdout_$$_$(date +%s%N)"
    local stderr_file="$GOK_TEMP_DIR/stderr_$$_$(date +%s%N)"
    local exit_code=0
    
    # Show what we're doing if verbose
    if is_verbose; then
        log_debug "Executing: $command"
    fi
    
    # Execute command with output capture
    if eval "$command" >"$stdout_file" 2>"$stderr_file"; then
        exit_code=0
        
        # Show output only in verbose mode
        if is_verbose && [[ -s "$stdout_file" ]]; then
            log_substep "Command output:"
            cat "$stdout_file" | sed 's/^/  /'
        fi
    else
        exit_code=$?
        
        # Always show errors
        log_error "Command failed: $description"
        log_error "Command: $command"
        log_error "Exit code: $exit_code"
        
        if [[ -s "$stderr_file" ]]; then
            log_error "Error output:"
            cat "$stderr_file" | sed 's/^/  /' >&2
        fi
        
        if [[ -s "$stdout_file" ]]; then
            log_error "Standard output:"
            cat "$stdout_file" | sed 's/^/  /' >&2
        fi
    fi
    
    # Cleanup
    rm -f "$stdout_file" "$stderr_file" 2>/dev/null
    
    return $exit_code
}

# Execute command with controlled output based on verbosity
execute_controlled() {
    local description="$1"
    shift
    local command="$*"
    
    if is_verbose; then
        # In verbose mode, show everything including the command being executed
        log_info "$description"
        log_debug "Executing: $command"
        eval "$command"
        local exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            log_error "Command failed with exit code: $exit_code"
        fi
        
        return $exit_code
    else
        # In normal mode, suppress output unless error
        execute_silent "$description" "$command"
    fi
}

# Execute command only in verbose mode
execute_verbose_only() {
    if is_verbose; then
        eval "$@"
    fi
}

# Execute command only in debug mode
execute_debug_only() {
    if is_debug; then
        log_debug "Debug execution: $*"
        eval "$@"
    fi
}

# Execute with progress indicator in normal mode, full output in verbose
execute_with_progress() {
    local description="$1"
    local progress_message="$2"
    shift 2
    local command="$*"
    
    if is_verbose; then
        log_info "$description"
        log_debug "Executing: $command"
        eval "$command"
    else
        # Show progress indicator, but still capture output for error display
        log_info "$progress_message"
        
        local stdout_file="$GOK_TEMP_DIR/stdout_$$_$(date +%s%N)"
        local stderr_file="$GOK_TEMP_DIR/stderr_$$_$(date +%s%N)"
        local exit_code=0
        
        # Execute command with output capture
        if eval "$command" >"$stdout_file" 2>"$stderr_file"; then
            exit_code=0
        else
            exit_code=$?
            
            # Show error details even in non-verbose mode
            log_error "Command failed: $description"
            log_error "Command: $command"
            log_error "Exit code: $exit_code"
            
            if [[ -s "$stderr_file" ]]; then
                log_error "Error output:"
                cat "$stderr_file" | sed 's/^/  /' >&2
            fi
            
            if [[ -s "$stdout_file" ]]; then
                log_error "Standard output:"
                cat "$stdout_file" | sed 's/^/  /' >&2
            fi
        fi
        
        # Cleanup
        rm -f "$stdout_file" "$stderr_file" 2>/dev/null
        
        return $exit_code
    fi
}

# =============================================================================
# SYSTEM COMMAND WRAPPERS
# =============================================================================

# APT operations with verbosity control
apt_update_controlled() {
    local description="Updating package repositories"
    
    if is_verbose; then
        log_info "$description"
        apt-get update
    else
        log_info "Updating package repositories..."
        execute_silent "$description" "apt-get update"
    fi
}

apt_install_controlled() {
    local packages="$*"
    local description="Installing packages: $packages"
    
    if is_verbose; then
        log_info "$description"
        apt-get install -y $packages
    else
        log_info "Installing packages: $packages"
        execute_silent "$description" "apt-get install -y $packages"
    fi
}

# Docker operations with verbosity control
docker_pull_controlled() {
    local image="$1"
    local description="Pulling Docker image: $image"
    
    if is_verbose; then
        log_info "$description"
        docker pull "$image"
    else
        log_info "Pulling Docker image: $image"
        # Show spinner for long operations
        show_spinner_background "docker pull \"$image\"" "Downloading $image"
    fi
}

docker_run_controlled() {
    local description="$1"
    shift
    local docker_cmd="docker run $*"
    
    if is_verbose; then
        log_info "$description"
        log_debug "Executing: $docker_cmd"
        eval "$docker_cmd"
    else
        execute_silent "$description" "$docker_cmd"
    fi
}

# Kubernetes operations with verbosity control
kubectl_apply_controlled() {
    local description="$1"
    shift
    local kubectl_cmd="kubectl apply $*"
    
    if is_verbose; then
        log_info "$description"
        log_debug "Executing: $kubectl_cmd"
        eval "$kubectl_cmd"
    else
        log_info "$description"
        execute_silent "Applying Kubernetes resources" "$kubectl_cmd"
    fi
}

# Systemctl operations with verbosity control
systemctl_controlled() {
    local action="$1"
    local service="$2"
    local description="$3"
    
    local systemctl_cmd="systemctl $action $service"
    
    if is_verbose; then
        log_info "$description"
        log_debug "Executing: $systemctl_cmd"
        eval "$systemctl_cmd"
    else
        execute_silent "$description" "$systemctl_cmd"
    fi
}

# =============================================================================
# LOGGING INTEGRATION
# =============================================================================

# Enhanced logging functions that respect verbosity
log_verbose() {
    if is_verbose; then
        log_info "$1"
    fi
}

log_debug_verbose() {
    if is_debug; then
        log_debug "$1"
    fi
}

# Progress logging that adapts to verbosity
log_progress_controlled() {
    local message="$1"
    local current="$2"
    local total="$3"
    
    if is_verbose; then
        log_step "$message ($current/$total)"
    elif is_normal; then
        log_progress "$current" "$total" "$message"
    fi
}

# =============================================================================
# CLEANUP AND ERROR HANDLING
# =============================================================================

# Cleanup function for temporary files
cleanup_verbosity_temp() {
    if [[ -d "$GOK_TEMP_DIR" ]]; then
        rm -rf "$GOK_TEMP_DIR"/stdout_* "$GOK_TEMP_DIR"/stderr_* 2>/dev/null || true
    fi
}

# Error handler that shows appropriate level of detail
handle_command_error() {
    local command="$1"
    local exit_code="$2"
    local error_message="${3:-Command execution failed}"
    
    log_error "$error_message"
    log_error "Failed command: $command"
    log_error "Exit code: $exit_code"
    
    if is_verbose; then
        log_error "This error occurred in verbose mode - all output was shown above"
    else
        log_error "Run with --verbose flag to see detailed error information"
    fi
}

# =============================================================================
# SPINNER AND PROGRESS UTILITIES
# =============================================================================

# Background spinner for long-running operations
show_spinner_background() {
    local command="$1"
    local message="${2:-Working}"
    
    if is_verbose; then
        # In verbose mode, just execute normally
        eval "$command"
        return $?
    fi
    
    # In normal mode, show spinner
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local temp_file="$GOK_TEMP_DIR/spinner_$$_$(date +%s%N)"
    
    # Start background process
    eval "$command" >"$temp_file" 2>&1 &
    local bg_pid=$!
    
    # Show spinner
    local i=0
    while kill -0 "$bg_pid" 2>/dev/null; do
        local char="${spinner_chars:i++%${#spinner_chars}:1}"
        printf "\r%s %s" "$char" "$message"
        sleep 0.1
    done
    
    # Get exit code
    wait "$bg_pid"
    local exit_code=$?
    
    # Clear spinner line
    printf "\r%*s\r" $((${#message} + 2)) ""
    
    # Show result
    if [[ $exit_code -eq 0 ]]; then
        log_success "$message - completed"
    else
        log_error "$message - failed"
        # Show error output
        if [[ -s "$temp_file" ]]; then
            log_error "Error details:"
            cat "$temp_file" | sed 's/^/  /' >&2
        fi
    fi
    
    rm -f "$temp_file" 2>/dev/null
    return $exit_code
}

# =============================================================================
# CONFIGURATION AND HELP
# =============================================================================

# Show current verbosity configuration
show_verbosity_config() {
    echo -e "\n${COLOR_HEADER:-}GOK Verbosity Configuration${COLOR_RESET:-}"
    echo -e "${COLOR_DIM:-}═══════════════════════════════════════════${COLOR_RESET:-}"
    
    local level_name
    case "$GOK_VERBOSITY_LEVEL" in
        0) level_name="Silent" ;;
        1) level_name="Normal" ;;
        2) level_name="Verbose" ;;
        3) level_name="Debug" ;;
        *) level_name="Unknown" ;;
    esac
    
    echo -e "Current Level: ${COLOR_INFO:-}$level_name ($GOK_VERBOSITY_LEVEL)${COLOR_RESET:-}"
    echo -e "GOK_VERBOSE: ${COLOR_DIM:-}${GOK_VERBOSE:-false}${COLOR_RESET:-}"
    echo -e "GOK_DEBUG: ${COLOR_DIM:-}${GOK_DEBUG:-false}${COLOR_RESET:-}"
    echo -e "GOK_QUIET: ${COLOR_DIM:-}${GOK_QUIET:-false}${COLOR_RESET:-}"
    echo
    
    echo -e "Available Levels:"
    echo -e "  ${COLOR_DIM:-}0${COLOR_RESET:-} Silent  - Only errors shown"
    echo -e "  ${COLOR_INFO:-}1${COLOR_RESET:-} Normal  - Progress indicators and results"
    echo -e "  ${COLOR_SUCCESS:-}2${COLOR_RESET:-} Verbose - Detailed operation logs"
    echo -e "  ${COLOR_DEBUG:-}3${COLOR_RESET:-} Debug   - Full debug information"
    echo
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize verbosity on module load
init_verbosity

# Set up cleanup trap
trap cleanup_verbosity_temp EXIT

# Export key functions
export -f execute_silent execute_controlled execute_verbose_only execute_debug_only
export -f execute_with_progress apt_update_controlled apt_install_controlled
export -f docker_pull_controlled docker_run_controlled kubectl_apply_controlled
export -f systemctl_controlled log_verbose log_debug_verbose log_progress_controlled
export -f show_spinner_background set_verbosity_level is_verbose is_debug
export -f handle_command_error show_verbosity_config

# Mark module as loaded
export GOK_VERBOSITY_LOADED="true"

# Debug initialization
if is_debug; then
    log_debug "Verbosity module loaded - level: $GOK_VERBOSITY_LEVEL"
fi