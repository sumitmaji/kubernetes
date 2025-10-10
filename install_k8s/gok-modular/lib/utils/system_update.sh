#!/bin/bash
# lib/utils/system_update.sh
# System Update Management Utility for GOK-New Modular System
# 
# This utility provides comprehensive system update management with:
# • Smart caching to avoid redundant updates
# • Progress tracking with visual indicators  
# • Verbose mode support for debugging
# • Force update and skip update options
# • Performance timing and reporting
#
# Usage in components:
#   source_gok_utility "system_update"
#   update_system [--force-update] [--skip-update] [--verbose]
#
# Integration example:
#   if ! update_system_with_cache; then
#       log_error "System update failed"
#       return 1
#   fi
# =============================================================================

# Ensure required utilities are available
if [[ "${GOK_UTILS_SYSTEM_UPDATE_LOADED:-}" == "true" ]]; then
    return 0
fi

# Global configuration for system updates
: ${GOK_UPDATE_CACHE_HOURS:=6}     # Cache system updates for 6 hours by default
: ${GOK_CACHE_DIR:="${GOK_CACHE_DIR:-/tmp/gok-cache}"}

# =============================================================================
# CACHE MANAGEMENT FUNCTIONS
# =============================================================================

# Check if system update cache is still valid
is_system_update_cache_valid() {
    local cache_file="$GOK_CACHE_DIR/last_system_update"
    local cache_hours="${GOK_UPDATE_CACHE_HOURS:-6}"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$GOK_CACHE_DIR"
    
    # Check if cache file exists
    if [[ ! -f "$cache_file" ]]; then
        log_debug "System update cache file not found: $cache_file"
        return 1  # No cache, need update
    fi
    
    # Get cache timestamp
    local cache_time=$(cat "$cache_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local cache_age_hours=$(( (current_time - cache_time) / 3600 ))
    
    if [[ $cache_age_hours -lt $cache_hours ]]; then
        log_info "System update cache is valid (updated ${cache_age_hours}h ago, cache expires in $((cache_hours - cache_age_hours))h)"
        return 0  # Cache is valid
    else
        log_info "System update cache expired (${cache_age_hours}h old, cache limit: ${cache_hours}h)"
        return 1  # Cache expired, need update
    fi
}

# Mark system update cache as fresh
mark_system_update_cache() {
    local cache_file="$GOK_CACHE_DIR/last_system_update"
    mkdir -p "$GOK_CACHE_DIR"
    date +%s > "$cache_file"
    log_debug "System update cache marked fresh at $(date)"
}

# Clear system update cache (force refresh)
clear_system_update_cache() {
    local cache_file="$GOK_CACHE_DIR/last_system_update"
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        log_info "System update cache cleared"
    fi
}

# Get cache status information
get_system_update_cache_status() {
    local cache_file="$GOK_CACHE_DIR/last_system_update"
    local cache_hours="${GOK_UPDATE_CACHE_HOURS:-6}"
    
    if [[ ! -f "$cache_file" ]]; then
        echo "no-cache"
        return
    fi
    
    local cache_time=$(cat "$cache_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local cache_age_hours=$(( (current_time - cache_time) / 3600 ))
    local cache_remaining_hours=$((cache_hours - cache_age_hours))
    
    if [[ $cache_age_hours -lt $cache_hours ]]; then
        echo "valid:${cache_age_hours}h:${cache_remaining_hours}h"
    else
        echo "expired:${cache_age_hours}h:0h"
    fi
}

# =============================================================================
# SYSTEM UPDATE FUNCTIONS
# =============================================================================

# Enhanced system update with progress bar and smart caching
update_system() {
    local force_update=false
    local skip_update=false
    local verbose_mode=false
    local start_time=$(date +%s)
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --force-update|--force)
                force_update=true
                ;;
            --skip-update|--skip)
                skip_update=true
                ;;
            --verbose|-v)
                verbose_mode=true
                ;;
        esac
    done
    
    # Skip update if explicitly requested
    if [[ "$skip_update" == "true" ]]; then
        log_info "System update skipped (--skip-update flag)"
        return 0
    fi
    
    # Check cache unless force update is requested
    if [[ "$force_update" == "false" ]] && is_system_update_cache_valid; then
        log_success "System update skipped (cache is fresh)"
        return 0
    fi
    
    log_step "System Update" "Updating package repositories"
    
    # Force update clears the cache first
    if [[ "$force_update" == "true" ]]; then
        clear_system_update_cache
        log_info "Force update requested - clearing cache"
    fi
    
    if is_verbose; then
        log_info "Running system update in verbose mode"
        if ! run_system_update_verbose; then
            log_error "System update failed"
            return 1
        fi
    else
        # Run with progress indication
        if ! run_system_update_with_progress; then
            log_error "System update failed"
            return 1
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Mark cache as fresh after successful update
    mark_system_update_cache
    
    log_success "System update completed in ${duration}s"
    return 0
}

