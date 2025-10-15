#!/bin/bash
# =============================================================================
# GOK Modular Interactive Installation System
# =============================================================================
# Guided wizard with prerequisite checking and component selection
# 
# Usage:
#   source lib/utils/interactive.sh
#   interactive_installation
#   show_installation_wizard
#   check_prerequisites
#   interactive_component_selection
# =============================================================================

# Ensure core utilities are available
if [[ -z "${GOK_ROOT}" ]]; then
    echo "Error: GOK_ROOT not set. Source bootstrap.sh first."
    return 1
fi

# Source dependencies
source "${GOK_ROOT}/lib/utils/logging.sh" 2>/dev/null || true
source "${GOK_ROOT}/lib/utils/colors.sh" 2>/dev/null || true
source "${GOK_ROOT}/lib/utils/guidance.sh" 2>/dev/null || true

# =============================================================================
# INTERACTIVE INSTALLATION CONFIGURATION
# =============================================================================

# Installation profiles for different use cases
declare -A INSTALLATION_PROFILES
INSTALLATION_PROFILES["minimal"]="kubernetes ingress cert-manager"
INSTALLATION_PROFILES["development"]="kubernetes ingress cert-manager registry monitoring argocd jupyter"
INSTALLATION_PROFILES["production"]="kubernetes cert-manager ingress vault monitoring keycloak kyverno argocd"
INSTALLATION_PROFILES["security"]="kubernetes cert-manager vault kyverno keycloak oauth2 monitoring"
INSTALLATION_PROFILES["complete"]="kubernetes helm cert-manager ingress vault kyverno keycloak oauth2 monitoring registry argocd jenkins jupyter dashboard"

# Component categories for organized display
declare -A COMPONENT_CATEGORIES
COMPONENT_CATEGORIES["Core Infrastructure"]="kubernetes docker helm"
COMPONENT_CATEGORIES["Security & Certificates"]="cert-manager vault kyverno keycloak oauth2"
COMPONENT_CATEGORIES["Networking & Ingress"]="ingress"
COMPONENT_CATEGORIES["Monitoring & Observability"]="monitoring"
COMPONENT_CATEGORIES["Development Tools"]="registry argocd jenkins jupyter"
COMPONENT_CATEGORIES["Platform Services"]="base dashboard"

# Prerequisites for each component
declare -A COMPONENT_PREREQUISITES
COMPONENT_PREREQUISITES["kubernetes"]="docker"
COMPONENT_PREREQUISITES["ingress"]="kubernetes"
COMPONENT_PREREQUISITES["cert-manager"]="kubernetes"
COMPONENT_PREREQUISITES["vault"]="kubernetes"
COMPONENT_PREREQUISITES["keycloak"]="kubernetes"
COMPONENT_PREREQUISITES["monitoring"]="kubernetes"
COMPONENT_PREREQUISITES["argocd"]="kubernetes"
COMPONENT_PREREQUISITES["jupyter"]="kubernetes"
COMPONENT_PREREQUISITES["registry"]="kubernetes"

# =============================================================================
# MAIN INTERACTIVE INSTALLATION WIZARD
# =============================================================================

# Interactive installation wizard
interactive_installation() {
    log_header "GOK Interactive Installation Wizard" "Guided Platform Setup"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🚀 Welcome to the GOK Platform Interactive Installation!${COLOR_RESET}"
    echo -e "${COLOR_CYAN}This wizard will guide you through setting up your Kubernetes platform.${COLOR_RESET}"
    echo
    
    # Show welcome message and options
    show_welcome_message
    
    # Check system prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed. Please resolve the issues and try again."
        echo
        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}💡 NEXT STEPS:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}1. Resolve the prerequisite issues listed above${COLOR_RESET}"
        echo -e "${COLOR_CYAN}2. Re-run the interactive installation: ${COLOR_BOLD}gok-new install --interactive${COLOR_RESET}"
        echo -e "${COLOR_CYAN}3. Or install prerequisites: ${COLOR_BOLD}gok-new install docker${COLOR_RESET}"
        return 1
    fi
    
    # Show installation options
    show_installation_options
    
    # Get user's installation choice
    local installation_choice
    installation_choice=$(get_installation_choice)
    
    case "$installation_choice" in
        "profile")
            interactive_profile_installation
            ;;
        "custom")
            interactive_custom_installation
            ;;
        "guided")
            interactive_guided_installation
            ;;
        "quick")
            interactive_quick_installation
            ;;
        *)
            log_error "Invalid installation choice"
            return 1
            ;;
    esac
}

