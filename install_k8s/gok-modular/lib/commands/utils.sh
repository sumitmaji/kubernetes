#!/bin/bash

# GOK Utility Commands Module - Describe, logs, bash operations

# Describe command handler
descCmd() {
    local target="${1:-}"
    
    if [[ "$target" == "methods" || "$target" == "functions" || "$target" == "all" ]]; then
        describe_all_methods
    elif [[ "$target" == "help" || "$target" == "--help" ]]; then
        show_desc_help
    else
        # Traditional pod description functionality
        describe_pod
    fi
}

# Show describe command help
show_desc_help() {
    echo "gok desc - Describe pods or GOK methods"
    echo ""
    echo "Usage:"
    echo "  gok desc              # Describe a selected pod (interactive)"
    echo "  gok desc methods      # Describe all GOK methods and functions"
    echo "  gok desc functions    # Same as methods"
    echo "  gok desc all          # Same as methods"
    echo ""
    echo "Examples:"
    echo "  gok desc              # Interactive pod description"
    echo "  gok desc methods      # Technical method documentation"
}

# Describe pod interactively
describe_pod() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found - Kubernetes not installed"
        return 1
    fi
    
    local pod
    if ! pod=$(getpod); then
        return 1
    fi
    
    if [[ -n "$pod" ]]; then
        log_info "Describing pod: $pod"
        kubectl describe pod "$pod"
    fi
}

# Logs command handler
logsCmd() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found - Kubernetes not installed"
        return 1
    fi
    
    local pod
    if ! pod=$(getpod); then
        return 1
    fi
    
    if [[ -n "$pod" ]]; then
        log_info "Showing logs for pod: $pod"
        kubectl logs -f "$pod"
    fi
}

# Bash command handler
bashCmd() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found - Kubernetes not installed"
        return 1
    fi
    
    local pod
    if ! pod=$(getpod); then
        return 1
    fi
    
    if [[ -n "$pod" ]]; then
        log_info "Opening terminal on pod: $pod"
        kubectl exec -it "$pod" -- /bin/bash
    fi
}

# Describe all methods (comprehensive documentation)
# Help command implementation
helpCmd() {
    log_header "GOK - Kubernetes Operations Toolkit (Modular Version)"
    
    echo "USAGE:"
    echo "  gok-new <command> [options] [arguments]"
    echo ""
    echo "AVAILABLE COMMANDS:"
    echo "  install <component>    Install specified component"
    echo "  reset <component>      Reset/uninstall specified component"
    echo "  status [component]     Show status of components"
    echo "  desc <resource>        Describe Kubernetes resources"
    echo "  logs <pod>             Show logs for pods"
    echo "  bash <pod>             Open bash shell in pod"
    echo "  exec <command>         Execute commands on remote VMs"
    echo "  create <type>          Create Kubernetes resources"
    echo "  generate <type>        Generate configuration files"
    echo "  patch <resource>       Patch Kubernetes resources"
    echo "  deploy <app>           Deploy applications"
    echo "  start <service>        Start services"
    echo "  remote <command>       Execute remote commands"
    echo "  completion             Generate shell completion"
    echo "  cache <action>         Manage cache operations"
    echo "  utils <utility>        Run utility functions"
    echo "  help                   Show this help message"
    echo ""
    echo "GLOBAL OPTIONS:"
    echo "  -h, --help             Show help for commands"
    echo "  --debug                Enable debug output"
    echo "  --quiet                Suppress non-error output"
    echo ""
    echo "EXAMPLES:"
    echo "  gok-new install docker         # Install Docker"
    echo "  gok-new install k8s            # Install Kubernetes"
    echo "  gok-new status                 # Show all component status"
    echo "  gok-new desc pods              # Describe all pods"
    echo "  gok-new logs my-pod            # Show logs for my-pod"
    echo ""
    echo "For more information on a specific command:"
    echo "  gok-new <command> --help"
}

