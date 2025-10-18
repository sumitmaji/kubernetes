#!/bin/bash

# GOK Next Command Module - Suggest and install next recommended component

# Main next command handler
nextCmd() {
    local component="$1"
    
    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_next_help
        return 0
    fi
    
    # Show next recommended module
    suggest_and_install_next_module "$component"
}

# Suggest and install next module based on current component
suggest_and_install_next_module() {
    local current_component="$1"
    local auto_install="${2:-false}"  # Optional parameter for auto-installation
    
    # Define the logical installation dependency chain
    declare -A NEXT_MODULE_MAP
    NEXT_MODULE_MAP["docker"]="kubernetes"
    NEXT_MODULE_MAP["kubernetes"]="helm"
    NEXT_MODULE_MAP["helm"]="ingress"
    NEXT_MODULE_MAP["ingress"]="cert-manager"
    NEXT_MODULE_MAP["cert-manager"]="kyverno"
    NEXT_MODULE_MAP["kyverno"]="registry"
    NEXT_MODULE_MAP["registry"]="base"
    NEXT_MODULE_MAP["base"]="ldap"
    NEXT_MODULE_MAP["ldap"]="keycloak"
    NEXT_MODULE_MAP["keycloak"]="oauth2"
    NEXT_MODULE_MAP["oauth2"]="gok-login"
    NEXT_MODULE_MAP["gok-login"]="rabbitmq"
    NEXT_MODULE_MAP["rabbitmq"]="vault"
    NEXT_MODULE_MAP["vault"]="monitoring"
    NEXT_MODULE_MAP["monitoring"]="argocd"
    NEXT_MODULE_MAP["argocd"]="gok-agent"
    NEXT_MODULE_MAP["gok-agent"]="gok-controller"
    NEXT_MODULE_MAP["gok-controller"]="che"
    NEXT_MODULE_MAP["che"]="workspace"
    
    # Define component descriptions
    declare -A MODULE_DESCRIPTIONS
    MODULE_DESCRIPTIONS["docker"]="Container runtime engine"
    MODULE_DESCRIPTIONS["kubernetes"]="Container orchestration platform"
    MODULE_DESCRIPTIONS["helm"]="Kubernetes package manager"
    MODULE_DESCRIPTIONS["ingress"]="HTTP/HTTPS traffic routing and load balancing"
    MODULE_DESCRIPTIONS["cert-manager"]="Automated TLS certificate management"
    MODULE_DESCRIPTIONS["kyverno"]="Policy engine for Kubernetes security and governance"
    MODULE_DESCRIPTIONS["registry"]="Container image registry for storing and managing images"
    MODULE_DESCRIPTIONS["base"]="Core platform services and base infrastructure"
    MODULE_DESCRIPTIONS["ldap"]="LDAP directory service for user and group management"
    MODULE_DESCRIPTIONS["keycloak"]="Identity and access management"
    MODULE_DESCRIPTIONS["oauth2"]="Authentication proxy and SSO"
    MODULE_DESCRIPTIONS["gok-login"]="GOK authentication service"
    MODULE_DESCRIPTIONS["rabbitmq"]="Message broker for asynchronous communication"
    MODULE_DESCRIPTIONS["vault"]="Secrets management and secure storage"
    MODULE_DESCRIPTIONS["monitoring"]="Prometheus & Grafana observability stack"
    MODULE_DESCRIPTIONS["argocd"]="GitOps continuous delivery"
    MODULE_DESCRIPTIONS["gok-agent"]="GOK distributed system agent"
    MODULE_DESCRIPTIONS["gok-controller"]="GOK distributed system controller"
    MODULE_DESCRIPTIONS["che"]="Eclipse Che cloud-based IDE"
    MODULE_DESCRIPTIONS["workspace"]="DevWorkspace for cloud development"
    MODULE_DESCRIPTIONS["jenkins"]="CI/CD automation and pipeline management"
    MODULE_DESCRIPTIONS["jupyter"]="Interactive data science and development"
    MODULE_DESCRIPTIONS["dashboard"]="Kubernetes web-based management interface"
    MODULE_DESCRIPTIONS["istio"]="Service mesh for microservices"
    MODULE_DESCRIPTIONS["fluentd"]="Log collection and aggregation"
    MODULE_DESCRIPTIONS["opensearch"]="Search and analytics engine"
    
    # Get the next recommended module
    local next_module="${NEXT_MODULE_MAP[$current_component]}"
    
    if [[ -z "$next_module" ]]; then
        # No specific next module defined, show general suggestions
        log_success "🎉 $current_component installation completed successfully!"
        echo ""
        show_general_next_suggestions
        return 0
    fi
    
    # Check if the next module is already installed
    local is_installed=$(check_component_installed "$next_module")
    
    echo ""
    log_header "Next Recommended Installation" "Suggested Module: $next_module"
    
    if [[ "$is_installed" == "true" ]]; then
        log_success "✓ $next_module is already installed"
        echo -e "  ${COLOR_DIM}${MODULE_DESCRIPTIONS[$next_module]}${COLOR_RESET}"
        echo ""
        # Recursively suggest the next module after this one
        suggest_and_install_next_module "$next_module" "$auto_install"
        return 0
    fi
    
    # Show the recommendation
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🎯 Recommended Next Step:${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_CYAN}Module:${COLOR_RESET} ${COLOR_BOLD}$next_module${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Purpose:${COLOR_RESET} ${MODULE_DESCRIPTIONS[$next_module]}"
    echo -e "  ${COLOR_CYAN}Command:${COLOR_RESET} ${COLOR_BOLD}gok-new install $next_module${COLOR_RESET}"
    echo ""
    
    # Show why this is recommended after the current component
    show_recommendation_rationale "$current_component" "$next_module"
    
    echo ""
    
    # Prompt user for installation
    if [[ "$auto_install" != "true" ]]; then
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}Would you like to install $next_module now?${COLOR_RESET}"
        echo -e "${COLOR_DIM}(This will start the installation process)${COLOR_RESET}"
        echo ""
        read -p "Install $next_module? [y/N]: " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Starting $next_module installation..."
            echo ""
            installCmd "$next_module"
        else
            log_info "Installation skipped. You can install later with:"
            echo -e "  ${COLOR_BOLD}gok-new install $next_module${COLOR_RESET}"
            echo ""
        fi
    else
        # Auto-install mode
        log_info "Auto-installing $next_module..."
        installCmd "$next_module"
    fi
}

