#!/bin/bash

# GOK Install Command Module - Component installation orchestration

# Main install command handler
installCmd() {
    local component="$1"
    
    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_install_help
        return 0
    fi
    
    # Check for interactive mode
    if [[ "$component" == "interactive" || "$component" == "wizard" ]]; then
        interactive_installation
        return 0
    fi
    
    log_header "Component Installation" "Installing: $component"
    
    # Initialize component tracking
    init_component_tracking "$component" "Installing $component component"
    
    # Parse all flags
    local verbose_flag=""
    local update_flags=""
    local deps_flags=""
    shift  # Remove component name from arguments
    
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_flag="--verbose"
                export GOK_VERBOSE="true"
                set_verbosity_level "verbose" 2>/dev/null || true
                log_info "Verbose logging enabled"
                ;;
            --quiet|-q)
                verbose_flag=""
                export GOK_VERBOSE="false"
                set_verbosity_level "normal" 2>/dev/null || true
                log_info "Quiet mode enabled"
                ;;
            --show-commands)
                export GOK_SHOW_COMMANDS="true"
                log_info "Command execution display enabled"
                ;;
            --force-update)
                update_flags="$update_flags --force-update"
                ;;
            --skip-update)
                update_flags="$update_flags --skip-update"
                ;;
            --force-deps)
                deps_flags="$deps_flags --force-deps"
                ;;
            --skip-deps)
                deps_flags="$deps_flags --skip-deps"
                ;;
        esac
    done
    
    # Also check environment variable
    if [[ "$GOK_VERBOSE" == "true" ]] && [[ -z "$verbose_flag" ]]; then
        verbose_flag="--verbose"
        log_info "Verbose logging enabled via GOK_VERBOSE"
    fi
    
    # Start component installation with enhanced logging
    start_component "$component"
    
    # Initialize verbosity for this installation
    if [[ -n "$verbose_flag" ]]; then
        set_verbosity_level "verbose"
    fi
    
    # Run smart system updates with caching (with automatic fallback)
    if declare -f safe_update_system_with_cache >/dev/null 2>&1; then
        if ! safe_update_system_with_cache $verbose_flag $update_flags; then
            fail_component "$component" "System update failed"
            return 1
        fi
    else
        log_warning "safe_update_system_with_cache not available, skipping system update"
    fi
    
    if declare -f safe_install_system_dependencies >/dev/null 2>&1; then
        if ! safe_install_system_dependencies $verbose_flag $deps_flags; then
            fail_component "$component" "Dependency installation failed"
            return 1
        fi
    else
        log_warning "safe_install_system_dependencies not available, skipping dependency installation"
    fi
    
    # Pre-installation checks
    if ! pre_install_checks "$component"; then
        fail_component "$component" "Pre-installation checks failed"
        return 1
    fi
    
    # Enhanced installation with validation
    case "$component" in
        # Infrastructure components with validation
        "docker")
            if dockrInst; then
                if validate_component_installation "docker" 60; then
                    complete_component "docker" "Docker installation completed and validated"
                else
                    complete_component "docker" "Docker installed but validation had warnings"
                fi
            else
                fail_component "docker" "Docker installation failed"
                return 1
            fi
            ;;
            
        "helm")
            if helmInst; then
                if validate_component_installation "helm" 60; then
                    complete_component "helm" "Helm installation completed and validated"
                else
                    complete_component "helm" "Helm installed but validation had warnings"
                fi
            else
                fail_component "helm" "Helm installation failed"
                return 1
            fi
            ;;
            
        "cert-manager")
            if certManagerInst && setupCertiIssuers; then
                if validate_component_installation "cert-manager" 300; then
                    complete_component "cert-manager" "Cert-manager installation completed and validated"
                else
                    complete_component "cert-manager" "Cert-manager installed but validation had warnings"
                fi
            else
                fail_component "cert-manager" "Cert-manager installation failed"
                return 1
            fi
            ;;
            
        "monitoring")
            if installPrometheusGrafanaWithCertMgr; then
                if validate_component_installation "monitoring" 600; then
                    complete_component "monitoring" "Monitoring stack installation completed and validated"
                else
                    complete_component "monitoring" "Monitoring stack installed but validation had warnings"
                fi
            else
                fail_component "monitoring" "Monitoring stack installation failed"
                return 1
            fi
            ;;
            
        "argocd")
            if argocdInst; then
                if validate_component_installation "argocd" 300; then
                    complete_component "argocd" "ArgoCD installation completed and validated"
                else
                    complete_component "argocd" "ArgoCD installed but validation had warnings"
                fi
            else
                fail_component "argocd" "ArgoCD installation failed"
                return 1
            fi
            ;;
            
        "gok-agent")
            if gok_agent_install; then
                if validate_component_installation "gok-agent" 180; then
                    complete_component "gok-agent" "GOK Agent installation completed and validated"
                else
                    complete_component "gok-agent" "GOK Agent installed but validation had warnings"
                fi
            else
                fail_component "gok-agent" "GOK Agent installation failed"
                return 1
            fi
            ;;
            
        "gok-controller")
            if gok_controller_install; then
                if validate_component_installation "gok-controller" 180; then
                    complete_component "gok-controller" "GOK Controller installation completed and validated"
                else
                    complete_component "gok-controller" "GOK Controller installed but validation had warnings"
                fi
            else
                fail_component "gok-controller" "GOK Controller installation failed"
                return 1
            fi
            ;;
            
        "che")
            if install_che; then
                if validate_component_installation "che" 600; then
                    complete_component "che" "Eclipse Che installation completed and validated"
                else
                    complete_component "che" "Eclipse Che installed but validation had warnings"
                fi
            else
                fail_component "che" "Eclipse Che installation failed"
                return 1
            fi
            ;;
            
        "workspace")
            if install_workspace; then
                complete_component "workspace" "DevWorkspace created successfully"
            else
                fail_component "workspace" "DevWorkspace creation failed"
                return 1
            fi
            ;;
            
        "workspacev2")
            if install_workspacev2; then
                complete_component "workspacev2" "DevWorkspace V2 created successfully"
            else
                fail_component "workspacev2" "DevWorkspace V2 creation failed"
                return 1
            fi
            ;;
        
        # Infrastructure components
        "kubernetes")
            # Enhanced Kubernetes installation with comprehensive logging and validation

            # Step 1: Install Docker first (prerequisite)
            log_info "Ensuring Docker is installed and running..."
            if ! dockrInst; then
                log_error "Docker installation failed - required for Kubernetes"
                fail_component "kubernetes" "Docker prerequisite installation failed"
                return 1
            fi
            log_success "Docker prerequisite satisfied"

            # Step 2: Handle HA proxy setup automatically if needed
            log_info "Checking High Availability requirements for Kubernetes installation"

            # Check if HA is required
            local ha_required=false
            local ha_reason=""

            # Method 1: Check API_SERVERS configuration
            if [[ -n "$API_SERVERS" ]] && [[ "$API_SERVERS" == *","* ]]; then
                ha_required=true
                ha_reason="Multiple API servers configured in API_SERVERS: $API_SERVERS"
            fi

            # Method 2: Check if HA_PROXY_PORT is configured and not default
            if [[ -n "$HA_PROXY_PORT" ]] && [[ "$HA_PROXY_PORT" != "6443" ]]; then
                ha_required=true
                ha_reason="Custom HA proxy port configured: $HA_PROXY_PORT"
            fi

            # Check if HA is already installed and working
            local ha_already_installed=false
            if validate_ha_proxy_installation "$verbose_flag" >/dev/null 2>&1; then
                ha_already_installed=true
                log_success "HA proxy is already installed and running"
            fi

            if [[ "$ha_required" == "true" ]] || [[ "$ha_already_installed" == "false" ]]; then
                if [[ "$ha_required" == "true" ]]; then
                    log_info "HA setup required: $ha_reason"
                else
                    log_info "HA proxy not detected - installing for Kubernetes cluster stability"
                fi

                # If HA is not already installed, install it
                if [[ "$ha_already_installed" == "false" ]]; then
                    log_info "Installing HA proxy locally for Kubernetes cluster"

                    if haproxyInst; then
                        log_success "HA proxy installed successfully locally"

                        # Validate local HA installation
                        if validate_ha_proxy_installation "$verbose_flag"; then
                            log_success "Local HA proxy validation passed - proceeding with Kubernetes installation"
                        else
                            log_error "Local HA proxy validation failed after installation"
                            fail_component "kubernetes" "Local HA proxy validation failed after installation"
                            return 1
                        fi
                    else
                        log_error "Local HA proxy installation failed"
                        echo -e ""
                        echo -e "${COLOR_BRIGHT_RED}${COLOR_BOLD}❌ KUBERNETES INSTALLATION BLOCKED${COLOR_RESET}"
                        echo -e "${COLOR_RED}HA proxy installation failed and is required for Kubernetes.${COLOR_RESET}"
                        echo -e ""
                        echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔧 RESOLUTION STEPS:${COLOR_RESET}"
                        echo -e "${COLOR_YELLOW}1. Check Docker status: ${COLOR_BOLD}systemctl status docker${COLOR_RESET}"
                        echo -e "${COLOR_YELLOW}2. Verify configuration: ${COLOR_BOLD}echo \$API_SERVERS${COLOR_RESET}"
                        echo -e "${COLOR_YELLOW}3. Manual HA install: ${COLOR_BOLD}gok-new install haproxy${COLOR_RESET}"
                        echo -e "${COLOR_YELLOW}4. Set up remote host: ${COLOR_BOLD}gok-new remote setup <host> <user>${COLOR_RESET}"
                        echo -e "${COLOR_YELLOW}5. Retry Kubernetes installation${COLOR_RESET}"
                        echo -e ""
                        fail_component "kubernetes" "HA proxy installation required but local installation failed"
                        return 1
                    fi
                fi
            else
                log_info "HA proxy already running - proceeding with Kubernetes installation"
            fi

            # Step 3: Install Kubernetes cluster
            if k8sInst "kubernetes" "$verbose_flag"; then
                log_success "Kubernetes master node installation completed"

                # Validate Kubernetes installation before proceeding
                if validate_component_installation "kubernetes" 300; then
                    log_success "Kubernetes cluster validation passed"
                else
                    log_warning "Kubernetes cluster validation had issues"
                fi
            else
                log_error "Kubernetes installation failed"
                fail_component "kubernetes" "Kubernetes cluster installation failed"
                return 1
            fi

            # Step 4: Install Helm package manager
            log_info "Installing Helm package manager..."
            if helmInst; then
                log_success "Helm package manager installed"
            else
                log_warning "Helm installation failed - some deployments may not work"
            fi

            # Step 5: Network plugin (Calico) is now installed within k8sInst
            log_info "Network plugin (Calico) was installed during cluster setup"

            # Step 6: Wait for system services to be ready
            log_info "Waiting for Kubernetes system services..."
            # Simple wait for core services
            local attempts=0
            local max_attempts=30
            while [[ $attempts -lt $max_attempts ]]; do
                if kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -q "Running"; then
                    log_success "Kubernetes system services are ready"
                    break
                fi
                attempts=$((attempts + 1))
                sleep 2
            done
            if [[ $attempts -eq $max_attempts ]]; then
                log_warning "Some system services may not be ready yet"
            fi

            # Step 7: Install additional utilities (comprehensive)
            log_info "Installing cluster utilities..."
            
            # DNS testing utilities
            if kubectl run dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 --restart=Never --command -- sleep 3600 >/dev/null 2>&1; then
                log_success "DNS utilities installed"
                echo -e "    ${COLOR_DIM}• Pod: dnsutils (gcr.io/kubernetes-e2e-test-images/dnsutils:1.3) in default namespace${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Usage: kubectl exec dnsutils -- nslookup <domain>${COLOR_RESET}"
            else
                log_warning "DNS utilities installation failed"
            fi

            # Curl testing utility
            if kubectl run curl --image=curlimages/curl --restart=Never --command -- sleep 3600 >/dev/null 2>&1; then
                log_success "Curl utility installed"
                echo -e "    ${COLOR_DIM}• Pod: curl (curlimages/curl) in default namespace${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Usage: kubectl exec curl -- curl <url>${COLOR_RESET}"
            else
                log_warning "Curl utility installation failed"
            fi

            # Configure custom DNS zones if needed
            log_info "Configuring custom DNS zones..."
            if customDns; then
                log_success "Custom DNS zones configured"
                
                # Verify DNS configuration
                if verify_dns_configuration; then
                    log_success "DNS configuration verification completed"
                else
                    log_warning "DNS configuration verification failed"
                fi
            else
                log_info "Custom DNS configuration skipped (no custom zones defined)"
            fi

            # Setup OAuth admin access if OIDC is configured
            log_info "Setting up OAuth admin access..."
            if oauthAdmin; then
                log_success "OAuth admin access configured"
            else
                log_info "OAuth admin setup skipped (OIDC not configured or already set up)"
            fi

            # Step 8: Setup system integration (simplified)
            log_info "Setting up system integration..."
            {
                # Create symlink for gok command if it doesn't exist
                if [[ ! -L "/bin/gok" ]]; then
                    ln -sf "$GOK_ROOT/gok-new" /bin/gok 2>/dev/null || true
                fi

            } >/dev/null 2>&1

            log_success "System integration configured"
            ;;
        "kubernetes-worker")
            k8sInst "kubernetes-worker"
            ;;
        "calico")
            calicoInst
            ;;
        "ingress")
            if ingressInst; then
                if validate_component_installation "ingress" 60; then
                    complete_component "ingress" "Ingress installation completed and validated"
                else
                    complete_component "ingress" "Ingress installed but validation had warnings"
                fi
            else
                fail_component "ingress" "Ingress installation failed"
                return 1
            fi
            ;;
        "haproxy"|"ha-proxy"|"ha")
            haproxyInst
            ;;
        
        # Security components
        "keycloak")
            if installKeycloakWithCertMgr; then
                if validate_component_installation "keycloak" 60; then
                    complete_component "keycloak" "Keycloak installation completed with certificate management and OAuth2 integration"
                else
                    complete_component "keycloak" "Keycloak installed but validation had warnings"
                fi                    
            else
                fail_component "keycloak" "Keycloak installation failed"
                return 1
            fi
            ;;
        "oauth2-proxy"|"oauth2")
            if oauth2Inst; then
                if validate_component_installation "oauth2" 60; then
                    complete_component "oauth2" "OAuth2 installation completed with certificate management and integration"
                else
                    complete_component "oauth2" "OAuth2 installed but validation had warnings"
                fi
            else
                fail_component "oauth2" "OAuth2 installation failed"
                return 1
            fi
            ;;
        "vault")
            if vaultInst; then
                if validate_component_installation "vault" 120; then
                    complete_component "vault" "Vault installation completed with certificate management and secret backend configuration"
                else
                    complete_component "vault" "Vault installed but validation had warnings"
                fi
            else
                fail_component "vault" "Vault installation failed"
                return 1
            fi
            ;;
        "ldap")
            # LDAP installation with validation
            if ldapInst; then
                if validate_component_installation "ldap" 120; then
                    complete_component "ldap" "LDAP installation completed and validated"
                else
                    complete_component "ldap" "LDAP installed but validation had warnings"
                fi
            else
                fail_component "ldap" "LDAP installation failed"
                return 1
            fi
            ;;
        
        # Monitoring components
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
        "controller")
            if install_gok_agent && install_gok_controller; then
                if validate_component_installation "gok-agent" 180 && validate_component_installation "gok-controller" 180; then
                    complete_component "controller" "GOK Agent and Controller installation completed and validated"
                else
                    complete_component "controller" "GOK Agent and Controller installed but validation had warnings"
                fi
            else
                fail_component "controller" "GOK Agent / Controller installation failed"
                return 1
            fi
            
            ;;
        "gok-login")
            gokLoginInst
            ;;
        "chart")
            chartInst
            ;;
        
        # Messaging and Policy
        "rabbitmq")
            if rabbitmq_install; then
                if validate_component_installation "rabbitmq" 120; then
                    complete_component "rabbitmq" "RabbitMQ installation completed and validated"
                else
                    complete_component "rabbitmq" "RabbitMQ installed but validation had warnings"
                fi
            else
                fail_component "rabbitmq" "RabbitMQ installation failed"
                return 1
            fi
            ;;
        "kyverno")
            kyvernoInst
            ;;
        "istio")
            istioInst
            ;;
        
        # Solution bundles
        "base")
            if declare -f basePlatformInst >/dev/null; then
                basePlatformInst
            else
                log_error "basePlatformInst function not found"
                return 1
            fi
            ;;
        "base-services")
            installBaseServices
            ;;
        
        *)
            log_error "Unknown component: $component"
            echo "Run 'gok-new install help' to see available components"
            fail_component "$component" "Unknown component"
            return 1
            ;;
    esac
    
    local install_result=$?

    # Post-installation handling for all components
    if [[ $install_result -eq 0 ]]; then
        if is_component_completed "$component"; then
            # complete_component is present after sucessful installation
            # complete_component "$component"
            post_install_actions "$component"
            log_component_success "$component"
            # Map component to namespace
            local ns="default"
            case "$component" in
                "docker") ns="default" ;;
                "kubernetes"|"kubernetes-worker") ns="kube-system" ;;
                "helm") ns="kube-system" ;;
                "cert-manager") ns="cert-manager" ;;
                "monitoring"|"prometheus"|"grafana") ns="monitoring" ;;
                "fluentd") ns="logging" ;;
                "opensearch") ns="opensearch" ;;
                "argocd") ns="argocd" ;;
                "gok-agent"|"gok-controller"|"controller") ns="gok-system" ;;
                "che") ns="eclipse-che" ;;
                "workspace") ns="che-user" ;;
                "workspacev2") ns="che-user" ;;
                "haproxy") ns="default" ;;
                "ingress") ns="ingress-nginx" ;;
                "keycloak") ns="keycloak" ;;
                "oauth2") ns="oauth2" ;;
                "vault") ns="vault" ;;
                "ldap") ns="ldap" ;;
                "dashboard") ns="kubernetes-dashboard" ;;
                "jupyter") ns="jupyter" ;;
                "devworkspace") ns="devworkspace" ;;
                "workspace") ns="workspace" ;;
                "che") ns="che" ;;
                "ttyd") ns="ttyd" ;;
                "cloudshell") ns="cloudshell" ;;
                "console") ns="console" ;;
                "jenkins") ns="jenkins" ;;
                "spinnaker") ns="spinnaker" ;;
                "registry") ns="registry" ;;
                "gok-login") ns="gok-login" ;;
                "chart") ns="chart" ;;
                "rabbitmq") ns="rabbitmq" ;;
                "kyverno") ns="kyverno" ;;
                "istio") ns="istio-system" ;;
                "base"|"base-services") ns="default" ;;
                *) ns="default" ;;
            esac
            log_info "Component '$component' installed successfully in namespace '$ns'"
            show_component_summary "$component" "$ns"
            show_component_next_steps "$component"
            suggest_and_install_next_module "$component"
        fi
    else
        fail_component "$component" "Installation failed with exit code $install_result"
        log_component_error "$component"
        provide_component_troubleshooting "$component"
        return $install_result
    fi
}