# Run system update with verbose output
run_system_update_verbose() {
    log_info "Downloading package information with detailed output:"
    
    # First attempt: try normal update
    if apt-get update; then
        log_success "Package information updated successfully"
        return 0
    fi
    
    # If update failed, try automatic repository fix
    log_warning "Initial package update failed, attempting automatic repository fix..."
    
    # Attempt automatic repository fixes
    if auto_fix_repository_issues; then
        log_info "Repository issues fixed, retrying package update..."
        
        # Retry update after fixes
        if apt-get update; then
            log_success "Package information updated successfully after repository fix"
            return 0
        fi
    fi
    
    # Final fallback: try basic update ignoring some errors
    log_warning "Package update still failing, attempting basic update with error tolerance..."
    
    # Try to at least update what we can
    if apt-get update -o APT::Get::List-Cleanup=0 2>/dev/null; then
        log_warning "Package update completed with warnings - some repositories may be broken"
        return 0
    fi
    
    log_error "apt-get update failed even after repository fixes"
    return 1
}

# Run system update with progress indication
run_system_update_with_progress() {
    log_substep "Downloading package information"
    
    # Create a temporary file for capturing output
    local temp_log=$(mktemp)
    local temp_exit="${temp_log}.exit"
    local pid
    
    # Start the update process in background
    {
        apt-get update > "$temp_log" 2>&1
        echo $? > "$temp_exit"
    } &
    pid=$!
    
    # Show progress while update is running
    show_system_update_progress $pid "$temp_log"
    
    # Wait for process to complete and get exit code
    wait $pid 2>/dev/null || true
    local exit_code
    if [[ -f "$temp_exit" ]]; then
        exit_code=$(cat "$temp_exit")
    else
        exit_code=1
    fi
    
    printf "\r${COLOR_GREEN}  Repository update completed [✓] 100%%${COLOR_RESET}\n"
    
    # Check for errors
    if [[ $exit_code -ne 0 ]]; then
        log_warning "Initial system update failed, attempting automatic repository fix..."
        cat "$temp_log"
        
        # Attempt automatic repository fixes
        if auto_fix_repository_issues; then
            log_info "Repository issues fixed, retrying system update..."
            
            # Retry update with progress after fixes
            {
                apt-get update > "$temp_log" 2>&1
                echo $? > "$temp_exit"
            } &
            pid=$!
            
            # Show progress while update is running
            show_system_update_progress $pid "$temp_log"
            
            # Wait for process to complete and get exit code
            wait $pid 2>/dev/null || true
            if [[ -f "$temp_exit" ]]; then
                exit_code=$(cat "$temp_exit")
            else
                exit_code=1
            fi
            
            printf "\r${COLOR_GREEN}  Repository update completed [✓] 100%%${COLOR_RESET}\n"
            
            # Check retry results
            if [[ $exit_code -ne 0 ]]; then
                log_error "System update failed even after repository fixes:"
                cat "$temp_log"
                rm -f "$temp_log" "$temp_exit"
                return 1
            fi
        else
            log_error "System update failed and repository fix was unsuccessful:"
            rm -f "$temp_log" "$temp_exit"
            return 1
        fi
    fi
    
    # Check for important warnings in output
    if grep -qi "error\|fail\|warning" "$temp_log"; then
        log_warning "Update completed with warnings"
        if [[ "${GOK_DEBUG:-false}" == "true" ]]; then
            log_info "Update output summary:"
            grep -i "error\|fail\|warning" "$temp_log" | head -5 | while read line; do
                log_warning "  $line"
            done
        else
            log_info "Use --verbose flag or set GOK_DEBUG=true for detailed output"
        fi
    fi
    
    # Clean up
    rm -f "$temp_log" "$temp_exit"
    return 0
}

