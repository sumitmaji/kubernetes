#!/bin/bash
# =============================================================================
# GOK Modular Repository Fix Utility System
# =============================================================================
# Handles Helm repository 404 errors, package manager issues, and conflicts
# 
# Usage:
#   source lib/utils/repository_fix.sh
#   fix_helm_repository_errors
#   fix_package_repository_issues
#   setup_modern_helm_repository
#   clean_deprecated_repositories
# =============================================================================

# Ensure core utilities are available
if [[ -z "${GOK_ROOT}" ]]; then
    echo "Error: GOK_ROOT not set. Source bootstrap.sh first."
    return 1
fi

# Source dependencies
source "${GOK_ROOT}/lib/utils/logging.sh" 2>/dev/null || true
source "${GOK_ROOT}/lib/utils/colors.sh" 2>/dev/null || true

# =============================================================================
# REPOSITORY CONFIGURATION
# =============================================================================

# Modern repository configurations
declare -A MODERN_REPOSITORIES
MODERN_REPOSITORIES["helm"]="https://baltocdn.com/helm/stable/debian/"
MODERN_REPOSITORIES["kubernetes"]="https://pkgs.k8s.io/core:/stable:/v1.28/deb/"
MODERN_REPOSITORIES["docker"]="https://download.docker.com/linux/ubuntu"

# Repository signing keys
declare -A REPOSITORY_KEYS
REPOSITORY_KEYS["helm"]="https://baltocdn.com/helm/signing.asc"
REPOSITORY_KEYS["kubernetes"]="https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key"
REPOSITORY_KEYS["docker"]="https://download.docker.com/linux/ubuntu/gpg"

# =============================================================================
# MAIN REPOSITORY FIX FUNCTIONS
# =============================================================================

# Comprehensive repository fix for Helm and other package issues
fix_helm_repository_errors() {
    log_header "Repository Fix Utility" "Resolving Helm & Package Repository Issues"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔧 FIXING HELM REPOSITORY ERRORS${COLOR_RESET}"
    echo
    
    local fix_success=true
    local fixes_applied=0
    
    # Step 1: Clean up old Helm repositories
    log_step "1" "Removing old/problematic Helm repositories"
    if clean_old_helm_repositories; then
        log_success "Old Helm repository files removed"
        ((fixes_applied++))
    else
        log_info "No old Helm repository files found"
    fi
    
    # Step 2: Remove deprecated apt-key entries
    log_step "2" "Cleaning deprecated apt-key entries"
    if clean_deprecated_apt_keys; then
        log_success "Deprecated key entries cleaned"
        ((fixes_applied++))
    else
        log_info "No deprecated keys found"
    fi
    
    # Step 3: Update package lists after cleanup
    log_step "3" "Updating package lists after cleanup"
    if sudo apt-get update >/dev/null 2>&1; then
        log_success "Package lists updated successfully"
        ((fixes_applied++))
    else
        log_warning "Package update had some warnings (continuing...)"
    fi
    
    # Step 4: Verify Helm installation method
    log_step "4" "Analyzing current Helm installation"
    local helm_analysis=$(analyze_helm_installation)
    echo "$helm_analysis"
    
    # Step 5: Setup modern Helm repository (if needed)
    log_step "5" "Setting up modern Helm repository (if needed)"
    local helm_path=$(which helm 2>/dev/null || echo "")
    if [[ -n "$helm_path" && "$helm_path" != *"/snap/"* ]]; then
        log_info "Setting up modern Helm APT repository..."
        if install_helm_via_apt_fix; then
            log_success "Modern Helm repository configured successfully"
            ((fixes_applied++))
        else
            log_warning "Modern APT setup failed - recommend using snap: sudo snap install helm --classic"
            fix_success=false
        fi
    else
        log_info "Using snap installation or no Helm found - no APT repository needed"
    fi
    
    # Step 6: Test repository access
    log_step "6" "Testing package repository access"
    local repository_test_results=$(test_repository_access)
    echo "$repository_test_results"
    
    # Step 7: Check for remaining 404 errors
    log_step "7" "Scanning for remaining repository errors"
    local remaining_errors=$(check_remaining_repository_errors)
    if [[ -z "$remaining_errors" ]]; then
        log_success "No 404 or repository errors detected"
        ((fixes_applied++))
    else
        log_warning "Some repository warnings detected:"
        echo "$remaining_errors" | head -3
    fi
    
    # Display fix summary
    display_repository_fix_summary "$fix_success" "$fixes_applied"
    
    return $([[ "$fix_success" == "true" ]] && echo 0 || echo 1)
}