# Show install command help
show_install_help() {
    echo "gok-new install - Install and configure Kubernetes components and services"
    echo ""
    echo "Usage: gok-new install <component> [--verbose|-v] [--quiet|-q] [--show-commands] [--force-update] [--skip-update] [--force-deps] [--skip-deps]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v      Show detailed installation output and system logs"
    echo "  --quiet, -q        Disable verbose output, show only essential messages"
    echo "  --show-commands    Show commands being executed during installation"
    echo "  --force-update     Force system update regardless of cache"
    echo "  --skip-update      Skip system update completely"
    echo "  --force-deps       Force dependency installation regardless of cache"
    echo "  --skip-deps        Skip dependency installation completely"
    echo ""
    echo "Environment Variables:"
    echo "  GOK_VERBOSE=true         Enable verbose mode globally (default: false)"
    echo "  GOK_SHOW_COMMANDS=true   Show commands being executed (default: false)"
    echo "  GOK_UPDATE_CACHE_HOURS=6 Hours to cache system updates (default: 6)"
    echo "  GOK_DEPS_CACHE_HOURS=6   Hours to cache dependency installations (default: same as updates)"
    echo "  GOK_CACHE_DIR=/tmp/gok-cache  Custom cache directory location"
    echo ""
    echo "Smart Caching Examples:"
    echo "  gok-new install docker                     # Uses smart cache with verbose output (default)"
    echo "  gok-new install base --quiet               # Install quietly with minimal output"
    echo "  gok-new install base --show-commands       # Show commands being executed"
    echo "  gok-new install base --skip-update         # Skip system update completely"
    echo "  gok-new install base --skip-deps           # Skip dependency installation"
    echo "  gok-new install kubernetes --force-update  # Force fresh system update"
    echo "  gok-new install kubernetes --force-deps    # Force fresh dependency installation"
    echo "  GOK_UPDATE_CACHE_HOURS=12 gok-new install helm  # Cache updates for 12 hours"
    echo "  GOK_DEPS_CACHE_HOURS=24 gok-new install vault   # Cache dependencies for 24 hours"
    echo ""
    echo "Cache Management:"
    echo "  gok-new cache status        # Check cache age and validity"
    echo "  gok-new cache clear         # Clear cache, force next update"
    echo ""
    echo "Core Infrastructure:"
    echo "  docker            Docker container runtime"
    echo "  helm              Helm package manager for Kubernetes"
    echo "  haproxy           HA proxy container for load balancing (aliases: ha-proxy, ha)"
    echo "  kubernetes        Complete Kubernetes cluster with HA"
    echo "  kubernetes-worker Kubernetes worker node"
    echo "  cert-manager      Certificate management and TLS automation"
    echo "  ingress           NGINX ingress controller"
    echo "  dashboard         Kubernetes web dashboard"
    echo ""
    echo "Monitoring & Logging:"
    echo "  monitoring        Prometheus and Grafana stack"
    echo "  fluentd           Log collection and forwarding"
    echo "  opensearch        Search and analytics engine with dashboard"
    echo ""
    echo "Security & Identity:"
    echo "  keycloak          Identity and access management"
    echo "  oauth2            OAuth2 proxy for authentication"
    echo "  vault             Secrets management"
    echo "  ldap              LDAP directory service"
    echo ""
    echo "Development Tools:"
    echo "  jupyter           JupyterHub for data science"
    echo "  devworkspace      Developer workspace (legacy)"
    echo "  workspace         Enhanced developer workspace"
    echo "  che               Eclipse Che IDE"
    echo "  ttyd              Terminal over HTTP"
    echo "  cloudshell        Cloud-based terminal"
    echo "  console           Web-based console"
    echo ""
    echo "CI/CD & DevOps:"
    echo "  argocd            GitOps continuous delivery"
    echo "  jenkins           CI/CD automation server"
    echo "  spinnaker         Multi-cloud deployment platform"
    echo "  registry          Container image registry"
    echo ""
    echo "Service Mesh & Networking:"
    echo "  istio             Service mesh for microservices"
    echo "  rabbitmq          Message broker"
    echo ""
    echo "Governance & Policy:"
    echo "  kyverno           Kubernetes policy engine"
    echo ""
    echo "GOK Platform:"
    echo "  gok-agent         GOK distributed system agent"
    echo "  gok-controller    GOK distributed system controller"
    echo "  controller        Install both gok-agent and gok-controller"
    echo "  gok-login         GOK authentication service"
    echo "  chart             Helm chart repository"
    echo ""
    echo "Complete Solutions:"
    echo "  base              Base platform with Docker images and caching"
    echo "  base-services     Complete base services stack"
    echo ""
    echo "Examples:"
    echo "  gok-new install kubernetes        # Install complete K8s cluster"
    echo "  gok-new install cert-manager      # Install certificate management"
    echo "  gok-new install monitoring        # Install Prometheus & Grafana"
    echo "  gok-new install base-services     # Install complete base stack"
    echo ""
    echo "Installation Features:"
    echo "  ✅ Automated dependency resolution"
    echo "  ✅ High availability configuration"
    echo "  ✅ TLS/SSL certificate automation"
    echo "  ✅ RBAC and security hardening"
    echo "  ✅ Production-ready configurations"
    echo "  ✅ Integrated monitoring and logging"
    echo "  ✅ Service mesh ready"
    echo ""
    echo "Prerequisites:"
    echo "  - Ubuntu/Debian-based system"
    echo "  - Root or sudo access"
    echo "  - Internet connectivity"
    echo "  - Minimum 4GB RAM, 2 CPU cores"
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
    # valation is now done in after successful installation 
    # if ! validate_component_installation "$component"; then
    #     log_warning "Post-installation validation failed for $component"
    # fi
    
    # Update installation tracking
    echo "$component:$(date +%s)" >> "${GOK_CACHE_DIR}/installed_components"
}

