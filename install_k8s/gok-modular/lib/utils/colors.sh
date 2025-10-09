#!/bin/bash
# lib/utils/colors.sh
# Color definitions and utilities for GOK modular system
#
# This module provides standardized color constants and utility functions
# for consistent terminal output formatting across all GOK components.
#
# Usage:
#   source_gok_module "colors"
#   echo -e "${COLOR_GREEN}Success!${COLOR_RESET}"
#   echo -e "${COLOR_ERROR}Error occurred${COLOR_RESET}"
# =============================================================================

# Ensure this module is loaded only once
if [[ "${GOK_COLORS_LOADED:-}" == "true" ]]; then
    return 0
fi

# =============================================================================
# COLOR DETECTION AND SETUP
# =============================================================================

# Detect if colors are supported
detect_color_support() {
    # Check if we're in a terminal that supports colors
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null || echo 0)
        if [[ $colors -ge 8 ]]; then
            return 0  # Colors supported
        fi
    fi
    return 1  # No color support
}

# Initialize colors based on terminal capabilities
init_colors() {
    if detect_color_support && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${GOK_NO_COLOR:-}" != "true" ]]; then
        # Enable colors
        export GOK_COLORS_ENABLED=true
    else
        # Disable colors
        export GOK_COLORS_ENABLED=false
    fi
}

# =============================================================================
# BASE COLOR CONSTANTS
# =============================================================================

# Only set colors if they haven't been set already
if [[ -z "${COLOR_BLACK:-}" ]]; then
    if detect_color_support && [[ "${NO_COLOR:-}" != "1" ]] && [[ "${GOK_NO_COLOR:-}" != "true" ]]; then
        # Basic colors
        export COLOR_BLACK='\033[0;30m'
        export COLOR_RED='\033[0;31m'
        export COLOR_GREEN='\033[0;32m'
        export COLOR_YELLOW='\033[0;33m'
        export COLOR_BLUE='\033[0;34m'
        export COLOR_MAGENTA='\033[0;35m'
        export COLOR_CYAN='\033[0;36m'
        export COLOR_WHITE='\033[0;37m'
        
        # Bright colors
        export COLOR_BRIGHT_BLACK='\033[0;90m'
        export COLOR_BRIGHT_RED='\033[0;91m'
        export COLOR_BRIGHT_GREEN='\033[0;92m'
        export COLOR_BRIGHT_YELLOW='\033[0;93m'
        export COLOR_BRIGHT_BLUE='\033[0;94m'
        export COLOR_BRIGHT_MAGENTA='\033[0;95m'
        export COLOR_BRIGHT_CYAN='\033[0;96m'
        export COLOR_BRIGHT_WHITE='\033[0;97m'
        
        # Text formatting
        export COLOR_BOLD='\033[1m'
        export COLOR_DIM='\033[2m'
        export COLOR_UNDERLINE='\033[4m'
        export COLOR_BLINK='\033[5m'
        export COLOR_REVERSE='\033[7m'
        export COLOR_STRIKETHROUGH='\033[9m'
        
        # Reset
        export COLOR_RESET='\033[0m'
        
        # Background colors
        export BG_BLACK='\033[40m'
        export BG_RED='\033[41m'
        export BG_GREEN='\033[42m'
        export BG_YELLOW='\033[43m'
        export BG_BLUE='\033[44m'
        export BG_MAGENTA='\033[45m'
        export BG_CYAN='\033[46m'
        export BG_WHITE='\033[47m'
    else
        # No color mode - all color codes are empty
        export COLOR_BLACK=''
        export COLOR_RED=''
        export COLOR_GREEN=''
        export COLOR_YELLOW=''
        export COLOR_BLUE=''
        export COLOR_MAGENTA=''
        export COLOR_CYAN=''
        export COLOR_WHITE=''
        
        export COLOR_BRIGHT_BLACK=''
        export COLOR_BRIGHT_RED=''
        export COLOR_BRIGHT_GREEN=''
        export COLOR_BRIGHT_YELLOW=''
        export COLOR_BRIGHT_BLUE=''
        export COLOR_BRIGHT_MAGENTA=''
        export COLOR_BRIGHT_CYAN=''
        export COLOR_BRIGHT_WHITE=''
        
        export COLOR_BOLD=''
        export COLOR_DIM=''
        export COLOR_UNDERLINE=''
        export COLOR_BLINK=''
        export COLOR_REVERSE=''
        export COLOR_STRIKETHROUGH=''
        
        export COLOR_RESET=''
        
        export BG_BLACK=''
        export BG_RED=''
        export BG_GREEN=''
        export BG_YELLOW=''
        export BG_BLUE=''
        export BG_MAGENTA=''
        export BG_CYAN=''
        export BG_WHITE=''
    fi
fi

