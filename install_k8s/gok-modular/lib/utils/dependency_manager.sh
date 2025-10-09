#!/bin/bash
# lib/utils/dependency_manager.sh
# Comprehensive Dependency Management Utility for GOK-New Modular System
# 
# This utility provides advanced dependency management with:
# • Progress tracking with visual indicators and detailed logging
# • Smart caching to avoid redundant installations
# • Critical dependency verification and validation
# • Package-specific error handling and recovery
# • Comprehensive troubleshooting and diagnostics
# • Support for different package managers and installation methods
#
# Usage in components:
#   source_gok_utility "dependency_manager"
#   install_system_dependencies [--force-deps] [--skip-deps] [--verbose]
#   verify_critical_dependencies
#
# Integration example:
#   if ! ensure_dependencies_for_component "kubernetes"; then
#       log_error "Failed to install dependencies for kubernetes"
#       return 1
#   fi
# =============================================================================

# Ensure required utilities are available
if [[ "${GOK_UTILS_DEPENDENCY_MANAGER_LOADED:-}" == "true" ]]; then
    return 0
fi

# Global configuration for dependency management
: ${GOK_DEPS_CACHE_HOURS:="${GOK_UPDATE_CACHE_HOURS:-6}"}
: ${GOK_CACHE_DIR:="${GOK_CACHE_DIR:-/tmp/gok-cache}"}

# =============================================================================
# DEPENDENCY CACHE MANAGEMENT
# =============================================================================

# Check if dependency installation cache is still valid
is_dependencies_cache_valid() {
    local cache_file="$GOK_CACHE_DIR/last_deps_install"
    local cache_hours="${GOK_DEPS_CACHE_HOURS:-6}"
    
    # Create cache directory if it doesn't exist
    mkdir -p "$GOK_CACHE_DIR"
    
    # Check if cache file exists
    if [[ ! -f "$cache_file" ]]; then
        log_debug "Dependencies cache file not found: $cache_file"
        return 1  # No cache, need to install deps
    fi
    
    # Get cache timestamp
    local cache_time=$(cat "$cache_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local cache_age_hours=$(( (current_time - cache_time) / 3600 ))
    
    if [[ $cache_age_hours -lt $cache_hours ]]; then
        log_info "Dependencies cache is valid (installed ${cache_age_hours}h ago, cache expires in $((cache_hours - cache_age_hours))h)"
        return 0  # Cache is valid
    else
        log_info "Dependencies cache expired (${cache_age_hours}h old, cache limit: ${cache_hours}h)"
        return 1  # Cache expired, need to install deps
    fi
}

# Mark dependency installation cache as fresh
mark_dependencies_cache() {
    local cache_file="$GOK_CACHE_DIR/last_deps_install"
    mkdir -p "$GOK_CACHE_DIR"
    date +%s > "$cache_file"
    log_debug "Dependencies cache marked fresh at $(date)"
}

# Clear dependencies cache (force refresh)
clear_dependencies_cache() {
    local cache_file="$GOK_CACHE_DIR/last_deps_install"
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        log_info "Dependencies cache cleared"
    fi
}

# =============================================================================
# DEPENDENCY DEFINITIONS AND METADATA
# =============================================================================

# Define essential system dependencies with descriptions and categories
get_essential_dependencies() {
    local dependencies=(
        "net-tools:Network utilities and diagnostic tools:networking"
        "jq:JSON processor for command line operations:json"
        "python3:Python 3 interpreter for scripting:runtime"
        "python3-pip:Python package installer and manager:package-manager"
        "curl:Command line tool for transferring data with URLs:http-client"
        "wget:Network downloader and web client:http-client"
        "gnupg:GNU Privacy Guard for cryptographic operations:security"
        "software-properties-common:Tools for managing software repositories:repository"
        "apt-transport-https:HTTPS transport method for APT:security"
        "ca-certificates:Common CA certificates bundle:security"
        "unzip:Archive extraction utility:archive"
        "zip:Archive creation utility:archive"
        "git:Distributed version control system:vcs"
        "vim:Text editor for configuration files:editor"
    )
    
    printf '%s\n' "${dependencies[@]}"
}

# Define critical dependencies that must be available
get_critical_dependencies() {
    local critical=(
        "curl:HTTP client for downloading resources"
        "wget:Download utility for package retrieval" 
        "jq:JSON processor for API interactions"
        "python3:Python interpreter for scripting"
    )
    
    printf '%s\n' "${critical[@]}"
}

# Define component-specific dependencies
get_component_dependencies() {
    local component="$1"
    
    case "$component" in
        "kubernetes"|"k8s")
            echo "docker.io:Container runtime:container"
            echo "apt-transport-https:HTTPS transport for package repos:security"
            echo "ca-certificates:Certificate authorities:security"
            echo "gpg:GPG for package verification:security"
            ;;
        "monitoring"|"prometheus"|"grafana")
            echo "python3-yaml:YAML processing for configurations:config"
            echo "openssl:SSL/TLS toolkit for certificates:security"
            ;;
        "vault"|"security")
            echo "openssl:SSL/TLS toolkit:security"
            echo "gpg:GNU Privacy Guard:security"
            echo "jq:JSON processor for vault operations:json"
            ;;
        "jenkins"|"ci-cd")
            echo "openjdk-11-jdk:Java Development Kit:runtime"
            echo "maven:Build automation tool:build"
            ;;
        *)
            # Return empty for unknown components
            ;;
    esac
}