# Install base infrastructure components
install_base_infrastructure() {
    log_header "Base Infrastructure Installation"
    
    local components=("docker" "kubernetes" "helm" "ingress")
    
    for component in "${components[@]}"; do
        if ! gok-new install "$component"; then
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

# Check if component installation is completed
is_component_completed() {
    local component="$1"
    local status_file="${GOK_CACHE_DIR}/component_status"
    
    [[ -f "$status_file" ]] && grep -q "^${component}:completed:" "$status_file"
}

# Suggest next installations after component is installed
suggest_next_installations() {
    local component="$1"
    
    case "$component" in
        "docker")
            log_info "💡 Next recommended installations:"
            echo "  - gok-new install kubernetes (to set up Kubernetes cluster)"
            echo "  - gok-new install helm (to install package manager)"
            ;;
        "kubernetes")
            log_info "💡 Next recommended installations:"
            echo "  - gok-new install helm (package manager)"
            echo "  - gok-new install cert-manager (certificate management)"
            echo "  - gok-new install ingress (ingress controller)"
            ;;
        "cert-manager")
            log_info "💡 Next recommended installations:"
            echo "  - gok-new install ingress (ingress controller with TLS)"
            echo "  - gok-new install monitoring (monitoring stack)"
            ;;
    esac
}

# Provide component-specific troubleshooting
provide_component_troubleshooting() {
    local component="$1"
    
    log_error "Installation troubleshooting for $component:"
    echo ""
    echo "Common issues:"
    echo "  1. Check system requirements: gok-new validate system"
    echo "  2. Verify dependencies: gok-new status"
    echo "  3. Check logs: journalctl -xe"
    echo "  4. Review installation logs in ${GOK_CACHE_DIR}/logs/"
    echo ""
    echo "For detailed help:"
    echo "  - gok-new troubleshoot $component"
    echo "  - gok-new logs $component"
}

# Log component success
# Using comprehensive version declared in logging.sh
# log_component_success() {
#     local component="$1"
#     log_success "✅ $component installation completed successfully"
# }

# Log component error
log_component_error() {
    local component="$1"
    log_error "❌ $component installation failed"
}