# Show welcome message and system overview
show_welcome_message() {
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🎯 INSTALLATION WIZARD FEATURES:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Automatic prerequisite checking${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Guided component selection${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Installation progress tracking${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Post-installation configuration guidance${COLOR_RESET}"
    echo -e "${COLOR_GREEN}✓ Automatic dependency resolution${COLOR_RESET}"
    echo
    
    # Show current system status
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}💻 SYSTEM OVERVIEW:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🖥️  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Linux")${COLOR_RESET}"
    echo -e "${COLOR_CYAN}🏗️  Architecture: $(uname -m)${COLOR_RESET}"
    echo -e "${COLOR_CYAN}💾 RAM: $(free -h | grep Mem | awk '{print $2}')${COLOR_RESET}"
    echo -e "${COLOR_CYAN}💿 Disk: $(df -h / | tail -1 | awk '{print $4}' | head -1) available${COLOR_RESET}"
    echo
}

# Show installation options
show_installation_options() {
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}📋 INSTALLATION OPTIONS:${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}1. ${COLOR_BOLD}Profile-based Installation${COLOR_RESET} - Choose from predefined profiles"
    echo -e "${COLOR_DIM}   • Minimal, Development, Production, Security, Complete${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}2. ${COLOR_BOLD}Custom Installation${COLOR_RESET} - Select individual components"
    echo -e "${COLOR_DIM}   • Full control over component selection${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}3. ${COLOR_BOLD}Guided Installation${COLOR_RESET} - Step-by-step component setup"
    echo -e "${COLOR_DIM}   • Recommended for beginners${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}4. ${COLOR_BOLD}Quick Installation${COLOR_RESET} - Install minimal platform quickly"
    echo -e "${COLOR_DIM}   • Kubernetes + Ingress + Certificates${COLOR_RESET}"
    echo
}

# Get user's installation choice
get_installation_choice() {
    while true; do
        echo -e "${COLOR_BRIGHT_YELLOW}❓ Select installation mode [1-4]:${COLOR_RESET} "
        read -r choice
        
        case "$choice" in
            1|"profile")
                echo "profile"
                return
                ;;
            2|"custom")
                echo "custom"
                return
                ;;
            3|"guided")
                echo "guided"
                return
                ;;
            4|"quick")
                echo "quick"
                return
                ;;
            *)
                echo -e "${COLOR_RED}❌ Invalid choice. Please select 1-4.${COLOR_RESET}"
                ;;
        esac
    done
}

# =============================================================================
# INSTALLATION MODE IMPLEMENTATIONS
# =============================================================================

# Profile-based installation
interactive_profile_installation() {
    log_header "Profile Installation" "Choose from predefined installation profiles"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📦 AVAILABLE INSTALLATION PROFILES:${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_GREEN}1. ${COLOR_BOLD}Minimal${COLOR_RESET} - Basic Kubernetes platform"
    echo -e "${COLOR_DIM}   Components: ${INSTALLATION_PROFILES["minimal"]}${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}2. ${COLOR_BOLD}Development${COLOR_RESET} - Full development environment"
    echo -e "${COLOR_DIM}   Components: ${INSTALLATION_PROFILES["development"]}${COLOR_RESET}"
    echo
    echo -e "${COLOR_YELLOW}3. ${COLOR_BOLD}Production${COLOR_RESET} - Production-ready platform"
    echo -e "${COLOR_DIM}   Components: ${INSTALLATION_PROFILES["production"]}${COLOR_RESET}"
    echo
    echo -e "${COLOR_RED}4. ${COLOR_BOLD}Security${COLOR_RESET} - Security-focused setup"
    echo -e "${COLOR_DIM}   Components: ${INSTALLATION_PROFILES["security"]}${COLOR_RESET}"
    echo
    echo -e "${COLOR_BRIGHT_MAGENTA}5. ${COLOR_BOLD}Complete${COLOR_RESET} - Full platform with all components"
    echo -e "${COLOR_DIM}   Components: ${INSTALLATION_PROFILES["complete"]}${COLOR_RESET}"
    echo
    
    local profile_choice
    profile_choice=$(get_profile_choice)
    
    case "$profile_choice" in
        "minimal"|"development"|"production"|"security"|"complete")
            install_profile "$profile_choice"
            ;;
        *)
            log_error "Invalid profile choice"
            return 1
            ;;
    esac
}

