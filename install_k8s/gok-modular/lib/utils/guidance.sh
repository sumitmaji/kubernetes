#!/bin/bash
# =============================================================================
# GOK Modular Next-Steps Guidance System
# =============================================================================
# Provides intelligent component-specific recommendations and installation chains
# 
# Usage:
#   source lib/utils/guidance.sh
#   suggest_next_installations
#   suggest_and_install_next_module "kubernetes"
#   show_component_guidance "keycloak"
#   display_platform_overview
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
# COMPONENT INSTALLATION DEPENDENCIES AND RECOMMENDATIONS
# =============================================================================

# Define logical installation dependency chain
declare -A GOK_NEXT_MODULE_MAP
GOK_NEXT_MODULE_MAP["docker"]="kubernetes"
GOK_NEXT_MODULE_MAP["kubernetes"]="ingress"
GOK_NEXT_MODULE_MAP["ingress"]="cert-manager"
GOK_NEXT_MODULE_MAP["cert-manager"]="kyverno"
GOK_NEXT_MODULE_MAP["kyverno"]="registry"
GOK_NEXT_MODULE_MAP["registry"]="base"
GOK_NEXT_MODULE_MAP["base"]="ldap"
GOK_NEXT_MODULE_MAP["ldap"]="keycloak"
GOK_NEXT_MODULE_MAP["keycloak"]="oauth2"
GOK_NEXT_MODULE_MAP["oauth2"]="rabbitmq"
GOK_NEXT_MODULE_MAP["rabbitmq"]="vault"
GOK_NEXT_MODULE_MAP["vault"]="monitoring"
GOK_NEXT_MODULE_MAP["helm"]="kubernetes"
GOK_NEXT_MODULE_MAP["monitoring"]="argocd"
GOK_NEXT_MODULE_MAP["argocd"]="jenkins"
GOK_NEXT_MODULE_MAP["jenkins"]="jupyter"

# Define component descriptions
declare -A GOK_MODULE_DESCRIPTIONS
GOK_MODULE_DESCRIPTIONS["docker"]="Container runtime engine"
GOK_MODULE_DESCRIPTIONS["kubernetes"]="Container orchestration platform"
GOK_MODULE_DESCRIPTIONS["ingress"]="HTTP/HTTPS traffic routing and load balancing"
GOK_MODULE_DESCRIPTIONS["cert-manager"]="Automated TLS certificate management"
GOK_MODULE_DESCRIPTIONS["kyverno"]="Policy engine for Kubernetes security and governance"
GOK_MODULE_DESCRIPTIONS["registry"]="Container image registry for storing and managing images"
GOK_MODULE_DESCRIPTIONS["base"]="Core platform services and base infrastructure"
GOK_MODULE_DESCRIPTIONS["ldap"]="LDAP directory service for user and group management"
GOK_MODULE_DESCRIPTIONS["oauth2"]="Authentication proxy and SSO"
GOK_MODULE_DESCRIPTIONS["rabbitmq"]="Message broker for asynchronous communication"
GOK_MODULE_DESCRIPTIONS["vault"]="Secrets management and secure storage"
GOK_MODULE_DESCRIPTIONS["monitoring"]="Prometheus & Grafana observability stack"
GOK_MODULE_DESCRIPTIONS["keycloak"]="Identity and access management"
GOK_MODULE_DESCRIPTIONS["argocd"]="GitOps continuous delivery"
GOK_MODULE_DESCRIPTIONS["jenkins"]="CI/CD automation and pipeline management"
GOK_MODULE_DESCRIPTIONS["jupyter"]="Interactive data science and development"
GOK_MODULE_DESCRIPTIONS["dashboard"]="Kubernetes web-based management interface"

# Define component URLs and access information
declare -A GOK_COMPONENT_URLS
GOK_COMPONENT_URLS["keycloak"]="https://keycloak.${GOK_DOMAIN:-cluster.local}/auth/admin/"
GOK_COMPONENT_URLS["grafana"]="https://grafana.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["prometheus"]="https://prometheus.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["argocd"]="https://argocd.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["jenkins"]="https://jenkins.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["jupyter"]="https://jupyter.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["registry"]="https://registry.${GOK_DOMAIN:-cluster.local}/"
GOK_COMPONENT_URLS["vault"]="https://vault.${GOK_DOMAIN:-cluster.local}/"

# Define component default credentials
declare -A GOK_COMPONENT_CREDENTIALS
GOK_COMPONENT_CREDENTIALS["keycloak"]="admin / admin (change on first login)"
GOK_COMPONENT_CREDENTIALS["grafana"]="admin / prom-operator (or check secret: kubectl get secret -n monitoring grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
GOK_COMPONENT_CREDENTIALS["argocd"]="admin / (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
GOK_COMPONENT_CREDENTIALS["jenkins"]="admin / (check configmap: kubectl get secret -n jenkins jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d)"

# =============================================================================
# PLATFORM OVERVIEW AND STATUS DISPLAY
# =============================================================================