describe_all_methods() {
    cat << 'EOF'
GOK - Method Reference Documentation
====================================

This document describes all methods, functions, and their parameters
available in the GOK Kubernetes Operations Toolkit.

COMMAND INTERFACE METHODS:
=========================

helpCmd()
├─ Purpose: Display main help and documentation
├─ Parameters: None
├─ Usage: gok help | gok --help | gok -h
└─ Returns: Comprehensive toolkit overview and usage guide

installCmd($COMPONENT)
├─ Purpose: Install and configure Kubernetes components
├─ Parameters:
│  └─ $COMPONENT: Component name to install
├─ Supported Components: 35+ including:
│  ├─ Core: docker, kubernetes, kubernetes-worker, cert-manager, ingress, dashboard
│  ├─ Monitoring: monitoring, fluentd, opensearch
│  ├─ Security: keycloak, oauth2, vault, ldap
│  ├─ Development: jupyter, devworkspace, workspace, che, ttyd, cloudshell, console
│  ├─ CI/CD: argocd, jenkins, spinnaker, registry
│  ├─ Networking: istio, rabbitmq
│  ├─ Policy: kyverno
│  ├─ GOK Platform: gok-agent, gok-controller, controller, gok-login, chart
│  └─ Solutions: base, base-services
├─ Usage: gok install <component>
└─ Returns: Installation status and configuration

resetCmd($COMPONENT)
├─ Purpose: Reset and uninstall components
├─ Parameters:
│  └─ $COMPONENT: Component name to reset
├─ Supported Components:
│  ├─ Core: docker, kubernetes, helm, calico, ingress, cert-manager, dashboard
│  ├─ Monitoring: monitoring, prometheus, grafana, fluentd, opensearch
│  ├─ Security: keycloak, oauth2, vault, ldap
│  ├─ Development: jupyter, devworkspace, workspace, che, ttyd, cloudshell, console
│  ├─ CI/CD: argocd, jenkins, spinnaker, registry
│  ├─ Networking: istio, rabbitmq
│  ├─ Policy: kyverno
│  ├─ GOK Platform: gok-agent, gok-controller, gok-login, chart
│  └─ Solutions: base-services
├─ Usage: gok reset <component>
└─ Returns: Reset status and cleanup confirmation

startCmd($COMPONENT)
├─ Purpose: Start system services
├─ Parameters:
│  └─ $COMPONENT: Service name (kubernetes, docker, helm)
├─ Usage: gok start <service>
└─ Returns: Service startup status

deployCmd($COMPONENT)
├─ Purpose: Deploy applications to Kubernetes
├─ Parameters:
│  └─ $COMPONENT: Application name (currently supports: app1)
├─ Usage: gok deploy <component>
└─ Returns: Deployment status and application details

patchCmd($RESOURCE, $NAME, $NAMESPACE, $OPTIONS, $SUBDOMAIN)
├─ Purpose: Patch and modify existing Kubernetes resources
├─ Parameters:
│  ├─ $RESOURCE: Resource type (currently supports: ingress)
│  ├─ $NAME: Resource name
│  ├─ $NAMESPACE: Kubernetes namespace
│  ├─ $OPTIONS: Patch options (letsencrypt, ldap, localtls)
│  └─ $SUBDOMAIN: Optional subdomain configuration
├─ Usage: gok patch <resource> <name> <namespace> <options> [subdomain]
└─ Returns: Patch operation status

createCmd($RESOURCE, $NAME, $ADDITIONAL)
├─ Purpose: Create Kubernetes resources and configurations
├─ Parameters:
│  ├─ $RESOURCE: Resource type (secret, certificate, kubeconfig)
│  ├─ $NAME: Resource name
│  └─ $ADDITIONAL: Additional parameters (depends on resource type)
├─ Usage: gok create <resource> <name> [additional]
└─ Returns: Creation status and resource information

generateCmd($TYPE, $NAME, $BACKEND, $FRONTEND, $OPTIONS)
├─ Purpose: Generate microservice templates and configurations
├─ Parameters:
│  ├─ $TYPE: Generation type (microservice, service, api)
│  ├─ $NAME: Service/component name
│  ├─ $BACKEND: Backend technology (optional)
│  ├─ $FRONTEND: Frontend technology (optional)
│  └─ $OPTIONS: Additional generation options
├─ Usage: gok generate <type> <name> [backend] [frontend] [options]
└─ Returns: Generated template files and instructions

descCmd([$TARGET])
├─ Purpose: Describe pods or GOK methods
├─ Parameters:
│  └─ $TARGET: Optional target (methods, functions, all, or empty for pod)
├─ Usage: gok desc [methods|functions|all]
└─ Returns: Pod description or method documentation

logsCmd()
├─ Purpose: View pod logs and diagnostics
├─ Parameters: None (interactive pod selection)
├─ Usage: gok logs
└─ Returns: Pod log output

bashCmd()
├─ Purpose: Open interactive terminal in pods
├─ Parameters: None (interactive pod selection)
├─ Usage: gok bash
└─ Returns: Interactive shell session

statusCmd()
├─ Purpose: Check Helm release status
├─ Parameters: Uses global $release variable
├─ Usage: gok status
└─ Returns: Helm release status information

taintNodeCmd()
├─ Purpose: Configure node taints and scheduling
├─ Parameters: None (interactive configuration)
├─ Usage: gok taint-node
└─ Returns: Node taint configuration status

INTERNAL UTILITY FUNCTIONS:
===========================

updateSys()
├─ Purpose: Update system packages and dependencies
├─ Called by: installCmd()
└─ Returns: System update status

installDeps()
├─ Purpose: Install required system dependencies
├─ Called by: installCmd()
└─ Returns: Dependency installation status

getpod()
├─ Purpose: Interactive pod selection utility
├─ Called by: descCmd(), logsCmd(), bashCmd()
└─ Returns: Selected pod name

taintNode()
├─ Purpose: Apply node taints for scheduling control
├─ Called by: taintNodeCmd(), installCmd()
└─ Returns: Node taint application status

COMPONENT-SPECIFIC INSTALLATION FUNCTIONS:
==========================================

dockrInst() - Docker installation and configuration
k8sInst($TYPE) - Kubernetes cluster setup ($TYPE: kubernetes|kubernetes-worker)
haInst() - High availability proxy installation
helmInst() - Helm package manager installation
calicoInst() - Calico network plugin installation
ingressInst() - NGINX Ingress Controller installation
certManagerInst() - Certificate manager installation
dashboardInst() - Kubernetes dashboard installation
monitoringInst() - Full monitoring stack (Prometheus + Grafana)
prometheusInst() - Prometheus monitoring installation
grafanaInst() - Grafana dashboard installation
fluentdInst() - Fluentd log aggregation installation
opensearchInst() - OpenSearch installation
keycloakInst() - Keycloak identity management installation
oauth2Inst() - OAuth2 proxy installation
vaultInst() - HashiCorp Vault installation
ldapInst() - LDAP server installation
jupyterInst() - JupyterHub installation
workspaceInst() - Development workspace installation
eclipseCheInst() - Eclipse Che IDE installation
argocdInst() - ArgoCD GitOps installation
jenkinsInst() - Jenkins CI/CD installation
spinnakerInst() - Spinnaker deployment platform installation
registryInst() - Container registry installation
istioInst() - Istio service mesh installation
rabbitmqInst() - RabbitMQ message broker installation
kyvernoInst() - Kyverno policy engine installation

COMPONENT-SPECIFIC RESET FUNCTIONS:
===================================

All installation functions have corresponding reset functions:
dockrReset(), k8sReset(), helmReset(), etc.

UTILITY FUNCTIONS:
==================

helm_install_with_summary() - Enhanced Helm installation with logging
helm_uninstall_with_summary() - Enhanced Helm uninstallation with logging
kubectl_with_summary() - Enhanced kubectl operations with logging
wait_for_pods_ready() - Wait for pods to reach ready state
check_deployment_readiness() - Verify deployment status
execute_with_suppression() - Execute commands with error handling
log_*() functions - Comprehensive logging system

VALIDATION FUNCTIONS:
====================

validate_component_installation() - Post-installation validation
validate_kubernetes_cluster() - Kubernetes cluster health check
validate_cert_manager() - Certificate manager validation
validate_monitoring_stack() - Monitoring components validation
check_image_pull_issues() - Container image troubleshooting
check_resource_constraints() - Resource usage validation
perform_pod_diagnostics() - Pod-level troubleshooting

REMOTE EXECUTION FUNCTIONS:
===========================

remote_exec() - Execute commands on remote hosts
remote_copy() - Copy files to remote hosts
setup_ssh_keys() - SSH key management
configure_remote_host() - Remote host configuration
smart_remote_exec() - Intelligent remote execution with fallbacks

This is a comprehensive reference. For specific usage examples and parameters,
use 'gok <command> --help' for individual command documentation.

For more information, visit: https://github.com/sumitmaji/kubernetes
EOF
}