# =============================================================================
# DEPENDENCY INSTALLATION FUNCTIONS
# =============================================================================

# Enhanced dependency installation with progress tracking and error handling
install_system_dependencies() {
    local force_deps=false
    local skip_deps=false
    local verbose_mode=false
    local component_context="system"
    local start_time=$(date +%s)
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --force-deps|--force)
                force_deps=true
                ;;
            --skip-deps|--skip)
                skip_deps=true
                ;;
            --verbose|-v)
                verbose_mode=true
                ;;
            --component=*)
                component_context="${arg#*=}"
                ;;
        esac
    done
    
    # Skip dependencies if explicitly requested
    if [[ "$skip_deps" == "true" ]]; then
        log_info "Dependencies installation skipped (--skip-deps flag)"
        return 0
    fi
    
    # Check cache unless force install is requested
    if [[ "$force_deps" == "false" ]] && is_dependencies_cache_valid; then
        log_success "Dependencies installation skipped (cache is fresh)"
        return 0
    fi
    
    log_step "Dependencies" "Installing essential system dependencies for $component_context"
    
    # Force installation clears the cache first
    if [[ "$force_deps" == "true" ]]; then
        clear_dependencies_cache
        log_info "Force dependency installation requested - clearing cache"
    fi
    
    # Get dependencies to install
    local dependencies=()
    readarray -t dependencies < <(get_essential_dependencies)
    
    # Add component-specific dependencies if specified
    if [[ "$component_context" != "system" ]]; then
        local component_deps=()
        readarray -t component_deps < <(get_component_dependencies "$component_context")
        if [[ ${#component_deps[@]} -gt 0 ]]; then
            log_info "Adding ${#component_deps[@]} component-specific dependencies for $component_context"
            dependencies+=("${component_deps[@]}")
        fi
    fi
    
    local total_packages=${#dependencies[@]}
    local current_package=0
    local failed_packages=()
    local successful_packages=0
    
    log_info "Installing $total_packages dependencies..."
    
    for package_info in "${dependencies[@]}"; do
        IFS=':' read -r package_name package_desc package_category <<< "$package_info"
        current_package=$((current_package + 1))
        
        log_substep "Installing $package_name ($current_package/$total_packages)"
        
        if install_single_dependency "$package_name" "$package_desc" "$verbose_mode"; then
            successful_packages=$((successful_packages + 1))
        else
            failed_packages+=("$package_name")
        fi
        
        # Show progress
        show_dependency_progress "$current_package" "$total_packages" "Installing dependencies"
    done
    
    echo # New line after progress
    
    # Installation summary and cache management
    handle_dependency_installation_summary "$total_packages" "$successful_packages" "${failed_packages[@]}"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        mark_dependencies_cache
        log_success "All $total_packages dependencies installed successfully in ${duration}s"
        verify_critical_dependencies
        return 0
    else
        # Handle partial installation
        if [[ $successful_packages -gt $((total_packages / 2)) ]]; then
            mark_dependencies_cache
            log_warning "Partial installation completed ($successful_packages/$total_packages) in ${duration}s"
            verify_critical_dependencies
            return 0
        else
            log_error "Dependency installation failed ($successful_packages/$total_packages successful)"
            return 1
        fi
    fi
}

# Install a single dependency with error handling
install_single_dependency() {
    local package_name="$1"
    local package_desc="$2"
    local verbose_mode="$3"
    
    # Check if package is already installed
    if dpkg -l "$package_name" 2>/dev/null | grep -q "^ii"; then
        log_substep "✓ $package_name already installed"
        return 0
    fi
    
    if [[ "$verbose_mode" == "true" ]] || [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
        log_info "Installing $package_name: $package_desc"
        if apt-get install -y "$package_name"; then
            log_success "✓ $package_name installed successfully"
            return 0
        else
            log_error "✗ Failed to install $package_name"
            return 1
        fi
    else
        # Install with progress indication
        local temp_log=$(mktemp)
        local temp_exit="${temp_log}.exit"
        local pid
        
        # Start installation in background
        {
            apt-get install -y "$package_name" > "$temp_log" 2>&1
            echo $? > "$temp_exit"
        } &
        pid=$!
        
        # Show progress animation
        show_package_installation_progress "$pid" "$package_name"
        
        # Wait for completion
        wait $pid 2>/dev/null || true
        local exit_code
        if [[ -f "$temp_exit" ]]; then
            exit_code=$(cat "$temp_exit")
        else
            exit_code=1
        fi
        
        if [[ $exit_code -eq 0 ]]; then
            printf "\r${COLOR_GREEN}    ✓ $package_name installed successfully${COLOR_RESET}\n"
            rm -f "$temp_log" "$temp_exit"
            return 0
        else
            printf "\r${COLOR_RED}    ✗ $package_name installation failed${COLOR_RESET}\n"
            
            # Show error details for failed packages
            if [[ -f "$temp_log" ]]; then
                log_error "Installation error for $package_name:"
                tail -5 "$temp_log" | while read line; do
                    log_error "  $line"
                done
            fi
            
            rm -f "$temp_log" "$temp_exit"
            return 1
        fi
    fi
}

# Show animated progress for package installation
show_package_installation_progress() {
    local pid=$1
    local package_name=$2
    local dots=""
    local dot_count=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${COLOR_CYAN}    Installing $package_name${dots}${COLOR_RESET}"
        dots="${dots}."
        if [[ ${#dots} -gt 3 ]]; then 
            dots=""
        fi
        sleep 0.3
    done
}

# Show overall dependency installation progress
show_dependency_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percentage=$((current * 100 / total))
    
    # Create progress bar
    local bar_length=20
    local filled_length=$((percentage * bar_length / 100))
    local bar=""
    
    for ((i=0; i<filled_length; i++)); do
        bar="${bar}█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar="${bar}░"
    done
    
    printf "\r${COLOR_BLUE}  %s [%s] %d%% (%d/%d)${COLOR_RESET}" "$message" "$bar" "$percentage" "$current" "$total"
}

# Handle installation summary and provide troubleshooting
handle_dependency_installation_summary() {
    local total_packages=$1
    local successful_packages=$2
    shift 2
    local failed_packages=("$@")
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "$successful_packages/$total_packages dependencies installed successfully"
        log_error "Failed packages: ${failed_packages[*]}"
        
        # Provide troubleshooting suggestions
        show_dependency_troubleshooting "${failed_packages[@]}"
        
        if [[ ${#failed_packages[@]} -gt 3 ]]; then
            log_error "Too many failed packages - installation may be unstable"
        fi
    fi
}

# =============================================================================
# CRITICAL DEPENDENCY VERIFICATION
# =============================================================================

# Verify that critical dependencies are available and functional
verify_critical_dependencies() {
    log_substep "Verifying critical dependencies"
    
    local critical_commands=()
    readarray -t critical_commands < <(get_critical_dependencies)
    
    local missing_critical=()
    local verified_count=0
    
    for cmd_info in "${critical_commands[@]}"; do
        IFS=':' read -r cmd_name cmd_desc <<< "$cmd_info"
        
        if verify_single_critical_dependency "$cmd_name" "$cmd_desc"; then
            verified_count=$((verified_count + 1))
        else
            missing_critical+=("$cmd_name")
        fi
    done
    
    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_error "Critical dependencies missing: ${missing_critical[*]}"
        log_error "Installation cannot continue without these dependencies"
        show_critical_dependency_troubleshooting "${missing_critical[@]}"
        return 1
    fi
    
    log_success "All $verified_count critical dependencies verified"
    return 0
}

# Verify a single critical dependency
verify_single_critical_dependency() {
    local cmd_name="$1"
    local cmd_desc="$2"
    
    if command -v "$cmd_name" >/dev/null 2>&1; then
        # Additional verification for some commands
        case "$cmd_name" in
            "curl")
                if curl --version >/dev/null 2>&1; then
                    log_substep "✓ $cmd_name available and functional"
                    return 0
                fi
                ;;
            "jq")
                if echo '{"test": "value"}' | jq .test >/dev/null 2>&1; then
                    log_substep "✓ $cmd_name available and functional"
                    return 0
                fi
                ;;
            "python3")
                if python3 --version >/dev/null 2>&1; then
                    log_substep "✓ $cmd_name available and functional"
                    return 0
                fi
                ;;
            *)
                log_substep "✓ $cmd_name available"
                return 0
                ;;
        esac
    fi
    
    log_error "Critical dependency missing or non-functional: $cmd_name ($cmd_desc)"
    return 1
}

# =============================================================================
# DEPENDENCY TROUBLESHOOTING AND DIAGNOSTICS
# =============================================================================

# Show troubleshooting information for failed dependencies
show_dependency_troubleshooting() {
    local failed_packages=("$@")
    
    echo -e "\n${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔧 DEPENDENCY TROUBLESHOOTING${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Failed to install: ${failed_packages[*]}${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}Common solutions:${COLOR_RESET}"
    echo -e "  1. Update package cache: ${COLOR_DIM}sudo apt-get update${COLOR_RESET}"
    echo -e "  2. Fix broken packages: ${COLOR_DIM}sudo apt-get install -f${COLOR_RESET}"
    echo -e "  3. Check available space: ${COLOR_DIM}df -h /var${COLOR_RESET}"
    echo -e "  4. Check network connectivity: ${COLOR_DIM}ping archive.ubuntu.com${COLOR_RESET}"
    echo -e "  5. Install manually: ${COLOR_DIM}sudo apt-get install ${failed_packages[*]}${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Advanced troubleshooting:${COLOR_RESET}"
    echo -e "  • Check APT locks: ${COLOR_DIM}sudo lsof /var/lib/dpkg/lock-frontend${COLOR_RESET}"
    echo -e "  • Reset APT cache: ${COLOR_DIM}sudo apt-get clean && sudo apt-get update${COLOR_RESET}"
    echo -e "  • Check repository status: ${COLOR_DIM}sudo apt-get update 2>&1 | grep -i error${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}For verbose installation output:${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}GOK_VERBOSE=true gok install <component>${COLOR_RESET}"
    echo
}

# Show troubleshooting for critical dependencies
show_critical_dependency_troubleshooting() {
    local missing_critical=("$@")
    
    echo -e "\n${COLOR_BRIGHT_RED}${COLOR_BOLD}❌ CRITICAL DEPENDENCIES MISSING${COLOR_RESET}"
    echo -e "${COLOR_RED}Missing: ${missing_critical[*]}${COLOR_RESET}\n"
    
    echo -e "${COLOR_CYAN}Required actions:${COLOR_RESET}"
    echo -e "  1. Install missing packages: ${COLOR_DIM}sudo apt-get install ${missing_critical[*]}${COLOR_RESET}"
    echo -e "  2. Verify installation: ${COLOR_DIM}which ${missing_critical[0]}${COLOR_RESET}"
    echo -e "  3. Check PATH variable: ${COLOR_DIM}echo \$PATH${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}Alternative installation methods:${COLOR_RESET}"
    for cmd in "${missing_critical[@]}"; do
        case "$cmd" in
            "curl")
                echo -e "  • curl: ${COLOR_DIM}sudo snap install curl${COLOR_RESET}"
                ;;
            "jq")
                echo -e "  • jq: ${COLOR_DIM}sudo snap install jq${COLOR_RESET}"
                ;;
            "python3")
                echo -e "  • python3: ${COLOR_DIM}sudo apt-get install python3-minimal${COLOR_RESET}"
                ;;
        esac
    done
    echo
}

# Check dependency installation requirements
check_dependency_requirements() {
    local issues=()
    
    log_substep "Checking dependency installation requirements"
    
    # Check privileges
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        issues+=("Requires root privileges or sudo access")
    fi
    
    # Check package manager
    if ! command -v apt-get >/dev/null 2>&1; then
        issues+=("apt-get package manager not found")
    fi
    
    # Check disk space
    local var_space=$(df /var 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ $var_space -lt 204800 ]]; then  # Less than 200MB
        issues+=("Low disk space in /var (${var_space}KB available, need >200MB)")
    fi
    
    # Check network
    if ! ping -c 1 -W 5 archive.ubuntu.com >/dev/null 2>&1; then
        issues+=("Cannot reach package repositories (network issue)")
    fi
    
    # Report issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_error "Dependency installation requirements check failed:"
        for issue in "${issues[@]}"; do
            log_error "  • $issue"
        done
        return 1
    fi
    
    log_success "Dependency installation requirements satisfied"
    return 0
}

# =============================================================================
# CONVENIENCE FUNCTIONS FOR COMPONENT INTEGRATION
# =============================================================================

# Ensure dependencies for a specific component
ensure_dependencies_for_component() {
    local component_name="$1"
    shift
    local options=("$@")
    
    log_substep "Ensuring dependencies for $component_name"
    
    # Check requirements first
    if ! check_dependency_requirements; then
        log_error "Dependency requirements not met for $component_name"
        return 1
    fi
    
    # Install dependencies with component context
    if ! install_system_dependencies --component="$component_name" "${options[@]}"; then
        log_error "Failed to install dependencies for $component_name"
        return 1
    fi
    
    log_success "Dependencies ensured for $component_name"
    return 0
}

# Pre-installation dependency check for components  
prepare_dependencies_for_installation() {
    local component_name="$1"
    shift
    
    log_info "Preparing dependencies for $component_name installation"
    
    # Check cache first unless forced
    local force_requested=false
    for arg in "$@"; do
        if [[ "$arg" == "--force"* ]]; then
            force_requested=true
            break
        fi
    done
    
    if [[ "$force_requested" == "false" ]] && is_dependencies_cache_valid; then
        log_success "Dependencies already prepared for $component_name (cache valid)"
        return 0
    fi
    
    ensure_dependencies_for_component "$component_name" "$@"
}

# Verify dependencies are installed and functional
validate_component_dependencies() {
    local component_name="$1"
    
    log_substep "Validating dependencies for $component_name"
    
    # Always verify critical dependencies
    if ! verify_critical_dependencies; then
        log_error "Critical dependencies validation failed for $component_name"
        return 1
    fi
    
    # Component-specific dependency validation
    case "$component_name" in
        "kubernetes"|"k8s")
            validate_kubernetes_dependencies
            ;;
        "monitoring"|"prometheus")
            validate_monitoring_dependencies
            ;;
        *)
            log_success "Basic dependencies validated for $component_name"
            ;;
    esac
}

