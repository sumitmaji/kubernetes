#!/bin/bash
# lib/utils/logging.sh
# Logging utilities for GOK modular system
#
# This module provides comprehensive logging functionality with different
# log levels, formatting, and output destinations for the GOK system.
#
# Usage:
#   source_gok_module "logging"
#   log_info "Starting process"
#   log_success "Operation completed"
#   log_error "Something went wrong"
# =============================================================================

# Ensure this module is loaded only once
# Temporarily disabled guard to fix bootstrap issues in gok-new script
# if [[ "${GOK_LOGGING_LOADED:-}" == "true" ]]; then
#     return 0
# fi

# Load colors module if not already loaded
if [[ "${GOK_COLORS_LOADED:-}" != "true" ]]; then
    # Try to source colors module from relative path
    local_colors_path="$(dirname "${BASH_SOURCE[0]}")/colors.sh"
    if [[ -f "$local_colors_path" ]]; then
        source "$local_colors_path"
    fi
fi

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================

# Default logging configuration
: ${GOK_LOG_LEVEL:=INFO}
: ${GOK_LOG_FILE:=""}
: ${GOK_LOG_TIMESTAMP:=false}
: ${GOK_LOG_CALLER:=false}
: ${GOK_LOG_NO_COLORS:=false}
: ${GOK_LOG_QUIET:=false}

# Log level constants
if [[ -z "${LOG_LEVEL_DEBUG:-}" ]]; then readonly LOG_LEVEL_DEBUG=0; fi
if [[ -z "${LOG_LEVEL_INFO:-}" ]]; then readonly LOG_LEVEL_INFO=1; fi
if [[ -z "${LOG_LEVEL_SUCCESS:-}" ]]; then readonly LOG_LEVEL_SUCCESS=2; fi
if [[ -z "${LOG_LEVEL_WARNING:-}" ]]; then readonly LOG_LEVEL_WARNING=3; fi
if [[ -z "${LOG_LEVEL_ERROR:-}" ]]; then readonly LOG_LEVEL_ERROR=4; fi
if [[ -z "${LOG_LEVEL_CRITICAL:-}" ]]; then readonly LOG_LEVEL_CRITICAL=5; fi

# Current log level (converted from string)
GOK_LOG_LEVEL_NUM=1

# =============================================================================
# LOGGING LEVEL MANAGEMENT
# =============================================================================

# Convert log level string to number
get_log_level_num() {
    local level="${1^^}"  # Convert to uppercase
    
    case "$level" in
        "DEBUG"|"DBG") echo $LOG_LEVEL_DEBUG ;;
        "INFO"|"INF") echo $LOG_LEVEL_INFO ;;
        "SUCCESS"|"SUC"|"OK") echo $LOG_LEVEL_SUCCESS ;;
        "WARNING"|"WARN"|"WRN") echo $LOG_LEVEL_WARNING ;;
        "ERROR"|"ERR") echo $LOG_LEVEL_ERROR ;;
        "CRITICAL"|"CRIT"|"FATAL") echo $LOG_LEVEL_CRITICAL ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# Set logging level
set_log_level() {
    local level="$1"
    export GOK_LOG_LEVEL="$level"
    if declare -f get_log_level_num >/dev/null 2>&1; then
        export GOK_LOG_LEVEL_NUM=$(get_log_level_num "$level")
    else
        # Fallback to default if function not available yet
        export GOK_LOG_LEVEL_NUM=2
    fi
}

# Initialize log level
init_log_level() {
    if declare -f get_log_level_num >/dev/null 2>&1; then
        export GOK_LOG_LEVEL_NUM=$(get_log_level_num "${GOK_LOG_LEVEL}")
    else
        # Fallback to default if function not available yet
        export GOK_LOG_LEVEL_NUM=2
    fi
}

# =============================================================================
# CORE LOGGING FUNCTIONS
# =============================================================================

