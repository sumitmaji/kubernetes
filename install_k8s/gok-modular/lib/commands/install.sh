#!/bin/bash

# GOK Install Command Module - Component installation orchestration

# Main install command handler
installCmd() {
    local component="$1"
    
    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_install_help
        return 1
    fi
    
    log_header "Component Installation" "Installing: $component"
    
    # Initialize component tracking
    init_component_tracking
    start_component "$component"
    
    # Pre-installation checks
    if ! pre_install_checks "$component"; then
        fail_component "$component" "Pre-installation checks failed"
        return 1
    fi
    
    # Dispatch to appropriate installer
    case "$component" in
        # Infrastructure components
        "docker")
            dockrInst
            ;;
        "kubernetes")
            k8sInst "kubernetes"
            ;;
        "kubernetes-worker")
            k8sInst "kubernetes-worker"
            ;;
        "helm")
            helmInst
            ;;
        "calico")
            calicoInst
            ;;
        "ingress")
            ingressInst
            ;;
        
        # Security components
        "cert-manager")
            certManagerInst
            ;;
        "keycloak")
            installKeycloakWithCertMgr
            ;;
        "oauth2")
            oauth2Inst
            ;;
        "vault")
            vaultInstall
            ;;
        "ldap")
            ldapInst
            ;;
        
        # Monitoring components
        "monitoring")
            prometheusInst
            grafanaInst
            ;;
        "prometheus")
            prometheusInst
            ;;
        "grafana")
            grafanaInst
            ;;
        "fluentd")
            fluentdInst
            ;;
        "opensearch")
            opensearchInst
            opensearchDashInst
            ;;
        
        # Development components
        "dashboard")
            installDashboardwithCertManager
            ;;
        "jupyter")
            jupyterHubInst
            ;;
        "devworkspace")
            createDevWorkspace
            ;;
        "workspace")
            createDevWorkspaceV2
            ;;
        "che")
            eclipseCheInst
            ;;
        "ttyd")
            ttydInst
            ;;
        "cloudshell")
            cloudshellInst
            ;;
        "console")
            consoleInst
            ;;
        
        # CI/CD components
        "argocd")
            argocdInst
            ;;
        "jenkins")
            jenkinsInst
            ;;
        "spinnaker")
            spinnakerInst
            ;;
        "registry")
            installRegistryWithCertMgr
            ;;
        
        # GOK Platform components
        "gok-agent")
            gokAgentInstall
            ;;
        "gok-controller")
            gokControllerInstall
            ;;
        "controller")
            gok install gok-agent
            gok install gok-controller
            ;;
        "gok-login")
            gokLoginInst
            ;;
        "chart")
            chartInst
            ;;
        
        # Messaging and Policy
        "rabbitmq")
            rabbitmqInst
            ;;
        "kyverno")
            kyvernoInst
            ;;
        "istio")
            istioInst
            ;;
        
        # Solution bundles
        "base")
            install_base_infrastructure
            ;;
        "base-services")
            installBaseServices
            ;;
        
        *)
            log_error "Unknown component: $component"
            echo "Run 'gok install help' to see available components"
            fail_component "$component" "Unknown component"
            return 1
            ;;
    esac
    
    local install_result=$?
    
    # Post-installation handling
    if [[ $install_result -eq 0 ]]; then
        complete_component "$component"
        post_install_actions "$component"
        log_component_success "$component"
        suggest_next_installations "$component"
    else
        fail_component "$component" "Installation failed with exit code $install_result"
        log_component_error "$component"
        provide_component_troubleshooting "$component"
        return $install_result
    fi
}