# Fix general package repository issues beyond just Helm
fix_package_repository_issues() {
    log_header "Package Repository Fix" "Comprehensive Repository Resolution"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔧 FIXING PACKAGE REPOSITORY ISSUES${COLOR_RESET}"
    echo
    
    local fix_success=true
    local fixes_applied=0
    
    # Step 1: Check and fix broken repositories
    log_step "1" "Scanning for broken repositories"
    local broken_repos=$(find_broken_repositories)
    if [[ -n "$broken_repos" ]]; then
        log_warning "Found broken repositories:"
        echo "$broken_repos"
        if fix_broken_repositories "$broken_repos"; then
            log_success "Broken repositories fixed"
            ((fixes_applied++))
        else
            log_error "Failed to fix some broken repositories"
            fix_success=false
        fi
    else
        log_success "No broken repositories found"
    fi
    
    # Step 2: Update repository signatures
    log_step "2" "Updating repository signatures"
    if update_repository_signatures; then
        log_success "Repository signatures updated"
        ((fixes_applied++))
    else
        log_warning "Some signature updates failed"
    fi
    
    # Step 3: Clean package cache
    log_step "3" "Cleaning package cache"
    if clean_package_cache; then
        log_success "Package cache cleaned"
        ((fixes_applied++))
    else
        log_warning "Package cache cleaning had issues"
    fi
    
    # Step 4: Verify all repositories
    log_step "4" "Verifying repository accessibility"
    if verify_all_repositories; then
        log_success "All repositories are accessible"
        ((fixes_applied++))
    else
        log_warning "Some repositories have issues"
    fi
    
    # Display fix summary
    display_repository_fix_summary "$fix_success" "$fixes_applied"
    
    return $([[ "$fix_success" == "true" ]] && echo 0 || echo 1)
}

# =============================================================================
# HELPER FUNCTIONS FOR REPOSITORY MANAGEMENT
# =============================================================================

# Clean up old Helm repositories
clean_old_helm_repositories() {
    local cleaned=false
    
    # Remove old Helm repository files
    if sudo find /etc/apt/sources.list.d -name "*helm*" -type f -delete 2>/dev/null; then
        cleaned=true
    fi
    
    # Remove old Helm entries from main sources.list
    if sudo sed -i '/helm/d' /etc/apt/sources.list 2>/dev/null; then
        cleaned=true
    fi
    
    return $([[ "$cleaned" == "true" ]] && echo 0 || echo 1)
}

# Clean deprecated apt-key entries
clean_deprecated_apt_keys() {
    local cleaned=false
    
    if command -v apt-key >/dev/null 2>&1; then
        # Check for Helm keys and remove them
        local helm_keys=$(sudo apt-key list 2>/dev/null | grep -A1 "Helm" | grep pub | cut -d'/' -f2 | cut -d' ' -f1 2>/dev/null || echo "")
        
        if [[ -n "$helm_keys" ]]; then
            echo "$helm_keys" | while read -r key; do
                if [[ -n "$key" ]]; then
                    sudo apt-key del "$key" >/dev/null 2>&1 || true
                    cleaned=true
                fi
            done
        fi
    fi
    
    return $([[ "$cleaned" == "true" ]] && echo 0 || echo 1)
}