# Internal logging function
_log() {
    local level="$1"
    local level_num="$2"
    local color="$3"
    local symbol="$4"
    local message="$5"

    # Defensive: Ensure level_num is a number
    if ! [[ "$level_num" =~ ^[0-9]+$ ]]; then
        echo "[LOGGING ERROR] Invalid log level_num: '$level_num' (should be a number). Args: level='$level', color='$color', symbol='$symbol', message='$message'" >&2
        return 1
    fi

    # Check if we should log this level
    if [[ $level_num -lt $GOK_LOG_LEVEL_NUM ]]; then
        return 0
    fi

    # Skip if in quiet mode (unless it's an error)
    if [[ "$GOK_LOG_QUIET" == "true" ]] && [[ $level_num -lt $LOG_LEVEL_ERROR ]]; then
        return 0
    fi

    # Format timestamp if enabled
    local timestamp=""
    if [[ "$GOK_LOG_TIMESTAMP" == "true" ]]; then
        timestamp="$(date '+%Y-%m-%d %H:%M:%S') "
    fi

    # Format caller information if enabled
    local caller_info=""
    if [[ "$GOK_LOG_CALLER" == "true" ]]; then
        # Get calling function and line (skip this function and the wrapper)
        local caller_line="${BASH_LINENO[2]:-}"
        local caller_func="${FUNCNAME[2]:-main}"
        local caller_file="$(basename "${BASH_SOURCE[2]:-}")"
        caller_info="[${caller_file}:${caller_func}:${caller_line}] "
    fi

    # Determine output stream
    local output_stream=1  # stdout
    if [[ $level_num -ge $LOG_LEVEL_ERROR ]]; then
        output_stream=2  # stderr for errors
    fi

    # Format the log message
    local formatted_message
    if [[ "$GOK_LOG_NO_COLORS" == "true" ]] || [[ "${GOK_COLORS_ENABLED:-}" != "true" ]]; then
        # No colors
        formatted_message="${timestamp}${caller_info}[${level}] ${symbol} ${message}"
    else
        # With colors
        formatted_message="${COLOR_DIM}${timestamp}${COLOR_RESET}${COLOR_DIM}${caller_info}${COLOR_RESET}${color}[${level}]${COLOR_RESET} ${color}${symbol}${COLOR_RESET} ${message}"
    fi

    # Output the message
    echo -e "$formatted_message" >&$output_stream

    # Write to log file if configured
    if [[ -n "$GOK_LOG_FILE" ]] && [[ -w "$(dirname "$GOK_LOG_FILE")" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') ${caller_info}[${level}] ${message}" >> "$GOK_LOG_FILE"
    fi
}

# =============================================================================
# PUBLIC LOGGING FUNCTIONS
# =============================================================================

# Debug logging
log_debug() {
    local message="$1"
    _log "DEBUG" $LOG_LEVEL_DEBUG "${COLOR_DEBUG:-}" "🔍" "$message"
}

# Info logging
log_info() {
    local message="$1"
    _log "INFO" $LOG_LEVEL_INFO "${COLOR_INFO:-}" "ℹ" "$message"
}

# Success logging
log_success() {
    local message="$1"
    _log "SUCCESS" $LOG_LEVEL_SUCCESS "${COLOR_SUCCESS:-}" "✅" "$message"
}

# Warning logging
log_warning() {
    local message="$1"
    _log "WARNING" $LOG_LEVEL_WARNING "${COLOR_WARNING:-}" "⚠️" "$message"
}

# Error logging
log_error() {
    local message="$1"
    _log "ERROR" $LOG_LEVEL_ERROR "${COLOR_ERROR:-}" "❌" "$message"
}

# Critical error logging
log_critical() {
    local message="$1"
    _log "CRITICAL" $LOG_LEVEL_CRITICAL "${COLOR_ERROR:-}" "💀" "$message"
}

# =============================================================================
# SPECIALIZED LOGGING FUNCTIONS
# =============================================================================

# Log step (major operation)
log_step() {
    # Check number of arguments
    if [[ $# -eq 1 ]]; then
        # Single argument: treat as message only
        local message="$1"
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -e "\n${COLOR_STEP}${COLOR_BOLD}🚀 ${message}${COLOR_RESET}"
        else
            echo -e "\n[STEP] 🚀 ${message}"
        fi
    elif [[ $# -eq 2 ]]; then
        # Two arguments: step number + message
        local step="$1"
        local message="$2"
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -e "\n${COLOR_STEP}${COLOR_BOLD}Step $step: 🚀 ${message}${COLOR_RESET}"
        else
            echo -e "\n[STEP $step] 🚀 ${message}"
        fi
    else
        # Invalid number of arguments
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -e "${COLOR_ERROR}${EMOJI_ERROR} log_step: Invalid number of arguments. Use: log_step <message> or log_step <step> <message>${COLOR_RESET}" >&2
        else
            echo -e "[ERROR] log_step: Invalid number of arguments. Use: log_step <message> or log_step <step> <message>" >&2
        fi
        return 1
    fi
}

# Log substep (minor operation)
log_substep() {
    local message="$1"
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "  ${COLOR_SUBSTEP}→ ${message}${COLOR_RESET}"
    else
        echo -e "  → ${message}"
    fi
}

# Log progress
log_progress() {
    local message="$1"
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "  ${COLOR_PROGRESS}⚡ ${message}${COLOR_RESET}"
    else
        echo -e "  ⚡ ${message}"
    fi
}

# Log command execution
log_command() {
    local command="$1"
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "  ${COLOR_COMMAND}$ ${command}${COLOR_RESET}"
    else
        echo -e "  $ ${command}"
    fi
}

# Log file operations
log_file() {
    local operation="$1"
    local filepath="$2"
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "  ${COLOR_FILE}📄 ${operation}: ${COLOR_PATH}${filepath}${COLOR_RESET}"
    else
        echo -e "  📄 ${operation}: ${filepath}"
    fi
}

# =============================================================================
# LOGGING HELPERS AND UTILITIES
# =============================================================================

# Log separator
log_separator() {
    local char="${1:-=}"
    local length="${2:-60}"
    local separator=$(printf "%*s" "$length" "" | tr ' ' "$char")
    
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "${COLOR_DIM}${separator}${COLOR_RESET}"
    else
        echo "$separator"
    fi
}

# Log header with separator
log_header() {
    local title="$1"
    local char="${2:-=}"
    
    echo
    log_separator "$char"
    if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
        echo -e "${COLOR_HEADER}${COLOR_BOLD}${title}${COLOR_RESET}"
    else
        echo "$title"
    fi
    log_separator "$char"
    echo
}

# Get elapsed time since start
get_elapsed_time() {
    local start_time=${1:-$GOK_START_TIME}
    if [[ -n "$start_time" ]]; then
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        if [[ $minutes -gt 0 ]]; then
            echo "${minutes}m ${seconds}s"
        else
            echo "${seconds}s"
        fi
    else
        echo "0s"
    fi
}

# Initialize timing
GOK_START_TIME=${GOK_START_TIME:-$(date +%s)}

# Component logging functions
log_component_start() {
    local component="$1"
    local description="${2:-Installing component}"
    # Sanitize component name for variable names (replace hyphens with underscores)
    local var_name=$(echo "${component^^}" | tr '-' '_')
    echo
    echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}│ ${EMOJI_PACKAGE} Starting: $component${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}│ $description${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
    export "GOK_${var_name}_START_TIME=$(date +%s)"
}

log_component_success() {
    local component="$1"
    local message="${2:-Installation completed successfully}"
    # Sanitize component name for variable names (replace hyphens with underscores)
    local var_name=$(echo "${component^^}" | tr '-' '_')
    local start_var="GOK_${var_name}_START_TIME"
    local elapsed=$(get_elapsed_time "${!start_var}")
    echo
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}│ ${EMOJI_SUCCESS} Success: $component${COLOR_RESET}"
    echo -e "${COLOR_GREEN}│ $message${COLOR_RESET}"
    echo -e "${COLOR_GREEN}│ ${EMOJI_CLOCK} Installation time: $elapsed${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
}

log_component_error() {
    local component="$1"
    local message="${2:-Installation failed}"
    # Sanitize component name for variable names (replace hyphens with underscores)
    local var_name=$(echo "${component^^}" | tr '-' '_')
    local start_var="GOK_${var_name}_START_TIME"
    local elapsed=$(get_elapsed_time "${!start_var}")
    echo
    echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_RED}${COLOR_BOLD}│ ${EMOJI_ERROR} Failed: $component${COLOR_RESET}"
    echo -e "${COLOR_RED}│ $message${COLOR_RESET}"
    echo -e "${COLOR_RED}│ ${EMOJI_CLOCK} Time elapsed: $elapsed${COLOR_RESET}"
    echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
}

log_next_steps() {
    local title="$1"
    shift
    local steps=("$@")
    
    echo
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}│ ${EMOJI_LIGHTBULB} Next Steps: $title${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
    
    local step_num=1
    for step in "${steps[@]}"; do
        echo -e "${COLOR_YELLOW}${step_num}. $step${COLOR_RESET}"
        ((step_num++))
    done
    echo
}

log_urls() {
    local title="$1"
    shift
    local urls=("$@")
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}${EMOJI_LINK} $title:${COLOR_RESET}"
    for url in "${urls[@]}"; do
        echo -e "  ${COLOR_CYAN}• $url${COLOR_RESET}"
    done
    echo
}

log_credentials() {
    local service="$1"
    local username="$2"
    local password_info="$3"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}${EMOJI_KEY} $service Credentials:${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}Username: ${COLOR_BOLD}$username${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}Password: $password_info${COLOR_RESET}"
    echo
}

# Check if verbose mode is enabled
is_verbose_mode() {
    [[ "${GOK_VERBOSE:-false}" == "true" ]]
}

# Log array of items
log_list() {
    local title="$1"
    shift
    local items=("$@")
    
    log_info "$title"
    for item in "${items[@]}"; do
        log_substep "$item"
    done
}

# =============================================================================
# PROGRESS AND STATUS TRACKING
# =============================================================================

# Track operation with automatic success/failure logging
track_operation() {
    local operation_name="$1"
    shift
    local command=("$@")
    
    log_substep "Starting: $operation_name"
    
    if "${command[@]}"; then
        log_success "Completed: $operation_name"
        return 0
    else
        log_error "Failed: $operation_name"
        return 1
    fi
}

# Log operation with timing
timed_operation() {
    local operation_name="$1"
    shift
    local command=("$@")
    
    local start_time=$(date +%s)
    log_substep "Starting: $operation_name"
    
    if "${command[@]}"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Completed: $operation_name (${duration}s)"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "Failed: $operation_name (${duration}s)"
        return 1
    fi
}

# Execute command with spinner
execute_with_spinner() {
    local message="$1"
    shift
    local command=("$@")
    
    # Check if the command exists
    if ! command -v "${command[0]}" >/dev/null 2>&1; then
        log_error "$message - ${command[0]} command not found"
        return 127
    fi
    
    # Skip spinner in quiet mode or if not in normal verbosity
    if [[ "$GOK_LOG_QUIET" == "true" ]] || ! is_normal; then
        log_substep "$message"
        "${command[@]}"
        return $?
    fi
    
    # Spinner characters
    local spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spinner_index=0
    local pid=""
    
    # Start the command in background
    "${command[@]}" &
    pid=$!
    
    # Show spinner while command is running
    while kill -0 $pid 2>/dev/null; do
        local spinner_char="${spinner_chars[$spinner_index]}"
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -ne "\r${COLOR_PROGRESS}${spinner_char}${COLOR_RESET} ${message}..."
        else
            echo -ne "\r${spinner_char} ${message}..."
        fi
        
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars[@]} ))
        sleep 0.1
    done
    
    # Show spinner while command is running
    while kill -0 $pid 2>/dev/null; do
        local spinner_char="${spinner_chars[$spinner_index]}"
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -ne "\r${COLOR_PROGRESS}${spinner_char}${COLOR_RESET} ${message}..."
        else
            echo -ne "\r${spinner_char} ${message}..."
        fi
        
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars[@]} ))
        sleep 0.1
    done
    
    # Clear the spinner line
    echo -ne "\r"
    printf "%-${#message}s\n" ""
    echo -ne "\r"
    
    # Wait for the command and get exit code
    wait $pid
    local exit_code=$?
    
    # Show result
    if [[ $exit_code -eq 0 ]]; then
        log_success "$message"
    else
        log_error "$message"
    fi
    
    return $exit_code
}