# Show animated progress indicator for system update
show_system_update_progress() {
    local pid=$1
    local log_file=$2
    local progress=0
    local spinner_chars="|/-\\"
    local spinner_idx=0
    local dot_count=0
    
    while kill -0 $pid 2>/dev/null; do
        local char=${spinner_chars:spinner_idx:1}
        local dots=""
        for ((i=0; i<dot_count; i++)); do
            dots="${dots}."
        done
        
        printf "\r${COLOR_BLUE}  Updating repositories [%c] %d%%%s${COLOR_RESET}" "$char" "$progress" "$dots"
        
        spinner_idx=$(( (spinner_idx + 1) % 4 ))
        progress=$(( (progress + 1) % 101 ))
        dot_count=$(( (dot_count + 1) % 4 ))
        sleep 0.2
    done
}

# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

# Update system with cache checking (most common usage)
update_system_with_cache() {
    update_system "$@"
}

# Force system update (bypass cache)
force_system_update() {
    update_system --force-update "$@"
}

# Skip system update (for testing/dry-run)
skip_system_update() {
    log_info "System update skipped (skip_system_update called)"
    return 0
}

# Update system only if cache is invalid
update_system_if_needed() {
    if ! is_system_update_cache_valid; then
        log_info "System update cache invalid - updating"
        update_system "$@"
    else
        log_success "System update cache valid - skipping update"
        return 0
    fi
}

# =============================================================================
# SYSTEM UPDATE DIAGNOSTICS
# =============================================================================

# Check system update requirements and environment
check_system_update_requirements() {
    local issues=()
    
    log_substep "Checking system update requirements"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        issues+=("Requires root privileges or sudo access")
    fi
    
    # Check if apt-get is available
    if ! command -v apt-get >/dev/null 2>&1; then
        issues+=("apt-get command not found")
    fi
    
    # Check disk space in /var
    local var_space=$(df /var 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ $var_space -lt 102400 ]]; then  # Less than 100MB
        issues+=("Low disk space in /var (${var_space}KB available)")
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 5 archive.ubuntu.com >/dev/null 2>&1; then
        issues+=("Cannot reach package repositories (network issue)")
    fi
    
    # Check lock files
    if [[ -f /var/lib/dpkg/lock-frontend ]] || [[ -f /var/lib/apt/lists/lock ]]; then
        if pgrep -x apt >/dev/null || pgrep -x apt-get >/dev/null; then
            issues+=("Another package manager is running")
        fi
    fi
    
    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_error "System update requirements check failed:"
        for issue in "${issues[@]}"; do
            log_error "  • $issue"
        done
        return 1
    fi
    
    log_success "System update requirements satisfied"
    return 0
}

# Display system update status and cache information
show_system_update_status() {
    local cache_status=$(get_system_update_cache_status)
    
    echo -e "\n${COLOR_BOLD}${COLOR_BRIGHT_BLUE}SYSTEM UPDATE STATUS${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    case "$cache_status" in
        "no-cache")
            echo -e "Cache Status: ${COLOR_YELLOW}No cache found${COLOR_RESET}"
            echo -e "Recommendation: ${COLOR_CYAN}Run system update${COLOR_RESET}"
            ;;
        "valid:"*)
            local age=$(echo "$cache_status" | cut -d: -f2)
            local remaining=$(echo "$cache_status" | cut -d: -f3)
            echo -e "Cache Status: ${COLOR_GREEN}Valid${COLOR_RESET} (age: $age, expires in: $remaining)"
            echo -e "Recommendation: ${COLOR_GREEN}System update not needed${COLOR_RESET}"
            ;;
        "expired:"*)
            local age=$(echo "$cache_status" | cut -d: -f2)
            echo -e "Cache Status: ${COLOR_RED}Expired${COLOR_RESET} (age: $age)"
            echo -e "Recommendation: ${COLOR_CYAN}Run system update${COLOR_RESET}"
            ;;
    esac
    
    echo -e "Cache Directory: ${COLOR_DIM}$GOK_CACHE_DIR${COLOR_RESET}"
    echo -e "Cache Timeout: ${COLOR_DIM}${GOK_UPDATE_CACHE_HOURS}h${COLOR_RESET}"
    
    # Show last update time if available
    local cache_file="$GOK_CACHE_DIR/last_system_update"
    if [[ -f "$cache_file" ]]; then
        local last_update=$(date -d @$(cat "$cache_file" 2>/dev/null || echo "0") 2>/dev/null || echo "Unknown")
        echo -e "Last Update: ${COLOR_DIM}$last_update${COLOR_RESET}"
    fi
    
    echo
}