# Check if a component is installed
check_component_installed() {
    local component="$1"
    local is_installed="false"
    
    case "$component" in
        "kubernetes")
            kubectl get nodes >/dev/null 2>&1 && is_installed="true"
            ;;
        "helm")
            command -v helm >/dev/null 2>&1 && is_installed="true"
            ;;
        "ingress")
            kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1 && is_installed="true"
            ;;
        "cert-manager")
            kubectl get deployment cert-manager -n cert-manager >/dev/null 2>&1 && is_installed="true"
            ;;
        "kyverno")
            kubectl get deployment kyverno -n kyverno >/dev/null 2>&1 && is_installed="true"
            ;;
        "registry")
            kubectl get deployment registry -n registry >/dev/null 2>&1 && is_installed="true"
            ;;
        "base")
            kubectl get configmap base-config -n kube-system >/dev/null 2>&1 && is_installed="true"
            ;;
        "ldap")
            kubectl get deployment ldap -n ldap >/dev/null 2>&1 && is_installed="true"
            ;;
        "keycloak")
            kubectl get deployment keycloak -n keycloak >/dev/null 2>&1 && is_installed="true"
            ;;
        "oauth2")
            kubectl get deployment oauth2-proxy -n oauth2 >/dev/null 2>&1 && is_installed="true"
            ;;
        "gok-login")
            kubectl get deployment gok-login -n gok-login >/dev/null 2>&1 && is_installed="true"
            ;;
        "rabbitmq")
            kubectl get statefulset rabbitmq -n rabbitmq >/dev/null 2>&1 && is_installed="true"
            ;;
        "vault")
            kubectl get statefulset vault -n vault >/dev/null 2>&1 && is_installed="true"
            ;;
        "monitoring")
            kubectl get deployment -n monitoring kube-prometheus-stack-operator >/dev/null 2>&1 && is_installed="true"
            ;;
        "argocd")
            kubectl get deployment -n argocd argocd-server >/dev/null 2>&1 && is_installed="true"
            ;;
        "gok-agent")
            kubectl get deployment -n gok-agent gok-agent >/dev/null 2>&1 && is_installed="true"
            ;;
        "gok-controller"|"controller")
            kubectl get deployment -n gok-controller gok-controller >/dev/null 2>&1 && is_installed="true"
            ;;
        "che")
            kubectl get checluster -n eclipse-che >/dev/null 2>&1 && is_installed="true"
            ;;
        "workspace")
            kubectl get devworkspaces --all-namespaces >/dev/null 2>&1 && \
            [[ $(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null | wc -l) -gt 0 ]] && is_installed="true"
            ;;
        "docker")
            command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && is_installed="true"
            ;;
        "jenkins")
            kubectl get deployment -n jenkins jenkins >/dev/null 2>&1 && is_installed="true"
            ;;
        "jupyter")
            kubectl get deployment -n jupyter jupyterhub >/dev/null 2>&1 && is_installed="true"
            ;;
        "dashboard")
            kubectl get deployment -n kubernetes-dashboard kubernetes-dashboard >/dev/null 2>&1 && is_installed="true"
            ;;
        "istio")
            kubectl get deployment -n istio-system istiod >/dev/null 2>&1 && is_installed="true"
            ;;
        "fluentd")
            kubectl get daemonset -n logging fluentd >/dev/null 2>&1 && is_installed="true"
            ;;
        "opensearch")
            kubectl get statefulset -n opensearch opensearch-cluster-master >/dev/null 2>&1 && is_installed="true"
            ;;
    esac
    
    echo "$is_installed"
}