# Display comprehensive platform overview
display_platform_overview() {
    log_header "GOK Platform Overview" "Current Installation Status"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🏗️  PLATFORM COMPONENTS STATUS${COLOR_RESET}"
    echo
    
    # Core Infrastructure
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}Core Infrastructure:${COLOR_RESET}"
    check_and_display_component "kubernetes" "Kubernetes Cluster" "kubectl get nodes"
    check_and_display_component "cert-manager" "Certificate Manager" "kubectl get deployment cert-manager -n cert-manager"
    check_and_display_component "ingress" "NGINX Ingress" "kubectl get deployment ingress-nginx-controller -n ingress-nginx"
    check_and_display_component "monitoring" "Prometheus & Grafana" "kubectl get deployment prometheus-operator -n monitoring"
    echo
    
    # Security & Identity
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}Security & Identity:${COLOR_RESET}"
    check_and_display_component "vault" "HashiCorp Vault" "kubectl get statefulset vault -n vault"
    check_and_display_component "keycloak" "Keycloak" "kubectl get statefulset keycloak -n keycloak"
    check_and_display_component "oauth2" "OAuth2 Proxy" "kubectl get deployment oauth2-proxy -n oauth2-proxy"
    echo
    
    # Development & DevOps
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}Development & DevOps:${COLOR_RESET}"
    check_and_display_component "argocd" "ArgoCD" "kubectl get deployment argocd-server -n argocd"
    check_and_display_component "jenkins" "Jenkins" "kubectl get deployment jenkins -n jenkins"
    check_and_display_component "jupyter" "JupyterHub" "kubectl get deployment hub -n jupyterhub"
    check_and_display_component "registry" "Container Registry" "kubectl get deployment registry -n registry"
    echo
    
    # GOK Platform
    echo -e "${COLOR_YELLOW}${COLOR_BOLD}GOK Platform:${COLOR_RESET}"
    check_and_display_component "gok-controller" "GOK Controller" "kubectl get deployment gok-controller -n gok-system"
    check_and_display_component "gok-agent" "GOK Agent" "kubectl get daemonset gok-agent -n gok-system"
    echo
    
    # Provide recommendations
    suggest_next_installations
}

# Check if component is installed and display status
check_and_display_component() {
    local component="$1"
    local display_name="$2"
    local check_command="$3"
    
    if [[ -n "$check_command" ]]; then
        if eval "$check_command" >/dev/null 2>&1; then
            echo -e "  ${EMOJI_SUCCESS:-✅} ${COLOR_GREEN}$display_name${COLOR_RESET}"
            
            # Show additional info if component has URL
            if [[ -n "${GOK_COMPONENT_URLS[$component]}" ]]; then
                echo -e "    ${COLOR_CYAN}🌐 ${GOK_COMPONENT_URLS[$component]}${COLOR_RESET}"
            fi
            
            # Show credentials if available
            if [[ -n "${GOK_COMPONENT_CREDENTIALS[$component]}" ]]; then
                echo -e "    ${COLOR_YELLOW}🔑 ${GOK_COMPONENT_CREDENTIALS[$component]}${COLOR_RESET}"
            fi
        else
            echo -e "  ${EMOJI_CROSS:-❌} ${COLOR_DIM}$display_name${COLOR_RESET}"
        fi
    else
        # Fallback to simple name-based check
        if kubectl get deployment "$component" >/dev/null 2>&1 || kubectl get statefulset "$component" >/dev/null 2>&1; then
            echo -e "  ${EMOJI_SUCCESS:-✅} ${COLOR_GREEN}$display_name${COLOR_RESET}"
        else
            echo -e "  ${EMOJI_CROSS:-❌} ${COLOR_DIM}$display_name${COLOR_RESET}"
        fi
    fi
}

# =============================================================================
# INTELLIGENT NEXT-STEPS SUGGESTIONS
# =============================================================================