# Custom component installation
interactive_custom_installation() {
    log_header "Custom Installation" "Select individual components"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🛠️  CUSTOM COMPONENT SELECTION:${COLOR_RESET}"
    echo
    
    local selected_components=()
    
    # Show components by category
    for category in "${!COMPONENT_CATEGORIES[@]}"; do
        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}$category:${COLOR_RESET}"
        
        local components=${COMPONENT_CATEGORIES[$category]}
        for component in $components; do
            local description="${GOK_MODULE_DESCRIPTIONS[$component]:-"Platform component"}"
            echo -e "${COLOR_CYAN}  ☐ $component${COLOR_RESET} - $description"
        done
        echo
    done
    
    # Get component selections
    echo -e "${COLOR_BRIGHT_YELLOW}❓ Enter components to install (space-separated, or 'help' for guidance):${COLOR_RESET}"
    read -r component_input
    
    if [[ "$component_input" == "help" ]]; then
        show_component_help
        return
    fi
    
    # Parse and validate component selection
    IFS=' ' read -ra selected_components <<< "$component_input"
    
    if validate_component_selection "${selected_components[@]}"; then
        install_custom_components "${selected_components[@]}"
    else
        log_error "Invalid component selection"
        return 1
    fi
}

# Guided step-by-step installation
interactive_guided_installation() {
    log_header "Guided Installation" "Step-by-step platform setup"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}👨‍🏫 GUIDED INSTALLATION PROCESS:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}We'll walk through each component and explain what it does.${COLOR_RESET}"
    echo
    
    local components_to_install=()
    
    # Core infrastructure first
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 1: Core Infrastructure${COLOR_RESET}"
    if guided_component_choice "kubernetes" "Container orchestration platform - Required for all other components"; then
        components_to_install+=("kubernetes")
    else
        log_error "Kubernetes is required for GOK platform"
        return 1
    fi
    
    # Networking
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 2: Networking & Traffic Management${COLOR_RESET}"
    if guided_component_choice "ingress" "HTTP/HTTPS traffic routing - Recommended for web access"; then
        components_to_install+=("ingress")
    fi
    
    # Certificates
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 3: Certificate Management${COLOR_RESET}"
    if guided_component_choice "cert-manager" "Automated TLS certificate management - Recommended for secure connections"; then
        components_to_install+=("cert-manager")
    fi
    
    # Monitoring
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 4: Monitoring & Observability${COLOR_RESET}"
    if guided_component_choice "monitoring" "Prometheus & Grafana monitoring stack - Recommended for production"; then
        components_to_install+=("monitoring")
    fi
    
    # Security
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 5: Security & Secrets${COLOR_RESET}"
    if guided_component_choice "vault" "HashiCorp Vault for secrets management - Recommended for production"; then
        components_to_install+=("vault")
    fi
    
    # Development tools
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}Step 6: Development Tools${COLOR_RESET}"
    if guided_component_choice "argocd" "GitOps deployment platform - Recommended for CI/CD"; then
        components_to_install+=("argocd")
    fi
    
    if guided_component_choice "jupyter" "Interactive development environment - Optional"; then
        components_to_install+=("jupyter")
    fi
    
    # Install selected components
    if [[ ${#components_to_install[@]} -gt 0 ]]; then
        install_guided_components "${components_to_install[@]}"
    else
        log_error "No components selected for installation"
        return 1
    fi
}

# Quick installation with minimal components
interactive_quick_installation() {
    log_header "Quick Installation" "Fast minimal platform setup"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}⚡ QUICK INSTALLATION:${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Installing minimal platform components for immediate use:${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}• Kubernetes cluster${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• NGINX Ingress Controller${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Certificate Manager${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_BRIGHT_YELLOW}❓ Proceed with quick installation? [y/N]:${COLOR_RESET} "
    read -r proceed
    
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
        install_quick_components
    else
        log_info "Quick installation cancelled"
        echo
        echo -e "${COLOR_CYAN}💡 You can run other installation modes:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Profile installation: ${COLOR_BOLD}gok-new install --profile development${COLOR_RESET}"
        echo -e "${COLOR_CYAN}• Custom installation: ${COLOR_BOLD}gok-new install --interactive${COLOR_RESET}"
    fi
}

# =============================================================================
# HELPER FUNCTIONS FOR INSTALLATION MODES
# =============================================================================

# Get profile choice from user
get_profile_choice() {
    while true; do
        echo -e "${COLOR_BRIGHT_YELLOW}❓ Select installation profile [1-5]:${COLOR_RESET} "
        read -r choice
        
        case "$choice" in
            1|"minimal")
                echo "minimal"
                return
                ;;
            2|"development"|"dev")
                echo "development"
                return
                ;;
            3|"production"|"prod")
                echo "production"
                return
                ;;
            4|"security"|"sec")
                echo "security"
                return
                ;;
            5|"complete"|"full")
                echo "complete"
                return
                ;;
            *)
                echo -e "${COLOR_RED}❌ Invalid choice. Please select 1-5.${COLOR_RESET}"
                ;;
        esac
    done
}