# Show recommendation rationale
show_recommendation_rationale() {
    local current_component="$1"
    local next_module="$2"
    
    case "$current_component -> $next_module" in
        "docker -> kubernetes")
            echo -e "${COLOR_YELLOW}📋 Why install kubernetes next?${COLOR_RESET}"
            echo -e "  • Docker provides the container runtime"
            echo -e "  • Kubernetes orchestrates containers across multiple nodes"
            echo -e "  • Enables automated deployment, scaling, and management"
            echo -e "  • Foundation for building cloud-native applications"
            ;;
        "kubernetes -> helm")
            echo -e "${COLOR_YELLOW}📋 Why install helm next?${COLOR_RESET}"
            echo -e "  • Kubernetes package manager for deploying applications"
            echo -e "  • Simplifies installation of complex applications"
            echo -e "  • Required for most GOK platform components"
            echo -e "  • Provides version management and rollback capabilities"
            ;;
        "helm -> ingress")
            echo -e "${COLOR_YELLOW}📋 Why install ingress next?${COLOR_RESET}"
            echo -e "  • Enables external HTTP/HTTPS access to cluster services"
            echo -e "  • Provides load balancing and traffic routing"
            echo -e "  • Essential for accessing web-based applications and dashboards"
            echo -e "  • Foundation for exposing services to external users"
            ;;
        "ingress -> cert-manager")
            echo -e "${COLOR_YELLOW}📋 Why install cert-manager next?${COLOR_RESET}"
            echo -e "  • Provides automated TLS certificate management"
            echo -e "  • Secures ingress traffic with HTTPS encryption"
            echo -e "  • Integrates with Let's Encrypt for free certificates"
            echo -e "  • Required for production-grade secure communications"
            ;;
        "cert-manager -> kyverno")
            echo -e "${COLOR_YELLOW}📋 Why install kyverno next?${COLOR_RESET}"
            echo -e "  • Policy engine for Kubernetes security and governance"
            echo -e "  • Enforces security policies and best practices"
            echo -e "  • Validates and mutates Kubernetes resources"
            echo -e "  • Essential for compliance and security hardening"
            ;;
        "kyverno -> registry")
            echo -e "${COLOR_YELLOW}📋 Why install registry next?${COLOR_RESET}"
            echo -e "  • Private container image registry for your applications"
            echo -e "  • Secure storage and management of container images"
            echo -e "  • Required for deploying custom applications"
            echo -e "  • Integrates with CI/CD pipelines for image distribution"
            ;;
        "registry -> base")
            echo -e "${COLOR_YELLOW}📋 Why install base next?${COLOR_RESET}"
            echo -e "  • Core platform services and base infrastructure"
            echo -e "  • Provides shared services and configurations"
            echo -e "  • Foundation for other platform components"
            echo -e "  • Sets up common utilities and base Docker images"
            ;;
        "base -> ldap")
            echo -e "${COLOR_YELLOW}📋 Why install ldap next?${COLOR_RESET}"
            echo -e "  • Centralized directory service for users and groups"
            echo -e "  • Foundation for authentication and authorization"
            echo -e "  • Required for Keycloak user federation"
            echo -e "  • Enables enterprise identity management"
            ;;
        "ldap -> keycloak")
            echo -e "${COLOR_YELLOW}📋 Why install keycloak next?${COLOR_RESET}"
            echo -e "  • Identity and access management platform"
            echo -e "  • Provides OAuth2/OIDC authentication"
            echo -e "  • Integrates with LDAP for user management"
            echo -e "  • Foundation for SSO across all platform services"
            ;;
        "keycloak -> oauth2")
            echo -e "${COLOR_YELLOW}📋 Why install oauth2 next?${COLOR_RESET}"
            echo -e "  • Authentication proxy for protecting services"
            echo -e "  • Enables SSO across all platform components"
            echo -e "  • Integrates with Keycloak for authentication"
            echo -e "  • Secures ingress endpoints with OAuth2/OIDC"
            ;;
        "oauth2 -> gok-login")
            echo -e "${COLOR_YELLOW}📋 Why install gok-login next?${COLOR_RESET}"
            echo -e "  • GOK authentication service"
            echo -e "  • Provides unified login experience"
            echo -e "  • Integrates with Keycloak and OAuth2"
            echo -e "  • Required for GOK platform access control"
            ;;
        "gok-login -> rabbitmq")
            echo -e "${COLOR_YELLOW}📋 Why install rabbitmq next?${COLOR_RESET}"
            echo -e "  • Message broker for asynchronous communication"
            echo -e "  • Enables event-driven architecture"
            echo -e "  • Required for GOK platform messaging"
            echo -e "  • Supports distributed system communication"
            ;;
        "rabbitmq -> vault")
            echo -e "${COLOR_YELLOW}📋 Why install vault next?${COLOR_RESET}"
            echo -e "  • Secrets management and secure storage"
            echo -e "  • Centralized credential management"
            echo -e "  • Provides dynamic secrets and encryption"
            echo -e "  • Essential for production security"
            ;;
        "vault -> monitoring")
            echo -e "${COLOR_YELLOW}📋 Why install monitoring next?${COLOR_RESET}"
            echo -e "  • Prometheus & Grafana observability stack"
            echo -e "  • Metrics collection and visualization"
            echo -e "  • Enables system health monitoring and alerting"
            echo -e "  • Critical for production operations"
            ;;
        "monitoring -> argocd")
            echo -e "${COLOR_YELLOW}📋 Why install argocd next?${COLOR_RESET}"
            echo -e "  • GitOps continuous delivery platform"
            echo -e "  • Automates application deployment from Git"
            echo -e "  • Enables declarative infrastructure management"
            echo -e "  • Provides audit trail and rollback capabilities"
            ;;
        "argocd -> gok-agent")
            echo -e "${COLOR_YELLOW}📋 Why install gok-agent next?${COLOR_RESET}"
            echo -e "  • GOK distributed system agent"
            echo -e "  • Enables remote execution and monitoring"
            echo -e "  • Required for GOK platform functionality"
            echo -e "  • Foundation for gok-controller"
            ;;
        "gok-agent -> gok-controller")
            echo -e "${COLOR_YELLOW}📋 Why install gok-controller next?${COLOR_RESET}"
            echo -e "  • GOK distributed system controller"
            echo -e "  • Provides centralized platform management"
            echo -e "  • Enables workflow orchestration"
            echo -e "  • Complete the GOK platform installation"
            ;;
        "gok-controller -> che")
            echo -e "${COLOR_YELLOW}📋 Why install che next?${COLOR_RESET}"
            echo -e "  • Eclipse Che cloud-based IDE"
            echo -e "  • Provides browser-based development environment"
            echo -e "  • Integrates with OAuth/Keycloak for authentication"
            echo -e "  • Enables collaborative development workflows"
            echo -e "  • Foundation for creating DevWorkspaces"
            ;;
        "che -> workspace")
            echo -e "${COLOR_YELLOW}📋 Why create workspace next?${COLOR_RESET}"
            echo -e "  • DevWorkspace for actual development work"
            echo -e "  • Isolated development environment per project/user"
            echo -e "  • Pre-configured containers with development tools"
            echo -e "  • Persistent storage for project files"
            echo -e "  • Complete the development environment setup"
            ;;
        *)
            echo -e "${COLOR_YELLOW}📋 Why install $next_module?${COLOR_RESET}"
            echo -e "  • Logical next step in platform setup"
            echo -e "  • Builds upon $current_component functionality"
            echo -e "  • Provides additional capabilities for your platform"
            ;;
    esac
}