# Suggest next installations based on current platform state
suggest_next_installations() {
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}💡 SUGGESTED NEXT STEPS${COLOR_RESET}"
    echo
    
    local suggestions_made=false
    
    # Check infrastructure prerequisites first
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo -e "${COLOR_CYAN}🏗️  ${COLOR_BOLD}Set up Kubernetes cluster first:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install Kubernetes: ${COLOR_BOLD}gok-new install kubernetes${COLOR_RESET}"
        suggestions_made=true
    else
        # Check for basic infrastructure components
        if ! kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}🔒 ${COLOR_BOLD}Set up certificate management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install cert-manager: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["cert-manager"]}${COLOR_RESET}"
            suggestions_made=true
        fi
        
        if ! kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}🌐 ${COLOR_BOLD}Set up traffic routing:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install ingress controller: ${COLOR_BOLD}gok-new install ingress${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["ingress"]}${COLOR_RESET}"
            suggestions_made=true
        fi
        
        if ! kubectl get deployment prometheus-operator -n monitoring >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}📊 ${COLOR_BOLD}Set up monitoring:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install monitoring stack: ${COLOR_BOLD}gok-new install monitoring${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["monitoring"]}${COLOR_RESET}"
            suggestions_made=true
        fi
        
        if ! kubectl get statefulset vault -n vault >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}🔐 ${COLOR_BOLD}Set up secrets management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install HashiCorp Vault: ${COLOR_BOLD}gok-new install vault${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["vault"]}${COLOR_RESET}"
            suggestions_made=true
        fi
        
        if ! kubectl get statefulset keycloak -n keycloak >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}👤 ${COLOR_BOLD}Set up identity management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install Keycloak: ${COLOR_BOLD}gok-new install keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["keycloak"]}${COLOR_RESET}"
            suggestions_made=true
        fi
        
        # Advanced components suggestions
        if kubectl get statefulset keycloak -n keycloak >/dev/null 2>&1 && ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
            echo -e "${COLOR_CYAN}🚀 ${COLOR_BOLD}Set up GitOps deployment:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install ArgoCD: ${COLOR_BOLD}gok-new install argocd${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • ${GOK_MODULE_DESCRIPTIONS["argocd"]}${COLOR_RESET}"
            suggestions_made=true
        fi
    fi
    
    # Always show general options
    if [[ "$suggestions_made" == "false" ]]; then
        echo -e "${COLOR_GREEN}🎉 ${COLOR_BOLD}Core platform components are ready!${COLOR_RESET}"
        echo
        echo -e "${COLOR_CYAN}🛠️  ${COLOR_BOLD}Development tools:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install JupyterHub: ${COLOR_BOLD}gok-new install jupyter${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install Jenkins: ${COLOR_BOLD}gok-new install jenkins${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install Registry: ${COLOR_BOLD}gok-new install registry${COLOR_RESET}"
    fi
    
    echo
    echo -e "${COLOR_CYAN}📋 ${COLOR_BOLD}Management commands:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   • Generate microservice: ${COLOR_BOLD}gok-new generate python-api my-service${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   • Check platform status: ${COLOR_BOLD}gok-new status${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   • View logs: ${COLOR_BOLD}gok-new logs <component>${COLOR_RESET}"
    echo
}

# =============================================================================
# COMPONENT-SPECIFIC POST-INSTALLATION GUIDANCE
# =============================================================================