# Guided component choice with explanation
guided_component_choice() {
    local component="$1"
    local description="$2"
    
    echo -e "${COLOR_CYAN}📦 ${COLOR_BOLD}$component${COLOR_RESET}: $description"
    
    # Check if already installed
    if is_component_installed "$component"; then
        echo -e "${COLOR_GREEN}   ✅ Already installed${COLOR_RESET}"
        return 1
    fi
    
    # Show prerequisites if any
    local prereqs="${COMPONENT_PREREQUISITES[$component]}"
    if [[ -n "$prereqs" ]]; then
        echo -e "${COLOR_YELLOW}   📋 Prerequisites: $prereqs${COLOR_RESET}"
    fi
    
    while true; do
        echo -e "${COLOR_BRIGHT_YELLOW}   ❓ Install $component? [Y/n/skip/help]:${COLOR_RESET} "
        read -r choice
        
        case "$choice" in
            ""|"y"|"Y"|"yes"|"YES")
                return 0
                ;;
            "n"|"N"|"no"|"NO"|"skip")
                return 1
                ;;
            "help"|"h")
                show_component_detailed_help "$component"
                ;;
            *)
                echo -e "${COLOR_RED}   ❌ Invalid choice. Enter y/n/skip/help${COLOR_RESET}"
                ;;
        esac
    done
}

# Show detailed help for a component
show_component_detailed_help() {
    local component="$1"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📖 DETAILED HELP: $component${COLOR_RESET}"
    
    case "$component" in
        "kubernetes")
            echo -e "${COLOR_CYAN}Kubernetes is the core container orchestration platform.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Required for all other GOK components${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Provides container scheduling, scaling, and management${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Essential for running containerized applications${COLOR_RESET}"
            ;;
        "ingress")
            echo -e "${COLOR_CYAN}NGINX Ingress Controller manages HTTP/HTTPS traffic routing.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Provides external access to cluster services${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Handles SSL termination and load balancing${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Required for web-based component access${COLOR_RESET}"
            ;;
        "cert-manager")
            echo -e "${COLOR_CYAN}Certificate Manager automates TLS certificate provisioning.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Automatically obtains and renews SSL certificates${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Integrates with Let's Encrypt and other CAs${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Essential for secure HTTPS communications${COLOR_RESET}"
            ;;
        "monitoring")
            echo -e "${COLOR_CYAN}Monitoring stack includes Prometheus and Grafana.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Collects and visualizes cluster and application metrics${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Provides alerting and monitoring dashboards${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Essential for production operations${COLOR_RESET}"
            ;;
        "vault")
            echo -e "${COLOR_CYAN}HashiCorp Vault provides secrets management.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Securely stores and manages sensitive data${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Provides encryption and access control${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Recommended for production security${COLOR_RESET}"
            ;;
        "argocd")
            echo -e "${COLOR_CYAN}ArgoCD is a GitOps continuous deployment platform.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Automates application deployment from Git repositories${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Provides declarative application management${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Essential for modern CI/CD workflows${COLOR_RESET}"
            ;;
        "jupyter")
            echo -e "${COLOR_CYAN}JupyterHub provides interactive development environments.${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Multi-user Jupyter notebook server${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Supports data science and interactive computing${COLOR_RESET}"
            echo -e "${COLOR_CYAN}• Optional for development workflows${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_CYAN}Description: ${GOK_MODULE_DESCRIPTIONS[$component]:-"Platform component"}${COLOR_RESET}"
            ;;
    esac
    echo
}