# Show general next suggestions when no specific chain exists
show_general_next_suggestions() {
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🎯 Suggested Next Steps:${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}Development Tools:${COLOR_RESET}"
    echo -e "  • ${COLOR_BOLD}jenkins${COLOR_RESET} - CI/CD automation and pipeline management"
    echo -e "  • ${COLOR_BOLD}argocd${COLOR_RESET} - GitOps continuous delivery"
    echo -e "  • ${COLOR_BOLD}jupyter${COLOR_RESET} - Interactive data science and development"
    echo ""
    echo -e "${COLOR_YELLOW}Observability & Monitoring:${COLOR_RESET}"
    echo -e "  • ${COLOR_BOLD}monitoring${COLOR_RESET} - Prometheus & Grafana stack"
    echo -e "  • ${COLOR_BOLD}fluentd${COLOR_RESET} - Log collection and aggregation"
    echo -e "  • ${COLOR_BOLD}opensearch${COLOR_RESET} - Search and analytics engine"
    echo ""
    echo -e "${COLOR_YELLOW}Service Mesh & Networking:${COLOR_RESET}"
    echo -e "  • ${COLOR_BOLD}istio${COLOR_RESET} - Service mesh for microservices"
    echo ""
    echo -e "${COLOR_YELLOW}Management & UI:${COLOR_RESET}"
    echo -e "  • ${COLOR_BOLD}dashboard${COLOR_RESET} - Kubernetes web-based management"
    echo ""
    echo -e "${COLOR_DIM}Use: ${COLOR_BOLD}gok-new install <component>${COLOR_RESET}${COLOR_DIM} to install any component${COLOR_RESET}"
    echo ""
}

# Show help for next command
show_next_help() {
    echo "Usage: gok-new next <component>"
    echo ""
    echo "Show recommended next component to install after the current component"
    echo ""
    echo "Arguments:"
    echo "  component    Name of the component just installed"
    echo ""
    echo "Examples:"
    echo "  gok-new next kubernetes       # Show what to install after kubernetes"
    echo "  gok-new next cert-manager     # Show what to install after cert-manager"
    echo "  gok-new next monitoring       # Show what to install after monitoring"
    echo ""
    echo "Supported components:"
    echo "  docker, kubernetes, helm, ingress, cert-manager, kyverno"
    echo "  registry, base, ldap, keycloak, oauth2, gok-login"
    echo "  rabbitmq, vault, monitoring, argocd"
    echo "  gok-agent, gok-controller"
    echo ""
    echo "The command will:"
    echo "  • Show the recommended next component"
    echo "  • Explain why it's recommended"
    echo "  • Prompt you to install it"
    echo ""
}

# Export functions
export -f nextCmd
export -f suggest_and_install_next_module
export -f check_component_installed
export -f show_recommendation_rationale
export -f show_general_next_suggestions
export -f show_next_help