# Suggest and optionally install the next recommended module after successful installation
suggest_and_install_next_module() {
    local current_component="$1"
    local auto_install="${2:-false}"  # Optional parameter for auto-installation
    
    # Get the next recommended module
    local next_module="${GOK_NEXT_MODULE_MAP[$current_component]}"
    
    if [[ -z "$next_module" ]]; then
        # No specific next module defined, show general suggestions
        log_info "🎉 $current_component installation completed successfully!"
        echo
        suggest_next_installations
        return 0
    fi
    
    # Check if the next module is already installed
    local is_installed=false
    case "$next_module" in
        "kubernetes")
            kubectl get nodes >/dev/null 2>&1 && is_installed=true
            ;;
        "ingress")
            kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1 && is_installed=true
            ;;
        "cert-manager")
            kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1 && is_installed=true
            ;;
        "kyverno")
            kubectl get deployment kyverno -n kyverno >/dev/null 2>&1 && is_installed=true
            ;;
        "registry")
            kubectl get deployment registry -n registry >/dev/null 2>&1 && is_installed=true
            ;;
        "monitoring")
            kubectl get deployment prometheus-operator -n monitoring >/dev/null 2>&1 && is_installed=true
            ;;
        "vault")
            kubectl get statefulset vault -n vault >/dev/null 2>&1 && is_installed=true
            ;;
        "keycloak")
            kubectl get statefulset keycloak -n keycloak >/dev/null 2>&1 && is_installed=true
            ;;
        "argocd")
            kubectl get deployment argocd-server -n argocd >/dev/null 2>&1 && is_installed=true
            ;;
        *)
            kubectl get deployment "$next_module" >/dev/null 2>&1 && is_installed=true
            ;;
    esac
    
    if [[ "$is_installed" == "true" ]]; then
        log_success "$current_component ✅ installed successfully!"
        log_info "$next_module is already installed - continuing with platform setup"
        
        # Show component-specific guidance
        show_component_guidance "$current_component"
        return 0
    fi
    
    # Show next module recommendation
    log_success "$current_component ✅ installed successfully!"
    echo
    echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🎯 RECOMMENDED NEXT STEP${COLOR_RESET}"
    echo
    echo -e "${COLOR_CYAN}📦 ${COLOR_BOLD}Install $next_module:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   Description: ${GOK_MODULE_DESCRIPTIONS[$next_module]:-"Platform component"}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}   Command: ${COLOR_BOLD}gok-new install $next_module${COLOR_RESET}"
    echo
    
    # Auto-install if requested
    if [[ "$auto_install" == "true" ]]; then
        echo -e "${COLOR_YELLOW}🚀 Auto-installing next module: $next_module${COLOR_RESET}"
        if command -v gok-new >/dev/null 2>&1; then
            gok-new install "$next_module"
        else
            log_warning "gok-new command not found for auto-installation"
        fi
    else
        # Interactive prompt for installation
        echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}💡 QUICK ACTIONS:${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install now: ${COLOR_BOLD}gok-new install $next_module${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • View platform status: ${COLOR_BOLD}gok-new status${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Check component summary: ${COLOR_BOLD}gok-new ${current_component} summary${COLOR_RESET}"
        echo -e "${COLOR_CYAN}   • Install different component: ${COLOR_BOLD}gok-new install help${COLOR_RESET}"
    fi
    
    # Show component-specific guidance
    show_component_guidance "$current_component"
    echo
}

# Show component-specific post-installation guidance
show_component_guidance() {
    local component="$1"
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📋 $component POST-INSTALLATION GUIDANCE${COLOR_RESET}"
    echo
    
    case "$component" in
        "kubernetes")
            echo -e "${COLOR_GREEN}✓ Kubernetes cluster is ready${COLOR_RESET}"
            echo -e "${COLOR_CYAN}📝 Next steps:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Verify nodes: ${COLOR_BOLD}kubectl get nodes${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Install ingress: ${COLOR_BOLD}gok-new install ingress${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Set up certificates: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            ;;
        "ingress")
            echo -e "${COLOR_GREEN}✓ NGINX Ingress Controller is ready${COLOR_RESET}"
            echo -e "${COLOR_CYAN}📝 Configuration:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Service type: $(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.type}' 2>/dev/null || echo 'N/A')${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check status: ${COLOR_BOLD}kubectl get pods -n ingress-nginx${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View logs: ${COLOR_BOLD}kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx${COLOR_RESET}"
            ;;
        "cert-manager")
            echo -e "${COLOR_GREEN}✓ Certificate Manager is ready${COLOR_RESET}"
            echo -e "${COLOR_CYAN}📝 Certificate management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check issuers: ${COLOR_BOLD}kubectl get clusterissuers${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View certificates: ${COLOR_BOLD}kubectl get certificates -A${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check cert-manager logs: ${COLOR_BOLD}kubectl logs -n cert-manager -l app=cert-manager${COLOR_RESET}"
            ;;
        "monitoring")
            echo -e "${COLOR_GREEN}✓ Monitoring stack (Prometheus & Grafana) is ready${COLOR_RESET}"
            if [[ -n "${GOK_COMPONENT_URLS["grafana"]}" ]]; then
                echo -e "${COLOR_CYAN}🌐 Grafana URL: ${COLOR_BOLD}${GOK_COMPONENT_URLS["grafana"]}${COLOR_RESET}"
                echo -e "${COLOR_CYAN}🌐 Prometheus URL: ${COLOR_BOLD}${GOK_COMPONENT_URLS["prometheus"]}${COLOR_RESET}"
            fi
            if [[ -n "${GOK_COMPONENT_CREDENTIALS["grafana"]}" ]]; then
                echo -e "${COLOR_YELLOW}🔑 Credentials: ${GOK_COMPONENT_CREDENTIALS["grafana"]}${COLOR_RESET}"
            fi
            echo -e "${COLOR_CYAN}📝 Monitoring commands:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check pods: ${COLOR_BOLD}kubectl get pods -n monitoring${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View services: ${COLOR_BOLD}kubectl get svc -n monitoring${COLOR_RESET}"
            ;;
        "keycloak")
            echo -e "${COLOR_GREEN}✓ Keycloak Identity Management is ready${COLOR_RESET}"
            if [[ -n "${GOK_COMPONENT_URLS["keycloak"]}" ]]; then
                echo -e "${COLOR_CYAN}🌐 Admin Console: ${COLOR_BOLD}${GOK_COMPONENT_URLS["keycloak"]}${COLOR_RESET}"
            fi
            if [[ -n "${GOK_COMPONENT_CREDENTIALS["keycloak"]}" ]]; then
                echo -e "${COLOR_YELLOW}🔑 Default credentials: ${GOK_COMPONENT_CREDENTIALS["keycloak"]}${COLOR_RESET}"
            fi
            echo -e "${COLOR_CYAN}📝 Identity management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check Keycloak pods: ${COLOR_BOLD}kubectl get pods -n keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View service: ${COLOR_BOLD}kubectl get svc -n keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Access admin console and change default password${COLOR_RESET}"
            ;;
        "vault")
            echo -e "${COLOR_GREEN}✓ HashiCorp Vault is ready${COLOR_RESET}"
            if [[ -n "${GOK_COMPONENT_URLS["vault"]}" ]]; then
                echo -e "${COLOR_CYAN}🌐 Vault UI: ${COLOR_BOLD}${GOK_COMPONENT_URLS["vault"]}${COLOR_RESET}"
            fi
            echo -e "${COLOR_CYAN}📝 Vault management:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check Vault status: ${COLOR_BOLD}kubectl exec -n vault vault-0 -- vault status${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Initialize Vault: Follow the unseal process${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View pods: ${COLOR_BOLD}kubectl get pods -n vault${COLOR_RESET}"
            ;;
        "argocd")
            echo -e "${COLOR_GREEN}✓ ArgoCD GitOps Platform is ready${COLOR_RESET}"
            if [[ -n "${GOK_COMPONENT_URLS["argocd"]}" ]]; then
                echo -e "${COLOR_CYAN}🌐 ArgoCD UI: ${COLOR_BOLD}${GOK_COMPONENT_URLS["argocd"]}${COLOR_RESET}"
            fi
            if [[ -n "${GOK_COMPONENT_CREDENTIALS["argocd"]}" ]]; then
                echo -e "${COLOR_YELLOW}🔑 Credentials: ${GOK_COMPONENT_CREDENTIALS["argocd"]}${COLOR_RESET}"
            fi
            echo -e "${COLOR_CYAN}📝 GitOps workflow:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check ArgoCD pods: ${COLOR_BOLD}kubectl get pods -n argocd${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Connect Git repository for automated deployments${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_GREEN}✓ $component installation completed${COLOR_RESET}"
            echo -e "${COLOR_CYAN}📝 General verification:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check pods: ${COLOR_BOLD}kubectl get pods -l app=$component${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • View services: ${COLOR_BOLD}kubectl get svc -l app=$component${COLOR_RESET}"
            echo -e "${COLOR_CYAN}   • Check logs: ${COLOR_BOLD}kubectl logs -l app=$component${COLOR_RESET}"
            ;;
    esac
    
    echo
}