# Show install command help
show_install_help() {
    echo "gok install - Install and configure Kubernetes components"
    echo ""
    echo "Usage: gok install <component> [options]"
    echo ""
    echo "Infrastructure Components:"
    echo "  docker                 Docker container runtime"
    echo "  kubernetes            Kubernetes master node"
    echo "  kubernetes-worker     Kubernetes worker node"  
    echo "  helm                  Helm package manager"
    echo "  calico                Calico network plugin"
    echo "  ingress               NGINX Ingress Controller"
    echo ""
    echo "Security Components:"
    echo "  cert-manager          Certificate management"
    echo "  keycloak             Identity and access management"
    echo "  oauth2               OAuth2 proxy"
    echo "  vault                HashiCorp Vault"
    echo "  ldap                 LDAP authentication"
    echo ""
    echo "Monitoring Components:"
    echo "  monitoring           Full monitoring stack (Prometheus + Grafana)"
    echo "  prometheus           Prometheus monitoring"
    echo "  grafana             Grafana dashboards"
    echo "  fluentd             Log aggregation"
    echo "  opensearch          Search and analytics"
    echo ""
    echo "Development Components:"
    echo "  dashboard           Kubernetes dashboard"
    echo "  jupyter             JupyterHub development environment"
    echo "  devworkspace        Development workspace"
    echo "  workspace           Development workspace v2"
    echo "  che                 Eclipse Che IDE"
    echo "  ttyd                Terminal access"
    echo "  cloudshell          Cloud shell environment"
    echo "  console             Web console"
    echo ""
    echo "CI/CD Components:"
    echo "  argocd              GitOps continuous delivery"
    echo "  jenkins             CI/CD automation"
    echo "  spinnaker           Multi-cloud deployment"
    echo "  registry            Container registry"
    echo ""
    echo "GOK Platform:"
    echo "  gok-agent           GOK platform agent"
    echo "  gok-controller      GOK platform controller"
    echo "  controller          Both agent and controller"
    echo "  gok-login           Authentication service"
    echo "  chart               Helm chart registry"
    echo ""
    echo "Other Components:"
    echo "  rabbitmq            Message broker"
    echo "  kyverno             Policy engine"
    echo "  istio               Service mesh"
    echo ""
    echo "Solution Bundles:"
    echo "  base                Base infrastructure (docker, k8s, helm, ingress)"
    echo "  base-services       Essential services (vault, keycloak, registry, etc.)"
    echo ""
    echo "Options:"
    echo "  --verbose, -v       Enable verbose output"
    echo "  --force-deps        Force dependency installation"
    echo "  --skip-deps         Skip dependency checks"
    echo ""
    echo "Examples:"
    echo "  gok install kubernetes"
    echo "  gok install monitoring --verbose"
    echo "  gok install base-services"
}

# Pre-installation checks
pre_install_checks() {
    local component="$1"
    
    log_info "Running pre-installation checks for $component..."
    
    # Check if component is already installed
    if is_component_installed "$component"; then
        log_warning "$component is already installed"
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Check system requirements
    if ! check_system_requirements "$component"; then
        log_error "System requirements not met for $component"
        return 1
    fi
    
    # Check dependencies
    if ! check_component_dependencies "$component"; then
        log_error "Missing dependencies for $component"
        return 1
    fi
    
    return 0
}

# Post-installation actions
post_install_actions() {
    local component="$1"
    
    log_info "Running post-installation actions for $component..."
    
    # Validate installation
    if ! validate_component_installation "$component"; then
        log_warning "Post-installation validation failed for $component"
    fi
    
    # Update installation tracking
    echo "$component:$(date +%s)" >> "${GOK_CACHE_DIR}/installed_components"
}

# Install base infrastructure components
install_base_infrastructure() {
    log_header "Base Infrastructure Installation"
    
    local components=("docker" "kubernetes" "helm" "ingress")
    
    for component in "${components[@]}"; do
        if ! gok install "$component"; then
            log_error "Failed to install $component"
            return 1
        fi
    done
    
    log_success "Base infrastructure installation completed"
}

# Check if component is already installed
is_component_installed() {
    local component="$1"
    local installed_file="${GOK_CACHE_DIR}/installed_components"
    
    [[ -f "$installed_file" ]] && grep -q "^${component}:" "$installed_file"
}

# Check system requirements for component
check_system_requirements() {
    local component="$1"
    
    case "$component" in
        "docker"|"kubernetes")
            # Check minimum memory and CPU
            local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local memory_gb=$((memory_kb / 1024 / 1024))
            
            if [[ $memory_gb -lt 2 ]]; then
                log_error "Minimum 2GB RAM required for $component"
                return 1
            fi
            ;;
        "monitoring")
            # Monitoring stack needs more resources
            local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local memory_gb=$((memory_kb / 1024 / 1024))
            
            if [[ $memory_gb -lt 4 ]]; then
                log_error "Minimum 4GB RAM required for monitoring stack"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Check component dependencies
check_component_dependencies() {
    local component="$1"
    
    case "$component" in
        "kubernetes-worker")
            if ! is_component_installed "docker"; then
                log_error "Docker is required before installing kubernetes-worker"
                return 1
            fi
            ;;
        "helm")
            if ! is_component_installed "kubernetes"; then
                log_error "Kubernetes is required before installing Helm"
                return 1
            fi
            ;;
        "ingress"|"cert-manager")
            if ! is_component_installed "kubernetes"; then
                log_error "Kubernetes is required before installing $component"
                return 1
            fi
            ;;
        "monitoring"|"prometheus"|"grafana")
            if ! is_component_installed "kubernetes" || ! is_component_installed "helm"; then
                log_error "Kubernetes and Helm are required before installing $component"
                return 1
            fi
            ;;
    esac
    
    return 0
}