# =============================================================================
# INTEGRATION HELPERS FOR COMPONENTS
# =============================================================================

# Wrapper function for components - handles all common patterns
ensure_system_updated() {
    local component_name="${1:-unknown}"
    local options=("${@:2}")
    
    log_substep "Ensuring system is updated for $component_name"
    
    # Check requirements first
    if ! check_system_update_requirements; then
        log_error "System update requirements not met for $component_name"
        return 1
    fi
    
    # Run update with provided options
    if ! update_system "${options[@]}"; then
        log_error "Failed to update system for $component_name installation"
        return 1
    fi
    
    log_success "System update completed for $component_name"
    return 0
}

# Pre-installation system update for components
prepare_system_for_installation() {
    local component_name="$1"
    shift
    
    log_info "Preparing system for $component_name installation"
    
    # Always check cache first unless forced
    local force_requested=false
    for arg in "$@"; do
        if [[ "$arg" == "--force"* ]]; then
            force_requested=true
            break
        fi
    done
    
    if [[ "$force_requested" == "false" ]] && is_system_update_cache_valid; then
        log_success "System already prepared for $component_name (cache valid)"
        return 0
    fi
    
    ensure_system_updated "$component_name" "$@"
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize system update utility
init_system_update_utility() {
    # Ensure cache directory exists
    mkdir -p "$GOK_CACHE_DIR"
    
    # Set default configurations if not already set
    : ${GOK_UPDATE_CACHE_HOURS:=6}
    
    log_debug "System update utility initialized (cache dir: $GOK_CACHE_DIR, timeout: ${GOK_UPDATE_CACHE_HOURS}h)"
}

# =============================================================================
# SAFE WRAPPER FUNCTIONS WITH AUTOMATIC FALLBACK
# =============================================================================

# Safe wrapper for system updates with automatic fallback
safe_update_system_with_cache() {
    # Try to use the modular function first
    if declare -f update_system_with_cache >/dev/null 2>&1; then
        update_system_with_cache "$@"
        return $?
    fi
    
    # Fallback to basic system update
    if declare -f log_warning >/dev/null 2>&1; then
        log_warning "update_system_with_cache not available, using fallback system update"
    else
        echo "WARNING: update_system_with_cache not available, using fallback system update"
    fi
    
    local skip_update=false
    local force_update=false
    
    # Parse arguments for fallback
    for arg in "$@"; do
        case "$arg" in
            --skip-update)
                skip_update=true
                ;;
            --force-update)
                force_update=true
                ;;
        esac
    done
    
    # Skip if requested
    if [[ "$skip_update" == "true" ]]; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "System update skipped (--skip-update flag)"
        else
            echo "INFO: System update skipped (--skip-update flag)"
        fi
        return 0
    fi
    
    # Check cache unless force update
    local cache_file="/tmp/gok-cache/last_system_update"
    local cache_hours=6
    
    if [[ "$force_update" == "false" ]] && [[ -f "$cache_file" ]]; then
        local cache_time=$(cat "$cache_file" 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local cache_age_hours=$(( (current_time - cache_time) / 3600 ))
        
        if [[ $cache_age_hours -lt $cache_hours ]]; then
            if declare -f log_info >/dev/null 2>&1; then
                log_info "System update skipped (cache is fresh, ${cache_age_hours}h old)"
            else
                echo "INFO: System update skipped (cache is fresh, ${cache_age_hours}h old)"
            fi
            return 0
        fi
    fi
    
    # Perform basic system update with automatic repository fixing
    if declare -f log_info >/dev/null 2>&1; then
        log_info "Updating system packages..."
    else
        echo "INFO: Updating system packages..."
    fi
    
    # First attempt: try normal update
    if apt-get update >/dev/null 2>&1; then
        # Update successful, proceed with upgrade
        if apt-get upgrade -y >/dev/null 2>&1; then
            # Mark cache as fresh
            mkdir -p "$(dirname "$cache_file")"
            date +%s > "$cache_file"
            if declare -f log_success >/dev/null 2>&1; then
                log_success "System update completed successfully"
            else
                echo "SUCCESS: System update completed successfully"
            fi
            return 0
        fi
    fi
    
    # If update failed, try automatic repository fix
    if declare -f log_warning >/dev/null 2>&1; then
        log_warning "Initial system update failed, attempting automatic repository fix..."
    else
        echo "WARNING: Initial system update failed, attempting automatic repository fix..."
    fi
    
    # Attempt automatic repository fixes
    if auto_fix_repository_issues; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "Repository issues fixed, retrying system update..."
        else
            echo "INFO: Repository issues fixed, retrying system update..."
        fi
        
        # Retry update after fixes
        if apt-get update >/dev/null 2>&1 && apt-get upgrade -y >/dev/null 2>&1; then
            # Mark cache as fresh
            mkdir -p "$(dirname "$cache_file")"
            date +%s > "$cache_file"
            if declare -f log_success >/dev/null 2>&1; then
                log_success "System update completed successfully after repository fix"
            else
                echo "SUCCESS: System update completed successfully after repository fix"
            fi
            return 0
        fi
    fi
    
    # Final fallback: basic update ignoring errors
    if declare -f log_warning >/dev/null 2>&1; then
        log_warning "System update still failing, proceeding with basic update..."
    else
        echo "WARNING: System update still failing, proceeding with basic update..."
    fi
    
    # Try to at least update what we can
    apt-get update 2>/dev/null || true
    
    if declare -f log_warning >/dev/null 2>&1; then
        log_warning "System update completed with warnings - some repositories may be broken"
    else
        echo "WARNING: System update completed with warnings - some repositories may be broken"
    fi
    return 0  # Don't fail the entire installation due to repository issues
}