# Execute command with spinner and custom success/failure messages
execute_with_spinner_custom() {
    local message="$1"
    local success_msg="$2"
    local failure_msg="$3"
    shift 3
    local command=("$@")
    
    # Check if the command exists
    if ! command -v "${command[0]}" >/dev/null 2>&1; then
        if [[ -n "$failure_msg" ]]; then
            log_error "$failure_msg - ${command[0]} command not found"
        else
            log_error "$message - ${command[0]} command not found"
        fi
        return 127
    fi
    
    # Skip spinner in quiet mode or if not in normal verbosity
    if [[ "$GOK_LOG_QUIET" == "true" ]] || ! is_normal; then
        log_substep "$message"
        if "${command[@]}"; then
            [[ -n "$success_msg" ]] && log_success "$success_msg"
            return 0
        else
            [[ -n "$failure_msg" ]] && log_error "$failure_msg"
            return 1
        fi
    fi
    
    # Spinner characters
    local spinner_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spinner_index=0
    local pid=""
    
    # Start the command in background
    "${command[@]}" &
    pid=$!
    
    # Show spinner while command is running
    while kill -0 $pid 2>/dev/null; do
        local spinner_char="${spinner_chars[$spinner_index]}"
        if [[ "$GOK_LOG_NO_COLORS" != "true" ]] && [[ "${GOK_COLORS_ENABLED:-}" == "true" ]]; then
            echo -ne "\r${COLOR_PROGRESS}${spinner_char}${COLOR_RESET} ${message}..."
        else
            echo -ne "\r${spinner_char} ${message}..."
        fi
        
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars[@]} ))
        sleep 0.1
    done
    
    # Clear the spinner line
    echo -ne "\r"
    printf "%-${#message}s\n" ""
    echo -ne "\r"
    
    # Wait for the command and get exit code
    wait $pid
    local exit_code=$?
    
    # Show result
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$success_msg" ]]; then
            log_success "$success_msg"
        else
            log_success "$message"
        fi
    else
        if [[ -n "$failure_msg" ]]; then
            log_error "$failure_msg"
        else
            log_error "$message"
        fi
    fi
    
    return $exit_code
}