# Taint node command (placeholder)
taintNodeCmd() {
    log_info "Node taint configuration"
    echo "This feature manages Kubernetes node taints for pod scheduling control."
    echo "Use 'kubectl taint nodes <node-name> <key>=<value>:<effect>' for manual configuration."
}

# Completion command - generate shell completion scripts
completionCmd() {
    local shell_type="${1:-bash}"
    
    # Only show header for help and install commands
    case "$shell_type" in
        --help|-h|help|install)
            log_header "GOK Command Completion"
            ;;
    esac
    
    case "$shell_type" in
        --help|-h|help)
            echo "Generate shell completion for GOK commands"
            echo ""
            echo "Usage: gok completion [shell]"
            echo ""
            echo "Supported shells:"
            echo "  bash    Generate bash completion (default)"
            echo "  zsh     Generate zsh completion"
            echo "  fish    Generate fish completion"
            echo ""
            echo "Installation:"
            echo "  # For bash (add to ~/.bashrc):"
            echo "  source <(gok-new completion bash)"
            echo ""
            echo "  # For zsh (add to ~/.zshrc):"
            echo "  source <(gok-new completion zsh)"
            echo ""
            echo "  # For fish:"
            echo "  gok-new completion fish > ~/.config/fish/completions/gok-new.fish"
            echo ""
            echo "Examples:"
            echo "  gok-new completion bash > gok-completion.bash"
            echo "  source gok-completion.bash"
            return 0
            ;;
        bash)
            # Generate bash completion 
            if [[ -f "${GOK_ROOT}/gok-completion.bash" ]]; then
                cat "${GOK_ROOT}/gok-completion.bash"
            else
                echo "Error: Completion script not found: ${GOK_ROOT}/gok-completion.bash" >&2
                return 1
            fi
            ;;
        zsh)
            # Generate zsh completion
            if [[ -f "${GOK_ROOT}/gok-completion.bash" ]]; then
                bash "${GOK_ROOT}/gok-completion.bash" generate zsh
            else
                log_error "Completion script not found: ${GOK_ROOT}/gok-completion.bash"
                return 1
            fi
            ;;
        fish)
            # Generate fish completion
            if [[ -f "${GOK_ROOT}/gok-completion.bash" ]]; then
                bash "${GOK_ROOT}/gok-completion.bash" generate fish
            else
                log_error "Completion script not found: ${GOK_ROOT}/gok-completion.bash"
                return 1
            fi
            ;;
        install)
            # Install completion for current shell
            local current_shell=$(basename "$SHELL")
            log_info "Installing completion for $current_shell..."
            if [[ -f "${GOK_ROOT}/gok-completion.bash" ]]; then
                bash "${GOK_ROOT}/gok-completion.bash" install "$current_shell"
            else
                log_error "Completion script not found: ${GOK_ROOT}/gok-completion.bash"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported shell: $shell_type"
            log_info "Supported shells: bash, zsh, fish"
            log_info "Use 'gok-new completion --help' for more information"
            return 1
            ;;
    esac
}