# =============================================================================
# SEMANTIC COLOR ALIASES
# =============================================================================

# Status colors
export COLOR_SUCCESS="$COLOR_GREEN"
export COLOR_ERROR="$COLOR_RED"
export COLOR_WARNING="$COLOR_YELLOW"
export COLOR_INFO="$COLOR_BLUE"
export COLOR_DEBUG="$COLOR_DIM"

# Component colors
export COLOR_HEADER="$COLOR_BOLD$COLOR_CYAN"
export COLOR_SUBHEADER="$COLOR_CYAN"
export COLOR_STEP="$COLOR_BOLD$COLOR_BLUE"
export COLOR_SUBSTEP="$COLOR_BLUE"
export COLOR_PROGRESS="$COLOR_GREEN"
export COLOR_COMMAND="$COLOR_MAGENTA"
export COLOR_FILE="$COLOR_YELLOW"
export COLOR_PATH="$COLOR_DIM"

# Status indicators
export COLOR_CHECKMARK="$COLOR_GREEN"
export COLOR_CROSSMARK="$COLOR_RED"
export COLOR_QUESTION="$COLOR_YELLOW"
export COLOR_ARROW="$COLOR_CYAN"

# =============================================================================
# COLOR UTILITY FUNCTIONS
# =============================================================================

# Apply color to text
colorize() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${COLOR_RESET}"
}

# Apply semantic colors
color_success() {
    colorize "$COLOR_SUCCESS" "$1"
}

color_error() {
    colorize "$COLOR_ERROR" "$1"
}

color_warning() {
    colorize "$COLOR_WARNING" "$1"
}

color_info() {
    colorize "$COLOR_INFO" "$1"
}

color_debug() {
    colorize "$COLOR_DEBUG" "$1"
}

color_header() {
    colorize "$COLOR_HEADER" "$1"
}

color_step() {
    colorize "$COLOR_STEP" "$1"
}

color_command() {
    colorize "$COLOR_COMMAND" "$1"
}

color_file() {
    colorize "$COLOR_FILE" "$1"
}

# Format with multiple styles
format_text() {
    local styles="$1"
    local text="$2"
    local formatted_text="$text"
    
    # Apply styles
    case "$styles" in
        *bold*) formatted_text="${COLOR_BOLD}${formatted_text}" ;;
    esac
    case "$styles" in
        *dim*) formatted_text="${COLOR_DIM}${formatted_text}" ;;
    esac
    case "$styles" in
        *underline*) formatted_text="${COLOR_UNDERLINE}${formatted_text}" ;;
    esac
    
    echo -e "${formatted_text}${COLOR_RESET}"
}

# =============================================================================
# PROGRESS AND STATUS INDICATORS
# =============================================================================

# Status symbols
get_status_symbol() {
    local status="$1"
    
    case "$status" in
        "success"|"ok"|"done")
            echo -e "${COLOR_CHECKMARK}✓${COLOR_RESET}"
            ;;
        "error"|"fail"|"failed")
            echo -e "${COLOR_CROSSMARK}✗${COLOR_RESET}"
            ;;
        "warning"|"warn")
            echo -e "${COLOR_WARNING}⚠${COLOR_RESET}"
            ;;
        "info"|"information")
            echo -e "${COLOR_INFO}ℹ${COLOR_RESET}"
            ;;
        "question"|"ask")
            echo -e "${COLOR_QUESTION}?${COLOR_RESET}"
            ;;
        "progress"|"working")
            echo -e "${COLOR_PROGRESS}⚡${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_ARROW}→${COLOR_RESET}"
            ;;
    esac
}

# Progress bar
show_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local prefix="${4:-Progress}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    printf "\r${COLOR_INFO}%s${COLOR_RESET}: ${COLOR_PROGRESS}[%s]${COLOR_RESET} %d%% (%d/%d)" \
           "$prefix" "$bar" "$percentage" "$current" "$total"
}

# =============================================================================
# COLOR THEME MANAGEMENT
# =============================================================================

# Set color theme
set_color_theme() {
    local theme="${1:-default}"
    
    case "$theme" in
        "minimal")
            export COLOR_SUCCESS="$COLOR_GREEN"
            export COLOR_ERROR="$COLOR_RED"
            export COLOR_WARNING="$COLOR_YELLOW"
            export COLOR_INFO="$COLOR_BLUE"
            export COLOR_HEADER="$COLOR_BOLD"
            export COLOR_STEP="$COLOR_BLUE"
            ;;
        "vibrant")
            export COLOR_SUCCESS="$COLOR_BRIGHT_GREEN"
            export COLOR_ERROR="$COLOR_BRIGHT_RED"
            export COLOR_WARNING="$COLOR_BRIGHT_YELLOW"
            export COLOR_INFO="$COLOR_BRIGHT_BLUE"
            export COLOR_HEADER="$COLOR_BOLD$COLOR_BRIGHT_CYAN"
            export COLOR_STEP="$COLOR_BOLD$COLOR_BRIGHT_BLUE"
            ;;
        "monochrome")
            export COLOR_SUCCESS="$COLOR_BOLD"
            export COLOR_ERROR="$COLOR_BOLD"
            export COLOR_WARNING="$COLOR_BOLD"
            export COLOR_INFO="$COLOR_DIM"
            export COLOR_HEADER="$COLOR_BOLD"
            export COLOR_STEP="$COLOR_BOLD"
            ;;
        "default"|*)
            # Keep the default semantic color assignments
            ;;
    esac
}