# =============================================================================
# LOG FILE MANAGEMENT
# =============================================================================

# Set log file
set_log_file() {
    local log_file="$1"
    local create_dir="${2:-true}"
    
    # Create directory if it doesn't exist
    if [[ "$create_dir" == "true" ]]; then
        local log_dir=$(dirname "$log_file")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir" 2>/dev/null || {
                log_warning "Cannot create log directory: $log_dir"
                return 1
            }
        fi
    fi
    
    # Check if we can write to the log file
    if touch "$log_file" 2>/dev/null; then
        export GOK_LOG_FILE="$log_file"
        log_debug "Log file set to: $log_file"
    else
        log_warning "Cannot write to log file: $log_file"
        return 1
    fi
}

# Rotate log file
rotate_log_file() {
    local log_file="${1:-$GOK_LOG_FILE}"
    local max_size="${2:-10485760}"  # 10MB default
    
    if [[ -f "$log_file" ]]; then
        local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        if [[ $file_size -gt $max_size ]]; then
            local backup_file="${log_file}.$(date +%Y%m%d_%H%M%S)"
            mv "$log_file" "$backup_file"
            log_info "Log file rotated: $backup_file"
        fi
    fi
}

# Clear log file
clear_log_file() {
    local log_file="${1:-$GOK_LOG_FILE}"
    
    if [[ -f "$log_file" ]]; then
        > "$log_file"
        log_debug "Log file cleared: $log_file"
    fi
}