# Validate component selection
validate_component_selection() {
    local components=("$@")
    
    # Check if components exist
    for component in "${components[@]}"; do
        if [[ -z "${GOK_MODULE_DESCRIPTIONS[$component]}" && "$component" != "kubernetes" && "$component" != "docker" && "$component" != "helm" ]]; then
            log_error "Unknown component: $component"
            return 1
        fi
    done
    
    # Check prerequisites
    for component in "${components[@]}"; do
        local prereqs="${COMPONENT_PREREQUISITES[$component]}"
        if [[ -n "$prereqs" ]]; then
            for prereq in $prereqs; do
                if ! is_component_installed "$prereq" && [[ ! " ${components[@]} " =~ " $prereq " ]]; then
                    log_error "Component $component requires $prereq, but it's not selected or installed"
                    return 1
                fi
            done
        fi
    done
    
    return 0
}

# Check if component is already installed
is_component_installed() {
    local component="$1"
    
    case "$component" in
        "docker")
            systemctl is-active --quiet docker
            ;;
        "kubernetes")
            kubectl cluster-info >/dev/null 2>&1
            ;;
        "helm")
            command -v helm >/dev/null 2>&1
            ;;
        "ingress")
            kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1
            ;;
        "cert-manager")
            kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1
            ;;
        "monitoring")
            kubectl get deployment prometheus-operator -n monitoring >/dev/null 2>&1
            ;;
        "vault")
            kubectl get statefulset vault -n vault >/dev/null 2>&1
            ;;
        "keycloak")
            kubectl get statefulset keycloak -n keycloak >/dev/null 2>&1
            ;;
        "argocd")
            kubectl get deployment argocd-server -n argocd >/dev/null 2>&1
            ;;
        "jupyter")
            kubectl get deployment hub -n jupyterhub >/dev/null 2>&1
            ;;
        "registry")
            kubectl get deployment registry -n registry >/dev/null 2>&1
            ;;
        *)
            # Generic check
            kubectl get deployment "$component" >/dev/null 2>&1 || kubectl get statefulset "$component" >/dev/null 2>&1
            ;;
    esac
}

# =============================================================================
# INSTALLATION EXECUTION FUNCTIONS
# =============================================================================