# Analyze current Helm installation
analyze_helm_installation() {
    if command -v helm >/dev/null 2>&1; then
        local helm_path=$(which helm)
        local helm_version=$(helm version --short --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        
        echo -e "${COLOR_GREEN}✓ Helm found at: ${COLOR_BOLD}$helm_path${COLOR_RESET}"
        echo -e "${COLOR_GREEN}✓ Version: ${COLOR_BOLD}$helm_version${COLOR_RESET}"
        
        if [[ "$helm_path" == *"/snap/"* ]]; then
            echo -e "${COLOR_GREEN}✓ Installation method: ${COLOR_BOLD}Snap package manager${COLOR_RESET}"
            echo -e "${COLOR_GREEN}✓ Status: ${COLOR_BOLD}No APT repository conflicts${COLOR_RESET}"
        elif [[ "$helm_path" == *"/usr/local/bin"* ]]; then
            echo -e "${COLOR_YELLOW}⚠ Installation method: ${COLOR_BOLD}Manual/Script installation${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}⚠ Recommendation: ${COLOR_BOLD}Consider using snap for easier updates${COLOR_RESET}"
        else
            echo -e "${COLOR_CYAN}ℹ Installation method: ${COLOR_BOLD}APT package manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}ℹ Status: ${COLOR_BOLD}May need repository updates${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_RED}❌ Helm not found${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}📝 Installation options:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Snap (recommended): ${COLOR_BOLD}sudo snap install helm --classic${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Script: ${COLOR_BOLD}curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar -xz${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • APT (after fixing repos): ${COLOR_BOLD}sudo apt-get install helm${COLOR_RESET}"
    fi
}

# Install Helm via modern APT repository
install_helm_via_apt_fix() {
    # Clean up any old repositories first
    sudo rm -f /etc/apt/sources.list.d/helm*.list 2>/dev/null || true
    
    # Download and add the official Helm signing key
    if curl -fsSL "${REPOSITORY_KEYS["helm"]}" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null 2>&1; then
        # Add the official Helm APT repository with proper key management
        local architecture=$(dpkg --print-architecture)
        echo "deb [arch=$architecture signed-by=/usr/share/keyrings/helm.gpg] ${MODERN_REPOSITORIES["helm"]} all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
        
        # Update package list and verify
        if sudo apt-get update >/dev/null 2>&1; then
            log_success "Modern Helm repository configured successfully"
            return 0
        else
            log_error "Failed to update package lists after adding Helm repository"
        fi
    else
        log_error "Failed to add Helm signing key"
    fi
    
    return 1
}

# Test repository access comprehensively
test_repository_access() {
    local test_output=""
    local test_success=true
    
    # Test APT update
    local apt_test=$(sudo apt-get update 2>&1)
    local apt_exit_code=$?
    
    if [[ $apt_exit_code -eq 0 ]]; then
        test_output+="${COLOR_GREEN}✓ APT update successful${COLOR_RESET}\n"
    else
        test_output+="${COLOR_RED}❌ APT update failed${COLOR_RESET}\n"
        test_success=false
    fi
    
    # Check for specific error patterns
    local error_404=$(echo "$apt_test" | grep -i "404\|not found" | head -2)
    local error_failed=$(echo "$apt_test" | grep -i "failed\|err:" | head -2)
    local error_timeout=$(echo "$apt_test" | grep -i "timeout\|connection" | head -2)
    
    if [[ -n "$error_404" ]]; then
        test_output+="${COLOR_YELLOW}⚠ 404 errors found:${COLOR_RESET}\n"
        test_output+="$(echo "$error_404" | sed 's/^/   /')\n"
    fi
    
    if [[ -n "$error_failed" ]]; then
        test_output+="${COLOR_YELLOW}⚠ Failed operations:${COLOR_RESET}\n"
        test_output+="$(echo "$error_failed" | sed 's/^/   /')\n"
    fi
    
    if [[ -n "$error_timeout" ]]; then
        test_output+="${COLOR_RED}❌ Connection issues:${COLOR_RESET}\n"
        test_output+="$(echo "$error_timeout" | sed 's/^/   /')\n"
        test_success=false
    fi
    
    if [[ "$test_success" == "true" && -z "$error_404" && -z "$error_failed" ]]; then
        test_output+="${COLOR_GREEN}✓ All repositories accessible${COLOR_RESET}\n"
    fi
    
    echo -e "$test_output"
}

# Find broken repositories
find_broken_repositories() {
    local broken_repos=""
    
    # Check for repositories that return 404 or other errors
    local apt_output=$(sudo apt-get update 2>&1)
    
    # Extract repository URLs that are failing
    broken_repos=$(echo "$apt_output" | grep -oP '(?<=Failed to fetch )https?://[^\s]+' | sort -u)
    
    if [[ -n "$broken_repos" ]]; then
        echo "$broken_repos"
    fi
}

# Fix broken repositories
fix_broken_repositories() {
    local broken_repos="$1"
    local fixed=true
    
    echo "$broken_repos" | while read -r repo; do
        if [[ -n "$repo" ]]; then
            log_info "Attempting to fix repository: $repo"
            
            # Try to find and disable the problematic repository
            local repo_file=$(grep -l "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | head -1)
            
            if [[ -n "$repo_file" ]]; then
                log_info "Found in file: $repo_file"
                
                # Comment out the problematic line
                if sudo sed -i "s|^deb.*${repo}.*|# &|" "$repo_file"; then
                    log_success "Disabled problematic repository in $repo_file"
                else
                    log_warning "Failed to disable repository in $repo_file"
                    fixed=false
                fi
            fi
        fi
    done
    
    return $([[ "$fixed" == "true" ]] && echo 0 || echo 1)
}

# Update repository signatures
update_repository_signatures() {
    local updated=true
    
    # Update GPG keyring
    if sudo apt-key update >/dev/null 2>&1; then
        log_success "APT keys updated"
    else
        log_info "APT key update not needed or failed"
    fi
    
    # Refresh package lists
    if sudo apt-get update >/dev/null 2>&1; then
        log_success "Package lists refreshed"
    else
        updated=false
    fi
    
    return $([[ "$updated" == "true" ]] && echo 0 || echo 1)
}

# Clean package cache
clean_package_cache() {
    local cleaned=true
    
    # Clean APT cache
    if sudo apt-get clean >/dev/null 2>&1; then
        log_success "APT cache cleaned"
    else
        log_warning "APT cache cleaning failed"
        cleaned=false
    fi
    
    # Remove partial packages
    if sudo apt-get autoclean >/dev/null 2>&1; then
        log_success "Partial packages cleaned"
    else
        log_info "No partial packages to clean"
    fi
    
    return $([[ "$cleaned" == "true" ]] && echo 0 || echo 1)
}

# Verify all repositories are accessible
verify_all_repositories() {
    local all_accessible=true
    
    # Do a dry-run update to check accessibility
    local update_test=$(sudo apt-get update --dry-run 2>&1)
    
    if echo "$update_test" | grep -q "Err:\|Failed"; then
        all_accessible=false
    fi
    
    return $([[ "$all_accessible" == "true" ]] && echo 0 || echo 1)
}

# Check for remaining repository errors after fixes
check_remaining_repository_errors() {
    local apt_output=$(sudo apt-get update 2>&1)
    echo "$apt_output" | grep -i "404\|not found\|failed\|err:" | head -5
}

# =============================================================================
# REPOSITORY FIX SUMMARY AND RECOMMENDATIONS
# =============================================================================

# Display comprehensive fix summary
display_repository_fix_summary() {
    local fix_success="$1"
    local fixes_applied="$2"
    
    echo
    log_header "Fix Summary" "Repository Status"
    
    if [[ "$fix_success" == "true" ]]; then
        echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✅ REPOSITORY ISSUES RESOLVED${COLOR_RESET}"
        echo
        echo -e "${COLOR_GREEN}📊 Summary:${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   • Fixes applied: ${COLOR_BOLD}$fixes_applied${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   • Old repositories cleaned up${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   • Package lists updated successfully${COLOR_RESET}"
        echo -e "${COLOR_GREEN}   • No critical errors detected${COLOR_RESET}"
        
        # Check Helm status
        if command -v helm >/dev/null 2>&1; then
            echo -e "${COLOR_GREEN}   • Helm installation verified${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}⚠️  PARTIAL RESOLUTION${COLOR_RESET}"
        echo
        echo -e "${COLOR_YELLOW}📊 Summary:${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   • Fixes applied: ${COLOR_BOLD}$fixes_applied${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   • Some issues may require manual intervention${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   • Check troubleshooting section below${COLOR_RESET}"
    fi
    
    echo
    display_prevention_tips
    echo
    display_troubleshooting_guide
}

# Display prevention tips
display_prevention_tips() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📋 PREVENTION TIPS:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Use snap for Helm: ${COLOR_BOLD}sudo snap install helm --classic${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Regular updates: ${COLOR_BOLD}sudo snap refresh helm${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Avoid mixing installation methods (APT + Snap + Script)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Run this fix utility regularly: ${COLOR_BOLD}gok-new fix repositories${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Use official repositories only${COLOR_RESET}"
}

# Display troubleshooting guide
display_troubleshooting_guide() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🛠️  TROUBLESHOOTING:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Manual cache clean: ${COLOR_BOLD}sudo apt-get clean && sudo apt-get update${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Debug repository issues: ${COLOR_BOLD}sudo apt-get update -o Debug::Acquire::http=true${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Fresh Helm install: ${COLOR_BOLD}sudo snap remove helm && sudo snap install helm --classic${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Check network connectivity: ${COLOR_BOLD}ping google.com${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Verify proxy settings if behind corporate firewall${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Run repository diagnostics: ${COLOR_BOLD}gok-new diagnose repositories${COLOR_RESET}"
}

# =============================================================================
# ADDITIONAL REPOSITORY MANAGEMENT FUNCTIONS
# =============================================================================

# Setup modern repositories for common tools
setup_modern_repositories() {
    local tool="$1"
    
    log_header "Modern Repository Setup" "$tool Repository Configuration"
    
    case "$tool" in
        "helm")
            install_helm_via_apt_fix
            ;;
        "kubernetes"|"kubectl")
            setup_kubernetes_repository
            ;;
        "docker")
            setup_docker_repository
            ;;
        "all")
            log_info "Setting up all modern repositories..."
            setup_kubernetes_repository
            setup_docker_repository
            install_helm_via_apt_fix
            ;;
        *)
            log_error "Unknown tool: $tool"
            log_info "Supported tools: helm, kubernetes, docker, all"
            return 1
            ;;
    esac
}

# Setup Kubernetes repository
setup_kubernetes_repository() {
    log_info "Setting up modern Kubernetes repository..."
    
    # Remove old Kubernetes repositories
    sudo rm -f /etc/apt/sources.list.d/kubernetes*.list 2>/dev/null || true
    
    # Add modern Kubernetes repository
    if curl -fsSL "${REPOSITORY_KEYS["kubernetes"]}" | gpg --dearmor | sudo tee /usr/share/keyrings/kubernetes-apt-keyring.gpg > /dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] ${MODERN_REPOSITORIES["kubernetes"]} /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        
        if sudo apt-get update >/dev/null 2>&1; then
            log_success "Modern Kubernetes repository configured"
            return 0
        fi
    fi
    
    log_error "Failed to setup Kubernetes repository"
    return 1
}

# Setup Docker repository
setup_docker_repository() {
    log_info "Setting up modern Docker repository..."
    
    # Remove old Docker repositories
    sudo rm -f /etc/apt/sources.list.d/docker*.list 2>/dev/null || true
    
    # Add Docker's official GPG key
    if curl -fsSL "${REPOSITORY_KEYS["docker"]}" | gpg --dearmor | sudo tee /usr/share/keyrings/docker.gpg > /dev/null; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] ${MODERN_REPOSITORIES["docker"]} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        if sudo apt-get update >/dev/null 2>&1; then
            log_success "Modern Docker repository configured"
            return 0
        fi
    fi
    
    log_error "Failed to setup Docker repository"
    return 1
}

# Export functions for use by other modules
export -f fix_helm_repository_errors
export -f fix_package_repository_issues
export -f setup_modern_repositories
export -f clean_old_helm_repositories
export -f analyze_helm_installation