# Automatic repository fix function (fallback implementation)
auto_fix_repository_issues() {
    # Try to use the modular repository fix utility if available
    if declare -f fix_package_repository_issues >/dev/null 2>&1; then
        fix_package_repository_issues
        return $?
    fi
    
    # Fallback repository fixes
    local fixes_applied=false
    
    # Fix 1: Remove broken Kubernetes repositories
    if [[ -f "/etc/apt/sources.list.d/kubernetes.list" ]]; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "Fixing broken Kubernetes repositories..."
        else
            echo "INFO: Fixing broken Kubernetes repositories..."
        fi
        
        # Backup original file
        cp /etc/apt/sources.list.d/kubernetes.list /etc/apt/sources.list.d/kubernetes.list.bak 2>/dev/null || true
        
        # Remove old kubernetes repository entries
        sed -i '/apt.kubernetes.io/d' /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true
        sed -i '/packages.cloud.google.com.*kubernetes-xenial/d' /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true
        
        # Add modern kubernetes repository if not present
        if ! grep -q "pkgs.k8s.io" /etc/apt/sources.list.d/kubernetes.list 2>/dev/null; then
            echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
        fi
        
        fixes_applied=true
    fi
    
    # Fix 2: Remove broken Helm repositories
    if [[ -f "/etc/apt/sources.list.d/helm-stable-debian.list" ]]; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "Removing problematic Helm repository..."
        else
            echo "INFO: Removing problematic Helm repository..."
        fi
        
        rm -f /etc/apt/sources.list.d/helm-stable-debian.list 2>/dev/null || true
        fixes_applied=true
    fi
    
    # Fix 3: Clean package cache
    if [[ "$fixes_applied" == "true" ]]; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "Cleaning package cache after repository fixes..."
        else
            echo "INFO: Cleaning package cache after repository fixes..."
        fi
        
        apt-get clean 2>/dev/null || true
        rm -rf /var/lib/apt/lists/* 2>/dev/null || true
        
        return 0
    fi
    
    return 1
}

# Module cleanup function
cleanup_system_update_utility() {
    # Clean up any temporary files older than 24 hours
    find "$GOK_CACHE_DIR" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
}

# Initialize the utility when sourced
init_system_update_utility

# Mark module as loaded
export GOK_UTILS_SYSTEM_UPDATE_LOADED="true"

log_debug "System Update utility module loaded successfully"