#!/bin/bash

# GOK Logging Module - Comprehensive logging and output functions

# Color definitions for output formatting (only define if not already set by colors utility module)
if [[ -z "${COLOR_RED:-}" ]]; then
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_MAGENTA='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[1;37m'
    readonly COLOR_BRIGHT_RED='\033[1;31m'
    readonly COLOR_BRIGHT_GREEN='\033[1;32m'
    readonly COLOR_BRIGHT_YELLOW='\033[1;33m'
    readonly COLOR_BRIGHT_BLUE='\033[1;34m'
    readonly COLOR_BRIGHT_MAGENTA='\033[1;35m'
    readonly COLOR_BRIGHT_CYAN='\033[1;36m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_DIM='\033[2m'
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_NC='\033[0m' # No Color
fi

# Emoji definitions for better visual feedback
readonly EMOJI_SUCCESS="✅"
readonly EMOJI_ERROR="❌"
readonly EMOJI_WARNING="⚠️"
readonly EMOJI_INFO="ℹ️"
readonly EMOJI_ROCKET="🚀"
readonly EMOJI_GEAR="⚙️"
readonly EMOJI_PACKAGE="📦"
readonly EMOJI_ARROW="➜"
readonly EMOJI_CHECKMARK="✓"
readonly EMOJI_CROSS="✗"
readonly EMOJI_CLOCK="⏰"
readonly EMOJI_NETWORK="🌐"
readonly EMOJI_KEY="🔑"
readonly EMOJI_LIGHTBULB="💡"
readonly EMOJI_TOOLS="🔧"
readonly EMOJI_LINK="🔗"
readonly EMOJI_DEBUG="🐛"
readonly EMOJI_FIRE="🔥"

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
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

# Check if verbose mode is enabled
is_verbose_mode() {
    [[ "${GOK_VERBOSE:-false}" == "true" ]]
}

# Enhanced logging functions
log_header() {
    local title="$1"
    local subtitle="${2:-}"
    echo
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}=================================================================${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}  ${EMOJI_ROCKET} GOK Platform - $title${COLOR_RESET}"
    if [[ -n "$subtitle" ]]; then
        echo -e "${COLOR_CYAN}  $subtitle${COLOR_RESET}"
    fi
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}=================================================================${COLOR_RESET}"
    echo
}

log_section() {
    local title="$1"
    local emoji="${2:-$EMOJI_GEAR}"
    echo
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}--- $emoji $title ---${COLOR_RESET}"
}

log_success() {
    local message="$1"
    local timestamp=$(get_timestamp)
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}[$timestamp] ${EMOJI_SUCCESS} $message${COLOR_RESET}"
}

log_error() {
    local message="$1"
    local timestamp=$(get_timestamp)
    echo -e "${COLOR_RED}${COLOR_BOLD}[$timestamp] ${EMOJI_ERROR} $message${COLOR_RESET}" >&2
}

# Minimal core logging functions - will be enhanced by utils/logging.sh
log_warning() {
    # Stub function - will be overridden by utils/logging.sh
    return 0
}

log_info() {
    # Stub function - will be overridden by utils/logging.sh
    return 0
}

log_step() {
    local step="$1"
    local message="$2"
    local timestamp=$(get_timestamp)
    echo -e "${COLOR_BLUE}[$timestamp] ${COLOR_BOLD}Step $step:${COLOR_RESET} ${COLOR_CYAN}$message${COLOR_RESET}"
}

log_substep() {
    local message="$1"
    echo -e "  ${COLOR_DIM}${EMOJI_ARROW} $message${COLOR_RESET}"
}

log_debug() {
    # Stub function - will be overridden by utils/logging.sh
    return 0
}

log_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    echo -ne "\r${COLOR_BRIGHT_BLUE}$message [${COLOR_BRIGHT_GREEN}$bar${COLOR_BRIGHT_BLUE}] $percentage% ($current/$total)${COLOR_RESET}"
    if [[ $current -eq $total ]]; then
        echo
    fi
}

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

log_troubleshooting() {
    local component="$1"
    shift
    local tips=("$@")
    
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}${EMOJI_TOOLS} Troubleshooting $component:${COLOR_RESET}"
    for tip in "${tips[@]}"; do
        echo -e "  ${COLOR_YELLOW}• $tip${COLOR_RESET}"
    done
    echo
}

show_spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r${COLOR_BRIGHT_BLUE}%s [%c]${COLOR_RESET}" "$message" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%*s\r" ${#message} ""
}

# Display installation summary
show_installation_summary() {
    local component="$1"
    local namespace="${2:-default}"
    local additional_info="${3:-}"
    
    echo
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}│ ${EMOJI_PACKAGE} $component Installation Complete${COLOR_RESET}"
    echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────────────┤${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${EMOJI_CHECKMARK} Component: ${COLOR_BOLD}$component${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${EMOJI_NETWORK} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│ ${EMOJI_CLOCK} Completed: ${COLOR_BOLD}$(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}"
    if [[ -n "$additional_info" ]]; then
        echo -e "${COLOR_CYAN}│ ${EMOJI_INFO} Info: ${COLOR_BOLD}$additional_info${COLOR_RESET}"
    fi
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo
}

# Execute a command with suppressed output and return status
execute_with_suppression() {
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    # Execute command with both stdout and stderr captured
    if "$@" >"$temp_file" 2>"$error_file"; then
        rm -f "$temp_file" "$error_file"
        return 0
    else
        local exit_code=$?
        echo
        echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}│ ${EMOJI_ERROR} COMMAND EXECUTION FAILED - DEBUGGING INFORMATION ${COLOR_RESET}${COLOR_RED}${COLOR_BOLD}│${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_GEAR} Failed Command:${COLOR_RESET}" >&2
        echo -e "${COLOR_WHITE}  $*${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_CROSS} Exit Code: ${COLOR_RED}$exit_code${COLOR_RESET}" >&2
        
        # Show error output if available
        if [[ -s "$error_file" ]]; then
            echo -e "${COLOR_RED}${COLOR_BOLD}${EMOJI_ERROR} Error Output:${COLOR_RESET}" >&2
            echo -e "${COLOR_RED}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
            cat "$error_file" >&2
            echo -e "${COLOR_RED}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
        fi
        
        # Show standard output if available (may contain useful debugging info)
        if [[ -s "$temp_file" ]]; then
            echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_INFO} Standard Output:${COLOR_RESET}" >&2
            echo -e "${COLOR_YELLOW}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
            cat "$temp_file" >&2
            echo -e "${COLOR_YELLOW}─────────────────────────────────────────────────────────${COLOR_RESET}" >&2
        fi
        
        echo -e "${COLOR_CYAN}${COLOR_BOLD}${EMOJI_LIGHTBULB} Debugging Tips:${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• Check system logs: journalctl -u kubelet${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• Verify resources: kubectl get all -A${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• Check events: kubectl get events --sort-by='.lastTimestamp'${COLOR_RESET}" >&2
        echo
        
        rm -f "$temp_file" "$error_file"
        return $exit_code
    fi
}

# Legacy compatibility functions
echoSuccess() {
    log_success "$1"
}

echoFailed() {
    log_error "$1"
}

echoWarning() {
    log_warning "$1"
}