# Disable colors
disable_colors() {
    export GOK_NO_COLOR=true
    # Re-source this module to apply no-color mode
    source "${BASH_SOURCE[0]}"
}

# Enable colors
enable_colors() {
    unset GOK_NO_COLOR
    # Re-source this module to apply colors
    source "${BASH_SOURCE[0]}"
}

# =============================================================================
# COLOR TESTING AND DEBUGGING
# =============================================================================

# Show color palette
show_color_palette() {
    echo -e "${COLOR_HEADER}GOK Color Palette${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}\n"
    
    echo -e "${COLOR_BOLD}Basic Colors:${COLOR_RESET}"
    echo -e "  ${COLOR_BLACK}Black${COLOR_RESET} ${COLOR_RED}Red${COLOR_RESET} ${COLOR_GREEN}Green${COLOR_RESET} ${COLOR_YELLOW}Yellow${COLOR_RESET}"
    echo -e "  ${COLOR_BLUE}Blue${COLOR_RESET} ${COLOR_MAGENTA}Magenta${COLOR_RESET} ${COLOR_CYAN}Cyan${COLOR_RESET} ${COLOR_WHITE}White${COLOR_RESET}"
    
    echo -e "\n${COLOR_BOLD}Bright Colors:${COLOR_RESET}"
    echo -e "  ${COLOR_BRIGHT_BLACK}Bright Black${COLOR_RESET} ${COLOR_BRIGHT_RED}Bright Red${COLOR_RESET} ${COLOR_BRIGHT_GREEN}Bright Green${COLOR_RESET} ${COLOR_BRIGHT_YELLOW}Bright Yellow${COLOR_RESET}"
    echo -e "  ${COLOR_BRIGHT_BLUE}Bright Blue${COLOR_RESET} ${COLOR_BRIGHT_MAGENTA}Bright Magenta${COLOR_RESET} ${COLOR_BRIGHT_CYAN}Bright Cyan${COLOR_RESET} ${COLOR_BRIGHT_WHITE}Bright White${COLOR_RESET}"
    
    echo -e "\n${COLOR_BOLD}Text Formatting:${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}Bold${COLOR_RESET} ${COLOR_DIM}Dim${COLOR_RESET} ${COLOR_UNDERLINE}Underline${COLOR_RESET}"
    
    echo -e "\n${COLOR_BOLD}Semantic Colors:${COLOR_RESET}"
    echo -e "  $(get_status_symbol success) ${COLOR_SUCCESS}Success${COLOR_RESET}"
    echo -e "  $(get_status_symbol error) ${COLOR_ERROR}Error${COLOR_RESET}"
    echo -e "  $(get_status_symbol warning) ${COLOR_WARNING}Warning${COLOR_RESET}"
    echo -e "  $(get_status_symbol info) ${COLOR_INFO}Information${COLOR_RESET}"
    echo -e "  $(get_status_symbol progress) ${COLOR_PROGRESS}Progress${COLOR_RESET}"
    
    echo
}

# Test color functionality
test_colors() {
    echo "Testing color functionality..."
    
    # Test basic colorization
    colorize "$COLOR_GREEN" "Green text test"
    colorize "$COLOR_RED" "Red text test"
    
    # Test semantic colors
    color_success "Success message"
    color_error "Error message"
    color_warning "Warning message"
    color_info "Information message"
    
    # Test status symbols
    echo "Status symbols:"
    echo "  $(get_status_symbol success) Success"
    echo "  $(get_status_symbol error) Error"
    echo "  $(get_status_symbol warning) Warning"
    
    # Test progress bar
    echo "Progress bar test:"
    for i in {0..20}; do
        show_progress_bar $i 20 30 "Loading"
        sleep 0.1
    done
    echo
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

# Export color utility functions
export -f colorize
export -f color_success color_error color_warning color_info color_debug
export -f color_header color_step color_command color_file
export -f format_text
export -f get_status_symbol show_progress_bar
export -f set_color_theme disable_colors enable_colors
export -f show_color_palette test_colors
export -f detect_color_support init_colors

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize colors
init_colors

# Mark module as loaded
export GOK_COLORS_LOADED="true"