# Validate Kubernetes-specific dependencies
validate_kubernetes_dependencies() {
    local missing=()
    
    if ! command -v docker >/dev/null 2>&1; then
        missing+=("docker")
    fi
    
    if ! command -v gpg >/dev/null 2>&1; then
        missing+=("gpg")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Kubernetes dependencies missing: ${missing[*]}"
        return 1
    fi
    
    log_success "Kubernetes dependencies validated"
    return 0
}

# Validate monitoring-specific dependencies
validate_monitoring_dependencies() {
    local missing=()
    
    if ! python3 -c "import yaml" 2>/dev/null; then
        missing+=("python3-yaml")
    fi
    
    if ! command -v openssl >/dev/null 2>&1; then
        missing+=("openssl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Monitoring dependencies missing: ${missing[*]}"
        return 1
    fi
    
    log_success "Monitoring dependencies validated"
    return 0
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize dependency manager utility
init_dependency_manager_utility() {
    # Ensure cache directory exists
    mkdir -p "$GOK_CACHE_DIR"
    
    # Set default configurations
    : ${GOK_DEPS_CACHE_HOURS:="${GOK_UPDATE_CACHE_HOURS:-6}"}
    
    log_debug "Dependency manager utility initialized (cache dir: $GOK_CACHE_DIR, timeout: ${GOK_DEPS_CACHE_HOURS}h)"
}

# Module cleanup function
cleanup_dependency_manager_utility() {
    # Clean up any temporary files older than 24 hours
    find "$GOK_CACHE_DIR" -name "deps_*.tmp" -mtime +1 -delete 2>/dev/null || true
}

# Initialize the utility when sourced
init_dependency_manager_utility

# Mark module as loaded
export GOK_UTILS_DEPENDENCY_MANAGER_LOADED="true"

log_debug "Dependency Manager utility module loaded successfully"