# =============================================================================
# GUIDED INSTALLATION RECOMMENDATIONS
# =============================================================================

# Provide installation path recommendations based on use case
recommend_installation_path() {
    local use_case="${1:-general}"
    
    log_header "Installation Path Recommendation" "$use_case Use Case"
    
    case "$use_case" in
        "development"|"dev")
            echo -e "${COLOR_BRIGHT_CYAN}🛠️  DEVELOPMENT PLATFORM SETUP${COLOR_RESET}"
            echo
            echo -e "${COLOR_YELLOW}Recommended installation order:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}1. Kubernetes cluster: ${COLOR_BOLD}gok-new install kubernetes${COLOR_RESET}"
            echo -e "${COLOR_CYAN}2. Ingress controller: ${COLOR_BOLD}gok-new install ingress${COLOR_RESET}"
            echo -e "${COLOR_CYAN}3. Certificate manager: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}4. Container registry: ${COLOR_BOLD}gok-new install registry${COLOR_RESET}"
            echo -e "${COLOR_CYAN}5. Monitoring stack: ${COLOR_BOLD}gok-new install monitoring${COLOR_RESET}"
            echo -e "${COLOR_CYAN}6. ArgoCD GitOps: ${COLOR_BOLD}gok-new install argocd${COLOR_RESET}"
            echo -e "${COLOR_CYAN}7. JupyterHub: ${COLOR_BOLD}gok-new install jupyter${COLOR_RESET}"
            ;;
        "production"|"prod")
            echo -e "${COLOR_BRIGHT_RED}🏭 PRODUCTION PLATFORM SETUP${COLOR_RESET}"
            echo
            echo -e "${COLOR_YELLOW}Recommended installation order:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}1. Kubernetes cluster: ${COLOR_BOLD}gok-new install kubernetes${COLOR_RESET}"
            echo -e "${COLOR_CYAN}2. Certificate manager: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}3. Ingress controller: ${COLOR_BOLD}gok-new install ingress${COLOR_RESET}"
            echo -e "${COLOR_CYAN}4. HashiCorp Vault: ${COLOR_BOLD}gok-new install vault${COLOR_RESET}"
            echo -e "${COLOR_CYAN}5. Monitoring stack: ${COLOR_BOLD}gok-new install monitoring${COLOR_RESET}"
            echo -e "${COLOR_CYAN}6. Identity management: ${COLOR_BOLD}gok-new install keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}7. Policy engine: ${COLOR_BOLD}gok-new install kyverno${COLOR_RESET}"
            echo -e "${COLOR_CYAN}8. ArgoCD GitOps: ${COLOR_BOLD}gok-new install argocd${COLOR_RESET}"
            ;;
        "security"|"sec")
            echo -e "${COLOR_BRIGHT_YELLOW}🔐 SECURITY-FOCUSED SETUP${COLOR_RESET}"
            echo
            echo -e "${COLOR_YELLOW}Recommended installation order:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}1. Kubernetes cluster: ${COLOR_BOLD}gok-new install kubernetes${COLOR_RESET}"
            echo -e "${COLOR_CYAN}2. Certificate manager: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}3. HashiCorp Vault: ${COLOR_BOLD}gok-new install vault${COLOR_RESET}"
            echo -e "${COLOR_CYAN}4. Policy engine: ${COLOR_BOLD}gok-new install kyverno${COLOR_RESET}"
            echo -e "${COLOR_CYAN}5. Identity management: ${COLOR_BOLD}gok-new install keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}6. OAuth2 proxy: ${COLOR_BOLD}gok-new install oauth2${COLOR_RESET}"
            echo -e "${COLOR_CYAN}7. Monitoring stack: ${COLOR_BOLD}gok-new install monitoring${COLOR_RESET}"
            ;;
        *)
            echo -e "${COLOR_BRIGHT_GREEN}🏗️  GENERAL PLATFORM SETUP${COLOR_RESET}"
            echo
            echo -e "${COLOR_YELLOW}Recommended installation order:${COLOR_RESET}"
            echo -e "${COLOR_CYAN}1. Kubernetes cluster: ${COLOR_BOLD}gok-new install kubernetes${COLOR_RESET}"
            echo -e "${COLOR_CYAN}2. Ingress controller: ${COLOR_BOLD}gok-new install ingress${COLOR_RESET}"
            echo -e "${COLOR_CYAN}3. Certificate manager: ${COLOR_BOLD}gok-new install cert-manager${COLOR_RESET}"
            echo -e "${COLOR_CYAN}4. Monitoring stack: ${COLOR_BOLD}gok-new install monitoring${COLOR_RESET}"
            echo -e "${COLOR_CYAN}5. Identity management: ${COLOR_BOLD}gok-new install keycloak${COLOR_RESET}"
            echo -e "${COLOR_CYAN}6. Container registry: ${COLOR_BOLD}gok-new install registry${COLOR_RESET}"
            echo -e "${COLOR_CYAN}7. ArgoCD GitOps: ${COLOR_BOLD}gok-new install argocd${COLOR_RESET}"
            ;;
    esac
    
    echo
    echo -e "${COLOR_BRIGHT_CYAN}💡 USAGE TIPS:${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Install components in the recommended order for optimal compatibility${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Use ${COLOR_BOLD}gok-new status${COLOR_RESET} to check platform state between installations${COLOR_RESET}"
    echo -e "${COLOR_CYAN}• Run ${COLOR_BOLD}gok-new validate <component>${COLOR_RESET} after each installation${COLOR_RESET}"
    echo
}