# Install components from profile
install_profile() {
    local profile="$1"
    local components="${INSTALLATION_PROFILES[$profile]}"
    
    log_header "Profile Installation" "Installing $profile profile components"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🚀 INSTALLING $profile PROFILE${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Components: $components${COLOR_RESET}"
    echo
    
    # Show estimated installation time
    local estimated_time=$(calculate_installation_time $components)
    echo -e "${COLOR_CYAN}⏱️  Estimated installation time: $estimated_time minutes${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_BRIGHT_YELLOW}❓ Continue with installation? [Y/n]:${COLOR_RESET} "
    read -r proceed
    
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled by user"
        return 0
    fi
    
    # Install components in order
    execute_component_installation $components
}

# Install custom selected components
install_custom_components() {
    local components=("$@")
    
    log_header "Custom Installation" "Installing selected components"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🛠️  CUSTOM INSTALLATION${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Selected components: ${components[*]}${COLOR_RESET}"
    echo
    
    # Resolve dependencies
    local resolved_components=$(resolve_dependencies "${components[@]}")
    echo -e "${COLOR_CYAN}📋 Installation order (with dependencies): $resolved_components${COLOR_RESET}"
    echo
    
    local estimated_time=$(calculate_installation_time $resolved_components)
    echo -e "${COLOR_CYAN}⏱️  Estimated installation time: $estimated_time minutes${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_BRIGHT_YELLOW}❓ Continue with installation? [Y/n]:${COLOR_RESET} "
    read -r proceed
    
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled by user"
        return 0
    fi
    
    execute_component_installation $resolved_components
}

# Install components from guided selection
install_guided_components() {
    local components=("$@")
    
    log_header "Guided Installation" "Installing selected components"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}👨‍🏫 GUIDED INSTALLATION COMPLETE${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Components to install: ${components[*]}${COLOR_RESET}"
    echo
    
    # Resolve dependencies
    local resolved_components=$(resolve_dependencies "${components[@]}")
    if [[ "$resolved_components" != "${components[*]}" ]]; then
        echo -e "${COLOR_CYAN}📋 Added dependencies: $resolved_components${COLOR_RESET}"
        echo
    fi
    
    execute_component_installation $resolved_components
}

# Install quick minimal components
install_quick_components() {
    log_header "Quick Installation" "Installing minimal platform"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}⚡ QUICK INSTALLATION STARTING${COLOR_RESET}"
    echo
    
    local quick_components="kubernetes ingress cert-manager"
    execute_component_installation $quick_components
}

# Execute the actual component installation
execute_component_installation() {
    local components="$1"
    local total_components=$(echo "$components" | wc -w)
    local current=0
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔄 INSTALLATION PROGRESS${COLOR_RESET}"
    echo
    
    for component in $components; do
        ((current++))
        
        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}[$current/$total_components] Installing $component...${COLOR_RESET}"
        
        # Skip if already installed
        if is_component_installed "$component"; then
            log_success "$component is already installed - skipping"
            continue
        fi
        
        # Install component
        if install_single_component "$component"; then
            log_success "$component installed successfully"
            
            # Show component-specific guidance
            if command -v show_component_guidance >/dev/null 2>&1; then
                show_component_guidance "$component"
            fi
        else
            log_error "$component installation failed"
            
            # Ask user how to proceed
            echo -e "${COLOR_BRIGHT_YELLOW}❓ Installation failed. How would you like to proceed?${COLOR_RESET}"
            echo -e "${COLOR_CYAN}1. Continue with remaining components${COLOR_RESET}"
            echo -e "${COLOR_CYAN}2. Retry this component${COLOR_RESET}"
            echo -e "${COLOR_CYAN}3. Abort installation${COLOR_RESET}"
            
            read -r failure_choice
            case "$failure_choice" in
                1|"continue")
                    log_warning "Continuing with remaining components..."
                    ;;
                2|"retry")
                    log_info "Retrying $component installation..."
                    ((current--)) # Reset counter for retry
                    continue
                    ;;
                *)
                    log_error "Installation aborted by user"
                    return 1
                    ;;
            esac
        fi
        
        echo
    done
    
    # Show completion summary
    show_installation_completion_summary "$components"
}

# Install a single component
install_single_component() {
    local component="$1"
    
    # Use the main gok-new install command if available
    if command -v gok-new >/dev/null 2>&1; then
        gok-new install "$component"
    else
        log_error "gok-new command not found"
        return 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Calculate estimated installation time
calculate_installation_time() {
    local components="$1"
    local total_time=0
    
    # Rough time estimates per component (in minutes)
    for component in $components; do
        case "$component" in
            "docker") total_time=$((total_time + 3)) ;;
            "kubernetes") total_time=$((total_time + 10)) ;;
            "helm") total_time=$((total_time + 2)) ;;
            "ingress") total_time=$((total_time + 5)) ;;
            "cert-manager") total_time=$((total_time + 7)) ;;
            "monitoring") total_time=$((total_time + 15)) ;;
            "vault") total_time=$((total_time + 8)) ;;
            "keycloak") total_time=$((total_time + 12)) ;;
            "argocd") total_time=$((total_time + 10)) ;;
            "jupyter") total_time=$((total_time + 8)) ;;
            "registry") total_time=$((total_time + 5)) ;;
            *) total_time=$((total_time + 5)) ;;
        esac
    done
    
    echo "$total_time"
}