# =============================================================================
# LOGGING CONFIGURATION FUNCTIONS
# =============================================================================

# Enable quiet mode
enable_quiet_mode() {
    export GOK_LOG_QUIET=true
    log_debug "Quiet mode enabled"
}

# Disable quiet mode  
disable_quiet_mode() {
    export GOK_LOG_QUIET=false
    log_debug "Quiet mode disabled"
}

# Enable timestamps
enable_timestamps() {
    export GOK_LOG_TIMESTAMP=true
    log_debug "Timestamps enabled"
}

# Disable timestamps
disable_timestamps() {
    export GOK_LOG_TIMESTAMP=false
    log_debug "Timestamps disabled"
}

# Enable caller information
enable_caller_info() {
    export GOK_LOG_CALLER=true
    log_debug "Caller information enabled"
}

# Disable caller information
disable_caller_info() {
    export GOK_LOG_CALLER=false
    log_debug "Caller information disabled"
}

# Show logging configuration
show_log_config() {
    echo -e "\n${COLOR_HEADER:-}GOK Logging Configuration${COLOR_RESET:-}"
    echo -e "${COLOR_DIM:-}═══════════════════════════════════════════${COLOR_RESET:-}"
    echo -e "Log Level: ${COLOR_INFO:-}${GOK_LOG_LEVEL}${COLOR_RESET:-}"
    echo -e "Log File: ${COLOR_FILE:-}${GOK_LOG_FILE:-none}${COLOR_RESET:-}"
    echo -e "Timestamps: ${COLOR_DIM:-}${GOK_LOG_TIMESTAMP}${COLOR_RESET:-}"
    echo -e "Caller Info: ${COLOR_DIM:-}${GOK_LOG_CALLER}${COLOR_RESET:-}"
    echo -e "Quiet Mode: ${COLOR_DIM:-}${GOK_LOG_QUIET}${COLOR_RESET:-}"
    echo -e "Colors: ${COLOR_DIM:-}$([[ "$GOK_LOG_NO_COLORS" == "true" ]] && echo "disabled" || echo "enabled")${COLOR_RESET:-}"
    echo
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export logging functions
export -f log_debug log_info log_success log_warning log_error log_critical
export -f log_step log_substep log_progress log_command log_file
export -f log_separator log_custom log_list log_header
export -f get_elapsed_time log_component_start log_component_success log_component_error
export -f log_next_steps log_urls log_credentials is_verbose_mode
export -f track_operation timed_operation
export -f execute_with_spinner execute_with_spinner_custom
export -f get_log_level_num set_log_level set_log_file rotate_log_file clear_log_file
export -f enable_quiet_mode disable_quiet_mode
export -f enable_timestamps disable_timestamps
export -f enable_caller_info disable_caller_info
export -f show_log_config

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Mark module as loaded
export GOK_LOGGING_LOADED="true"

# Initialize logging after functions are exported (commented out to prevent bootstrap issues)
# init_log_level