# Show component-specific next steps after successful installation
show_component_next_steps() {
    local component="$1"
    
    case "$component" in
        "docker")
            log_next_steps "Docker Engine" \
                "Verify Docker: docker --version && docker info" \
                "Test container: docker run hello-world" \
                "Configure user permissions: sudo usermod -aG docker $USER" \
                "Next: Install Kubernetes: gok install kubernetes"
            
            log_info "Docker is ready for container operations"
            ;;
            
        "kubernetes"|"k8s")
            log_next_steps "Kubernetes Cluster" \
                "Check cluster: kubectl get nodes" \
                "Verify system pods: kubectl get pods -n kube-system" \
                "Deploy test workload: kubectl create deployment nginx --image=nginx" \
                "Next: Install ingress controller: gok install ingress"
            
            log_info "Kubernetes cluster is operational and ready for workloads"
            ;;
            
        "ingress"|"nginx-ingress")
            log_next_steps "NGINX Ingress Controller" \
                "Check ingress: kubectl get pods -n ingress-nginx" \
                "Verify service: kubectl get svc -n ingress-nginx" \
                "Test external access to cluster services" \
                "Next: Install certificate manager: gok install cert-manager"
            
            log_urls "Ingress Configuration" \
                "Default Backend: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30080" \
                "HTTPS: https://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30443"
            
            log_info "Ingress controller enables external HTTP/HTTPS access to cluster services"
            ;;
            
        "cert-manager")
            log_next_steps "Certificate Manager" \
                "Check cert-manager: kubectl get pods -n cert-manager" \
                "Verify CRDs: kubectl get crd | grep cert-manager" \
                "Create test certificate issuer" \
                "Configure Let's Encrypt for automatic certificates"
            
            log_info "Cert-manager provides automated TLS certificate management"
            ;;
            
        "kyverno")
            log_next_steps "Kyverno Policy Engine" \
                "Check Kyverno: kubectl get pods -n kyverno" \
                "Review policies: kubectl get policies -A" \
                "Test policy enforcement with sample resources" \
                "Configure custom security policies"
            
            log_info "Kyverno enforces security policies and governance across the cluster"
            ;;
            
        "registry"|"docker-registry")
            log_next_steps "Container Registry" \
                "Check registry: kubectl get pods -n registry" \
                "Configure Docker to use registry" \
                "Push test image: docker push registry.$(rootDomain)/hello:latest" \
                "Set up registry webhooks and scanning"
            
            log_urls "Registry Access" \
                "Registry UI: https://registry.$(rootDomain)" \
                "Registry API: https://registry.$(rootDomain)/v2/"
            
            log_info "Private container registry is ready for image storage and distribution"
            ;;
            
        "base"|"base-services")
            log_next_steps "Base Platform Services" \
                "Verify core services: kubectl get pods -n kube-system" \
                "Check platform configurations" \
                "Test shared service connectivity" \
                "Next: Install LDAP: gok install ldap"
            
            log_info "Base platform services and shared infrastructure are configured"
            ;;
            
        "ldap"|"openldap")
            log_next_steps "LDAP Directory Service" \
                "Check LDAP: kubectl get pods -n ldap" \
                "Verify LDAP service: kubectl get svc -n ldap" \
                "Test LDAP connectivity: ldapsearch -x -H ldap://ldap.$(rootDomain)" \
                "Configure user and group entries"
            
            log_urls "LDAP Access" \
                "LDAP Server: ldap://ldap.$(rootDomain):389" \
                "LDAP Admin: cn=admin,dc=$(rootDomain | sed 's/\..*$//')"
            
            log_credentials "LDAP Admin" "admin" \
                "Run: kubectl get secret -n ldap ldap-admin-password -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "LDAP directory service provides centralized user and group management"
            ;;
            
        "oauth2"|"oauth2-proxy")
            log_next_steps "OAuth2 Authentication Proxy" \
                "Check OAuth2 proxy: kubectl get pods -n oauth2" \
                "Test SSO integration with LDAP" \
                "Configure application protection policies" \
                "Verify authentication flow"
            
            log_urls "OAuth2 Configuration" \
                "OAuth2 Proxy: https://oauth2.$(rootDomain)" \
                "Authentication Endpoint: https://oauth2.$(rootDomain)/oauth2/auth"
            
            log_info "OAuth2 proxy provides SSO and application security"
            ;;
            
        "rabbitmq"|"message-queue")
            log_next_steps "RabbitMQ Message Broker" \
                "Check RabbitMQ: kubectl get pods -n rabbitmq" \
                "Access management UI" \
                "Create queues and exchanges" \
                "Configure clustering and high availability"
            
            log_urls "RabbitMQ Access" \
                "Management UI: https://rabbitmq.$(rootDomain)" \
                "AMQP Endpoint: amqp://rabbitmq.$(rootDomain):5672"
            
            log_credentials "RabbitMQ Admin" "admin" \
                "Run: kubectl get secret -n rabbitmq rabbitmq-admin-password -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "RabbitMQ provides reliable message queuing for distributed applications"
            ;;
            
        "jenkins")
            log_next_steps "Jenkins CI/CD" \
                "Access Jenkins dashboard" \
                "Install required plugins" \
                "Configure build agents and pipelines" \
                "Set up Git integration and webhooks"
            
            log_urls "Jenkins Access" \
                "Jenkins UI: https://jenkins.$(rootDomain)" \
                "Build Agents: Configure in Jenkins > Manage Jenkins > Manage Nodes"
            
            log_credentials "Jenkins Admin" "admin" \
                "Run: kubectl get secret -n jenkins jenkins-admin-password -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "Jenkins is configured for continuous integration and deployment"
            ;;
            
        "monitoring"|"prometheus"|"grafana")
            log_next_steps "Monitoring Stack" \
                "Access Grafana dashboards" \
                "Configure Prometheus targets" \
                "Set up alerting rules" \
                "Configure alerting rules"
            
            log_urls "Monitoring Dashboards" \
                "Grafana: https://grafana.$(rootDomain)" \
                "Prometheus: https://prometheus.$(rootDomain)" \
                "AlertManager: https://alertmanager.$(rootDomain)"
            
            log_credentials "Grafana" "admin" \
                "Run: kubectl get secret -n monitoring grafana-admin-password -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "Pre-configured dashboards: Kubernetes cluster, node metrics, pod metrics"
            ;;
            
        "vault")
            log_next_steps "HashiCorp Vault" \
                "Check vault status: kubectl get pods -n vault" \
                "Initialize vault: kubectl exec -n vault vault-0 -- vault operator init" \
                "Unseal vault with generated keys" \
                "Configure authentication methods" \
                "Set up secret engines and policies"
            
            log_urls "Vault Access" \
                "Vault UI: https://$(fullVaultUrl)" \
                "Vault API: https://$(fullVaultUrl)/v1/"
            
            log_warning "IMPORTANT: Save vault unseal keys and root token securely!"
            log_info "Vault is running in HA mode with auto-unseal configured"
            ;;
            
        "keycloak")
            log_next_steps "Keycloak Identity Management" \
                "Access Keycloak admin console" \
                "Create realms and clients" \
                "Configure user federation (LDAP if needed)" \
                "Set up OAuth2 integration: gok install oauth2"
            
            log_urls "Keycloak Access" \
                "Admin Console: https://$(fullKeycloakUrl)/admin" \
                "Account Console: https://$(fullKeycloakUrl)/realms/master/account"
            
            log_credentials "Keycloak Admin" "admin" \
                "Run: kubectl get secret -n keycloak keycloak-admin-password -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "Default realm 'master' created. Create application-specific realms as needed."
            ;;
            
        "argocd")
            log_next_steps "ArgoCD GitOps" \
                "Access ArgoCD UI" \
                "Connect Git repositories" \
                "Create applications and sync policies" \
                "Set up RBAC and SSO integration"
            
            log_urls "ArgoCD Access" \
                "ArgoCD UI: https://argocd.$(rootDomain)" \
                "ArgoCD CLI: argocd login argocd.$(rootDomain)"
            
            log_credentials "ArgoCD Admin" "admin" \
                "Run: kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
            
            log_info "ArgoCD is configured for GitOps deployment workflows"
            ;;
            
        "jupyter")
            log_next_steps "JupyterHub Development Environment" \
                "Access JupyterHub" \
                "Configure user authentication" \
                "Install additional Python packages" \
                "Create shared notebooks and datasets"
            
            log_urls "JupyterHub Access" \
                "JupyterHub: https://jupyter.$(rootDomain)" \
                "Admin Panel: https://jupyter.$(rootDomain)/hub/admin"
            
            log_info "Default spawner configured with data science libraries pre-installed"
            ;;
            
        "registry")
            log_next_steps "Container Registry" \
                "Configure Docker daemon to use registry" \
                "Push first image: docker push $(fullRegistryUrl)/my-app:latest" \
                "Set up image scanning and policies" \
                "Configure registry webhooks"
            
            log_urls "Registry Access" \
                "Registry UI: https://$(fullRegistryUrl)" \
                "Registry API: https://$(fullRegistryUrl)/v2/"
            
            log_info "Registry is configured with TLS and basic authentication"
            ;;
            
        "gok-controller"|"controller")
            log_next_steps "GOK Platform Services" \
                "Verify controller: kubectl get pods -n gok-controller" \
                "Check agent: kubectl get pods -n gok-agent" \
                "Test command execution through web interface" \
                "Configure authentication and authorization"
            
            log_urls "GOK Platform Access" \
                "GOK Controller: https://gok-controller.$(rootDomain)" \
                "GOK Agent: Internal service for command execution"
            
            log_info "GOK distributed command execution platform is ready"
            ;;
            
        "istio")
            log_next_steps "Istio Service Mesh" \
                "Enable automatic sidecar injection for namespaces" \
                "Deploy sample applications with Istio" \
                "Configure traffic management and security policies" \
                "Set up observability with Kiali and Jaeger"
            
            log_info "Istio service mesh is installed and ready for microservices"
            ;;
            
        "haproxy"|"ha-proxy"|"load-balancer")
            log_next_steps "HA Proxy Load Balancer" \
                "Check proxy status: docker ps | grep master-proxy" \
                "View proxy logs: docker logs master-proxy" \
                "Test connectivity: curl -k https://localhost:$HA_PROXY_PORT/healthz" \
                "Install Kubernetes masters using HA endpoint" \
                "Configure kubectl to use HA endpoint: https://localhost:$HA_PROXY_PORT"
            
            log_urls "HA Proxy Access Points" \
                "Load Balancer Endpoint: https://localhost:$HA_PROXY_PORT" \
                "HAProxy Stats: http://localhost:$HA_PROXY_PORT/stats (if enabled)" \
                "Configuration File: /opt/haproxy.cfg"
            
            log_credentials "HA Proxy Management" "docker" \
                "Container name: master-proxy" \
                "Restart: docker restart master-proxy" \
                "Stop: docker stop master-proxy"
            
            log_info "HA proxy is now load balancing across $(($(echo "$API_SERVERS" | tr ',' '\n' | wc -l))) Kubernetes API servers"
            
            log_troubleshooting "HA Proxy" \
                "Check container logs: docker logs master-proxy" \
                "Verify port availability: netstat -tlnp | grep $HA_PROXY_PORT" \
                "Test backend connectivity: nc -z <backend-ip> 6443" \
                "Validate configuration: docker exec master-proxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg" \
                "Restart proxy: docker restart master-proxy"
            
            echo
            log_header "Kubernetes Installation with HA" "Ready for Multi-Master Setup"
            
            echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Your HA proxy is ready! Next steps:${COLOR_RESET}"
            echo
            echo -e "${COLOR_CYAN}1. ${COLOR_BOLD}Install first Kubernetes master:${COLOR_RESET}"
            echo -e "   ${COLOR_DIM}Use the HA proxy endpoint for --control-plane-endpoint${COLOR_RESET}"
            echo
            echo -e "${COLOR_CYAN}2. ${COLOR_BOLD}Join additional masters:${COLOR_RESET}"
            echo -e "   ${COLOR_DIM}Each additional master will connect through the HA proxy${COLOR_RESET}"
            echo
            echo -e "${COLOR_CYAN}3. ${COLOR_BOLD}Configure kubectl:${COLOR_RESET}"
            echo -e "   ${COLOR_DIM}Point kubectl to https://localhost:$HA_PROXY_PORT${COLOR_RESET}"
            echo
            ;;
            
        *)
            log_next_steps "$component Installation Complete" \
                "Check component status: kubectl get pods -A | grep $component" \
                "Review component logs: kubectl logs -l app=$component" \
                "Verify service endpoints: kubectl get svc | grep $component" \
                "Check ingress configuration: kubectl get ingress"
            
            log_info "Component $component has been installed successfully"
            ;;
    esac
}

# Export functions for use by other modules
export -f display_platform_overview
export -f check_and_display_component
export -f suggest_next_installations
export -f suggest_and_install_next_module
export -f show_component_guidance
export -f recommend_installation_path
export -f show_component_next_steps