# Resolve component dependencies
resolve_dependencies() {
    local components=("$@")
    local resolved=()
    local to_add=()
    
    # Start with user-selected components
    resolved=("${components[@]}")
    
    # Add prerequisites
    for component in "${components[@]}"; do
        local prereqs="${COMPONENT_PREREQUISITES[$component]}"
        if [[ -n "$prereqs" ]]; then
            for prereq in $prereqs; do
                if [[ ! " ${resolved[@]} " =~ " $prereq " ]]; then
                    to_add+=("$prereq")
                fi
            done
        fi
    done
    
    # Add prerequisites to the beginning of the list
    if [[ ${#to_add[@]} -gt 0 ]]; then
        resolved=("${to_add[@]}" "${resolved[@]}")
    fi
    
    echo "${resolved[*]}"
}

# =============================================================================
# PREREQUISITE CHECKING
# =============================================================================

# Check system prerequisites
check_prerequisites() {
    log_info "🔍 Checking system prerequisites..."
    
    local prerequisites_met=true
    local issues_found=()
    
    # Check if running as root or with sudo capabilities
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root - this is not recommended"
        echo -e "${COLOR_YELLOW}💡 Consider running as a regular user with sudo privileges${COLOR_RESET}"
    elif ! sudo -n true 2>/dev/null; then
        log_error "Sudo access required for installation"
        prerequisites_met=false
        issues_found+=("sudo_access")
    else
        log_success "Sudo access available"
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local min_space=10485760 # 10GB in KB
    
    if [[ "$available_space" -lt "$min_space" ]]; then
        log_error "Insufficient disk space. Available: $(( available_space / 1024 / 1024 ))GB, Required: 10GB"
        prerequisites_met=false
        issues_found+=("disk_space")
    else
        log_success "Sufficient disk space available"
    fi
    
    # Check available memory (minimum 4GB)
    local available_memory=$(free -k | grep MemTotal | awk '{print $2}')
    local min_memory=4194304 # 4GB in KB
    
    if [[ "$available_memory" -lt "$min_memory" ]]; then
        log_error "Insufficient memory. Available: $(( available_memory / 1024 / 1024 ))GB, Required: 4GB"
        prerequisites_met=false
        issues_found+=("memory")
    else
        log_success "Sufficient memory available"
    fi
    
    # Check required commands
    local required_commands=("curl" "wget" "git" "tar" "systemctl")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            prerequisites_met=false
            issues_found+=("missing_$cmd")
        else
            log_success "$cmd is available"
        fi
    done
    
    # Check network connectivity
    if ! curl -s --connect-timeout 5 https://google.com >/dev/null 2>&1; then
        log_error "No internet connectivity detected"
        prerequisites_met=false
        issues_found+=("network")
    else
        log_success "Internet connectivity verified"
    fi
    
    # Show resolution suggestions if issues found
    if [[ "$prerequisites_met" == "false" ]]; then
        echo
        echo -e "${COLOR_BRIGHT_RED}${COLOR_BOLD}❌ PREREQUISITE ISSUES FOUND${COLOR_RESET}"
        echo
        show_prerequisite_resolution "${issues_found[@]}"
    else
        echo
        log_success "All prerequisites met - ready for installation"
    fi
    
    return $([[ "$prerequisites_met" == "true" ]] && echo 0 || echo 1)
}

# Show prerequisite issue resolution
show_prerequisite_resolution() {
    local issues=("$@")
    
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🛠️  RESOLUTION STEPS:${COLOR_RESET}"
    
    for issue in "${issues[@]}"; do
        case "$issue" in
            "sudo_access")
                echo -e "${COLOR_CYAN}• Add sudo access: ${COLOR_BOLD}usermod -aG sudo \$USER${COLOR_RESET}"
                ;;
            "disk_space")
                echo -e "${COLOR_CYAN}• Free up disk space or add more storage${COLOR_RESET}"
                echo -e "${COLOR_CYAN}• Clean package cache: ${COLOR_BOLD}sudo apt-get clean${COLOR_RESET}"
                ;;
            "memory")
                echo -e "${COLOR_CYAN}• Add more RAM to the system${COLOR_RESET}"
                echo -e "${COLOR_CYAN}• Close unnecessary applications${COLOR_RESET}"
                ;;
            "missing_"*)
                local cmd=${issue#missing_}
                echo -e "${COLOR_CYAN}• Install $cmd: ${COLOR_BOLD}sudo apt-get install $cmd${COLOR_RESET}"
                ;;
            "network")
                echo -e "${COLOR_CYAN}• Check network configuration and firewall settings${COLOR_RESET}"
                echo -e "${COLOR_CYAN}• Verify DNS settings${COLOR_RESET}"
                ;;
        esac
    done
}

# =============================================================================
# COMPLETION AND SUMMARY
# =============================================================================