# Cache management command
cacheCmd() {
    local action="${1:-status}"
    
    case "$action" in
        --help|-h|help)
            echo "Manage GOK cache and temporary files"
            echo ""
            echo "Usage: gok-new cache [action]"
            echo ""
            echo "Actions:"
            echo "  status     Show cache status and size (default)"
            echo "  clean      Clean cache files"
            echo "  clear      Clear all cache and logs"
            echo "  path       Show cache directory path"
            echo ""
            echo "Examples:"
            echo "  gok-new cache status"
            echo "  gok-new cache clean"
            return 0
            ;;
        status)
            log_header "GOK Cache Status"
            
            if [[ -d "$GOK_CACHE_DIR" ]]; then
                local cache_size=$(du -sh "$GOK_CACHE_DIR" 2>/dev/null | cut -f1)
                local file_count=$(find "$GOK_CACHE_DIR" -type f 2>/dev/null | wc -l)
                
                log_info "Cache directory: $GOK_CACHE_DIR"
                log_info "Cache size: ${cache_size:-0}"
                log_info "Files: $file_count"
                
                if [[ -f "${GOK_CACHE_DIR}/component_status" ]]; then
                    local components=$(wc -l < "${GOK_CACHE_DIR}/component_status" 2>/dev/null || echo 0)
                    log_info "Tracked components: $components"
                fi
            else
                log_info "Cache directory not found: $GOK_CACHE_DIR"
            fi
            
            if [[ -d "$GOK_LOGS_DIR" ]]; then
                local logs_size=$(du -sh "$GOK_LOGS_DIR" 2>/dev/null | cut -f1)
                log_info "Logs directory: $GOK_LOGS_DIR"
                log_info "Logs size: ${logs_size:-0}"
            fi
            ;;
        clean)
            log_info "Cleaning GOK cache..."
            
            # Clean old temporary files
            if [[ -d "$GOK_CACHE_DIR" ]]; then
                find "$GOK_CACHE_DIR" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
                find "$GOK_CACHE_DIR" -name "*.lock" -mtime +1 -delete 2>/dev/null || true
                log_success "Temporary files cleaned"
            fi
            
            # Clean old logs
            if [[ -d "$GOK_LOGS_DIR" ]]; then
                find "$GOK_LOGS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
                log_success "Old logs cleaned"
            fi
            ;;
        clear)
            log_warning "This will remove ALL cache files and logs"
            read -p "Are you sure? (y/N): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if [[ -d "$GOK_CACHE_DIR" ]]; then
                    rm -rf "$GOK_CACHE_DIR"/*
                    log_success "Cache cleared"
                fi
                
                if [[ -d "$GOK_LOGS_DIR" ]]; then
                    rm -rf "$GOK_LOGS_DIR"/*
                    log_success "Logs cleared"
                fi
            else
                log_info "Operation cancelled"
            fi
            ;;
        path)
            echo "Cache: $GOK_CACHE_DIR"
            echo "Logs: $GOK_LOGS_DIR"
            ;;
        *)
            log_error "Unknown cache action: $action"
            log_info "Use 'gok-new cache --help' for available actions"
            return 1
            ;;
    esac
}