# Show installation completion summary
show_installation_completion_summary() {
    local components="$1"
    
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🎉 INSTALLATION COMPLETED!${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_GREEN}✅ Installed components: $components${COLOR_RESET}"
    echo
    
    # Show platform access information
    show_platform_access_info
    
    # Show next steps
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🚀 NEXT STEPS:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}1. Verify installation: ${COLOR_BOLD}gok-new status${COLOR_RESET}"
    echo -e "${COLOR_CYAN}2. Check platform overview: ${COLOR_BOLD}gok-new overview${COLOR_RESET}"
    echo -e "${COLOR_CYAN}3. Access component UIs using the URLs above${COLOR_RESET}"
    echo -e "${COLOR_CYAN}4. Deploy your first application: ${COLOR_BOLD}gok-new generate python-api my-app${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}📚 HELPFUL COMMANDS:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• View logs: ${COLOR_BOLD}gok-new logs <component>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Validate installation: ${COLOR_BOLD}gok-new validate <component>${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Get help: ${COLOR_BOLD}gok-new help${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Troubleshoot issues: ${COLOR_BOLD}gok-new diagnose${COLOR_RESET}"
    echo
}

# Show platform access information
show_platform_access_info() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🌐 PLATFORM ACCESS:${COLOR_RESET}"
    
    # Check which components are installed and show access info
    if is_component_installed "monitoring"; then
        echo -e "${COLOR_CYAN}📊 Grafana: https://grafana.${GOK_DOMAIN:-cluster.local}${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   Default credentials: admin / (check secret)${COLOR_RESET}"
    fi
    
    if is_component_installed "argocd"; then
        echo -e "${COLOR_CYAN}🚀 ArgoCD: https://argocd.${GOK_DOMAIN:-cluster.local}${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   Default credentials: admin / (check secret)${COLOR_RESET}"
    fi
    
    if is_component_installed "jupyter"; then
        echo -e "${COLOR_CYAN}📓 JupyterHub: https://jupyter.${GOK_DOMAIN:-cluster.local}${COLOR_RESET}"
    fi
    
    if is_component_installed "keycloak"; then
        echo -e "${COLOR_CYAN}🔐 Keycloak: https://keycloak.${GOK_DOMAIN:-cluster.local}/auth/admin${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}   Default credentials: admin / admin${COLOR_RESET}"
    fi
    
    echo
}

# Show component help
show_component_help() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📖 COMPONENT HELP${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}Available components and their purposes:${COLOR_RESET}"
    echo
    
    for category in "${!COMPONENT_CATEGORIES[@]}"; do
        echo -e "${COLOR_BRIGHT_YELLOW}$category:${COLOR_RESET}"
        local components=${COMPONENT_CATEGORIES[$category]}
        for component in $components; do
            local description="${GOK_MODULE_DESCRIPTIONS[$component]:-"Platform component"}"
            echo -e "${COLOR_CYAN}  • $component: $description${COLOR_RESET}"
        done
        echo
    done
    
    echo -e "${COLOR_BRIGHT_CYAN}Example usage:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Basic setup: kubernetes ingress cert-manager${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Development: kubernetes ingress cert-manager monitoring argocd${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Production: kubernetes cert-manager ingress vault keycloak monitoring${COLOR_RESET}"
}

# User input prompting utilities
promptUserInput(){
 MSG=$1
 DEFAULT=$2
id=$(python3 -c "
import sys
sys.stderr.write('${MSG}')
id=input()
print(id)
")
output=${id:-$DEFAULT}
echo $output
}

promptSecret(){
  MSG=$1
  secret=$(python3 -c "
import getpass
secret = getpass.getpass('${MSG}')
print(secret)
")
  printf '%s' "$secret"
}

# Export functions for use by other modules
export -f interactive_installation
export -f show_welcome_message
export -f show_installation_options
export -f get_installation_choice
export -f interactive_profile_installation
export -f interactive_custom_installation
export -f interactive_guided_installation
export -f interactive_quick_installation
export -f get_profile_choice
export -f guided_component_choice
export -f show_component_detailed_help
export -f validate_component_selection
export -f is_component_installed
export -f install_profile
export -f install_custom_components
export -f install_guided_components
export -f install_quick_components
export -f execute_component_installation
export -f install_single_component
export -f calculate_installation_time
export -f resolve_dependencies
export -f promptUserInput
export -f promptSecret