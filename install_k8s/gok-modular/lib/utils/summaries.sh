#!/bin/bash
# =============================================================================
# GOK Modular - Component Installation Summaries
# =============================================================================
# Provides detailed post-installation summaries for all GOK components
# Includes endpoints, credentials, next steps, and troubleshooting information

# Source dependencies
if [[ -f "${BASH_SOURCE[0]%/*}/logging.sh" ]]; then
    source "${BASH_SOURCE[0]%/*}/logging.sh"
fi
if [[ -f "${BASH_SOURCE[0]%/*}/colors.sh" ]]; then
    source "${BASH_SOURCE[0]%/*}/colors.sh"
fi

# =============================================================================
# MAIN SUMMARY FUNCTION
# =============================================================================

# Main function to show component summary after installation
show_component_summary() {
    local component="$1"
    local namespace="${2:-default}"
    
    if [[ -z "$component" ]]; then
        log_error "Component name required for summary"
        return 1
    fi
    
    log_info ""
    log_header "Installation Summary" "$component"
    
    # Dispatch to component-specific summary
    case "$component" in
        "docker")
            show_docker_summary
            ;;
        "kubernetes")
            show_kubernetes_summary
            ;;
        "haproxy"|"ha-proxy"|"ha")
            show_haproxy_summary
            ;;
        "helm")
            show_helm_summary
            ;;
        "calico")
            show_calico_summary "$namespace"
            ;;
        "ingress")
            show_ingress_summary "$namespace"
            ;;
        "cert-manager")
            show_cert_manager_summary "$namespace"
            ;;
        "keycloak")
            show_keycloak_summary "$namespace"
            ;;
        "oauth2"|"oauth2-proxy")
            show_oauth2_summary "$namespace"
            ;;
        "vault")
            show_vault_summary "$namespace"
            ;;
        "ldap"|"openldap")
            show_ldap_summary "$namespace"
            ;;
        "monitoring")
            show_monitoring_summary "$namespace"
            ;;
        "prometheus")
            show_prometheus_summary "$namespace"
            ;;
        "grafana")
            show_grafana_summary "$namespace"
            ;;
        "fluentd")
            show_fluentd_summary "$namespace"
            ;;
        "opensearch")
            show_opensearch_summary "$namespace"
            ;;
        "dashboard")
            show_dashboard_summary "$namespace"
            ;;
        "jupyter"|"jupyterhub")
            show_jupyter_summary "$namespace"
            ;;
        "argocd")
            show_argocd_summary "$namespace"
            ;;
        "jenkins")
            show_jenkins_summary "$namespace"
            ;;
        "registry")
            show_registry_summary "$namespace"
            ;;
        "gok-controller")
            show_gok_controller_summary "$namespace"
            ;;
        "gok-login")
            show_gok_login_summary "$namespace"
            ;;
        *)
            show_generic_summary "$component" "$namespace"
            ;;
    esac
    
    echo ""
}

# =============================================================================
# INFRASTRUCTURE COMPONENTS SUMMARIES
# =============================================================================

show_docker_summary() {
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🐳 Docker Container Runtime${COLOR_RESET}"
    echo -e "${COLOR_DIM}Containerization platform for running applications${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1 || echo "Unknown")
    local docker_status=$(systemctl is-active docker 2>/dev/null || echo "inactive")
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Version: ${COLOR_BOLD}$docker_version${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Service Status: ${COLOR_BOLD}$docker_status${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Socket Path: ${COLOR_DIM}/var/run/docker.sock${COLOR_RESET}"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Check status:${COLOR_RESET}     ${COLOR_BOLD}docker info${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}List images:${COLOR_RESET}      ${COLOR_BOLD}docker images${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}List containers:${COLOR_RESET}  ${COLOR_BOLD}docker ps -a${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}System cleanup:${COLOR_RESET}   ${COLOR_BOLD}docker system prune${COLOR_RESET}"
    echo ""
    
    # Configuration Files
    log_info "📁 Important Directories"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Data Directory: ${COLOR_DIM}/var/lib/docker${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Config File: ${COLOR_DIM}/etc/docker/daemon.json${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Service File: ${COLOR_DIM}/lib/systemd/system/docker.service${COLOR_RESET}"
    echo ""
    
    # Next Steps
    log_info "🎯 Next Steps"
    echo -e "  ${COLOR_YELLOW}1.${COLOR_RESET} Install Kubernetes: ${COLOR_BOLD}gok install kubernetes${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}2.${COLOR_RESET} Pull base images: ${COLOR_BOLD}docker pull ubuntu:latest${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}3.${COLOR_RESET} Configure registry: Set up private Docker registry"
    echo ""
    
    # Troubleshooting
    log_info "🔧 Troubleshooting"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Service issues: ${COLOR_DIM}sudo systemctl status docker${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Permission denied: ${COLOR_DIM}sudo usermod -aG docker \$USER${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Storage issues: ${COLOR_DIM}docker system df${COLOR_RESET}"
}

show_kubernetes_summary() {
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}☸️ Kubernetes Cluster${COLOR_RESET}"
    echo -e "${COLOR_DIM}Container orchestration platform${COLOR_RESET}"
    echo ""
    
    # Cluster Status
    log_info "📋 Cluster Status"
    local k8s_version=$(kubectl version --client=true -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo "Unknown")
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    local cluster_status=$(kubectl cluster-info 2>/dev/null | head -1 | grep -q "running" && echo "Active" || echo "Inactive")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Version: ${COLOR_BOLD}$k8s_version${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Nodes: ${COLOR_BOLD}$node_count${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Status: ${COLOR_BOLD}$cluster_status${COLOR_RESET}"
    echo ""
    
    # Key Endpoints
    log_info "🌐 Key Endpoints"
    local api_server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "Not configured")
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} API Server: ${COLOR_BOLD}$api_server${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} kubectl config: ${COLOR_DIM}~/.kube/config${COLOR_RESET}"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Cluster info:${COLOR_RESET}     ${COLOR_BOLD}kubectl cluster-info${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Get nodes:${COLOR_RESET}        ${COLOR_BOLD}kubectl get nodes${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Get namespaces:${COLOR_RESET}   ${COLOR_BOLD}kubectl get namespaces${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Get all pods:${COLOR_RESET}     ${COLOR_BOLD}kubectl get pods --all-namespaces${COLOR_RESET}"
    echo ""
    
    # Next Steps
    log_info "🎯 Next Steps"
    echo -e "  ${COLOR_YELLOW}1.${COLOR_RESET} Install network plugin: ${COLOR_BOLD}gok install calico${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}2.${COLOR_RESET} Install ingress controller: ${COLOR_BOLD}gok install ingress${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}3.${COLOR_RESET} Install Helm: ${COLOR_BOLD}gok install helm${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}4.${COLOR_RESET} Install cert-manager: ${COLOR_BOLD}gok install cert-manager${COLOR_RESET}"
    echo ""
    
    # Troubleshooting
    log_info "🔧 Troubleshooting"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Node issues: ${COLOR_DIM}kubectl describe nodes${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Pod issues: ${COLOR_DIM}kubectl describe pod <pod-name>${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Config issues: ${COLOR_DIM}kubectl config view${COLOR_RESET}"
}

show_haproxy_summary() {
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}⚖️ HAProxy Load Balancer${COLOR_RESET}"
    echo -e "${COLOR_DIM}High availability load balancer for Kubernetes API servers${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local ha_port="${HA_PROXY_PORT:-6643}"
    local container_status=$(docker ps --filter "name=master-proxy" --format "{{.Status}}" 2>/dev/null || echo "Not running")
    local container_id=$(docker ps --filter "name=master-proxy" --format "{{.ID}}" 2>/dev/null || echo "N/A")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Container: ${COLOR_BOLD}master-proxy${COLOR_RESET} (ID: ${COLOR_DIM}${container_id}${COLOR_RESET})"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Status: ${COLOR_BOLD}$container_status${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Port: ${COLOR_BOLD}$ha_port${COLOR_RESET}"
    echo ""
    
    # Endpoints
    log_info "🌐 Endpoints"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Load Balancer: ${COLOR_BOLD}https://localhost:$ha_port${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Configuration: ${COLOR_DIM}/opt/haproxy.cfg${COLOR_RESET}"
    echo ""
    
    # Backend Servers
    if [[ -n "${API_SERVERS:-}" ]]; then
        log_info "🔄 Backend Servers"
        IFS=','
        local counter=0
        for worker in $API_SERVERS; do
            oifs=$IFS
            IFS=':'
            read -r ip node <<<"$worker"
            counter=$((counter + 1))
            echo -e "  ${COLOR_GREEN}${counter}.${COLOR_RESET} ${COLOR_BOLD}$node${COLOR_RESET} → ${COLOR_DIM}$ip:6443${COLOR_RESET}"
            IFS=$oifs
        done
        unset IFS
        echo ""
    fi
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Check logs:${COLOR_RESET}       ${COLOR_BOLD}docker logs master-proxy${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Restart proxy:${COLOR_RESET}    ${COLOR_BOLD}docker restart master-proxy${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Test connectivity:${COLOR_RESET} ${COLOR_BOLD}curl -k https://localhost:$ha_port/healthz${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}View config:${COLOR_RESET}      ${COLOR_BOLD}cat /opt/haproxy.cfg${COLOR_RESET}"
    echo ""
    
    # Next Steps
    log_info "🎯 Next Steps"
    echo -e "  ${COLOR_YELLOW}1.${COLOR_RESET} Install Kubernetes masters using HA endpoint"
    echo -e "  ${COLOR_YELLOW}2.${COLOR_RESET} Configure kubectl: ${COLOR_BOLD}kubectl config set-cluster <name> --server=https://localhost:$ha_port${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}3.${COLOR_RESET} Test load balancing across all API servers"
    echo ""
    
    # Troubleshooting
    log_info "🔧 Troubleshooting"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Container issues: ${COLOR_DIM}docker logs master-proxy${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Port conflicts: ${COLOR_DIM}netstat -tlnp | grep $ha_port${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Config validation: ${COLOR_DIM}docker exec master-proxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg${COLOR_RESET}"
}

show_helm_summary() {
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}⎈ Helm Package Manager${COLOR_RESET}"
    echo -e "${COLOR_DIM}Kubernetes package manager for application deployment${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local helm_version=$(helm version --short 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
    local repo_count=$(helm repo list 2>/dev/null | wc -l || echo "0")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Version: ${COLOR_BOLD}$helm_version${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Repositories: ${COLOR_BOLD}$repo_count${COLOR_RESET}"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}List repos:${COLOR_RESET}       ${COLOR_BOLD}helm repo list${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Search charts:${COLOR_RESET}    ${COLOR_BOLD}helm search repo <keyword>${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}List releases:${COLOR_RESET}    ${COLOR_BOLD}helm list --all-namespaces${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Install chart:${COLOR_RESET}    ${COLOR_BOLD}helm install <name> <chart>${COLOR_RESET}"
    echo ""
    
    # Next Steps
    log_info "🎯 Next Steps"
    echo -e "  ${COLOR_YELLOW}1.${COLOR_RESET} Add repositories: ${COLOR_BOLD}helm repo add bitnami https://charts.bitnami.com/bitnami${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}2.${COLOR_RESET} Install applications: ${COLOR_BOLD}gok install <component>${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}3.${COLOR_RESET} Update repositories: ${COLOR_BOLD}helm repo update${COLOR_RESET}"
}

# =============================================================================
# SECURITY COMPONENTS SUMMARIES
# =============================================================================

show_cert_manager_summary() {
    local namespace="${1:-cert-manager}"
    
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔐 cert-manager${COLOR_RESET}"
    echo -e "${COLOR_DIM}Automatic TLS certificate management for Kubernetes${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
    local ready_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Pods: ${COLOR_BOLD}$ready_pods/$pod_count${COLOR_RESET} running"
    echo ""
    
    # Key Resources
    log_info "📋 Key Resources"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} ClusterIssuers: ${COLOR_DIM}kubectl get clusterissuers${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Certificates: ${COLOR_DIM}kubectl get certificates --all-namespaces${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} CertificateRequests: ${COLOR_DIM}kubectl get certificaterequests --all-namespaces${COLOR_RESET}"
    echo ""
    
    # Next Steps
    log_info "🎯 Next Steps"
    echo -e "  ${COLOR_YELLOW}1.${COLOR_RESET} Create ClusterIssuer for Let's Encrypt"
    echo -e "  ${COLOR_YELLOW}2.${COLOR_RESET} Configure ingress with TLS annotations"
    echo -e "  ${COLOR_YELLOW}3.${COLOR_RESET} Monitor certificate renewal"
}

show_keycloak_summary() {
    local namespace="${1:-keycloak}"
    
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔑 Keycloak Identity Provider${COLOR_RESET}"
    echo -e "${COLOR_DIM}Identity and access management solution${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local service_ip=$(kubectl get svc -n "$namespace" keycloak -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "Not found")
    local ingress_host=$(kubectl get ingress -n "$namespace" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "Not configured")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Service IP: ${COLOR_BOLD}$service_ip${COLOR_RESET}"
    if [[ "$ingress_host" != "Not configured" ]]; then
        echo -e "  ${COLOR_GREEN}•${COLOR_RESET} External URL: ${COLOR_BOLD}https://$ingress_host${COLOR_RESET}"
    fi
    echo ""
    
    # Credentials
    log_info "🔐 Default Credentials"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Username: ${COLOR_BOLD}admin${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Password: ${COLOR_DIM}kubectl get secret -n $namespace keycloak -o jsonpath='{.data.password}' | base64 -d${COLOR_RESET}"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Access admin:${COLOR_RESET}     ${COLOR_BOLD}kubectl port-forward -n $namespace svc/keycloak 8080:8080${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Get password:${COLOR_RESET}     ${COLOR_DIM}kubectl get secret -n $namespace keycloak -o jsonpath='{.data.password}' | base64 -d${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Check logs:${COLOR_RESET}       ${COLOR_BOLD}kubectl logs -n $namespace -l app=keycloak${COLOR_RESET}"
}

# =============================================================================
# DEVELOPMENT COMPONENTS SUMMARIES
# =============================================================================

show_jupyter_summary() {
    local namespace="${1:-jupyterhub}"
    
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}📓 JupyterHub${COLOR_RESET}"
    echo -e "${COLOR_DIM}Multi-user Jupyter notebook environment${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local hub_url=$(kubectl get ingress -n "$namespace" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "Not configured")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    if [[ "$hub_url" != "Not configured" ]]; then
        echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Hub URL: ${COLOR_BOLD}https://$hub_url${COLOR_RESET}"
    fi
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Access hub:${COLOR_RESET}       ${COLOR_BOLD}kubectl port-forward -n $namespace svc/hub 8000:8080${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Check users:${COLOR_RESET}      ${COLOR_BOLD}kubectl get pods -n $namespace | grep jupyter${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Hub logs:${COLOR_RESET}         ${COLOR_BOLD}kubectl logs -n $namespace -l component=hub${COLOR_RESET}"
}

show_argocd_summary() {
    local namespace="${1:-argocd}"
    
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔄 ArgoCD${COLOR_RESET}"
    echo -e "${COLOR_DIM}GitOps continuous deployment for Kubernetes${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local server_url=$(kubectl get ingress -n "$namespace" -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "Not configured")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    if [[ "$server_url" != "Not configured" ]]; then
        echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Server URL: ${COLOR_BOLD}https://$server_url${COLOR_RESET}"
    fi
    echo ""
    
    # Credentials
    log_info "🔐 Default Credentials"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Username: ${COLOR_BOLD}admin${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Password: ${COLOR_DIM}kubectl get secret -n $namespace argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${COLOR_RESET}"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Access UI:${COLOR_RESET}        ${COLOR_BOLD}kubectl port-forward -n $namespace svc/argocd-server 8080:443${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}CLI login:${COLOR_RESET}        ${COLOR_BOLD}argocd login <server> --username admin${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}List apps:${COLOR_RESET}        ${COLOR_BOLD}argocd app list${COLOR_RESET}"
}

# =============================================================================
# GENERIC SUMMARY FUNCTION
# =============================================================================

show_generic_summary() {
    local component="$1"
    local namespace="${2:-default}"
    
    echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}📦 $component${COLOR_RESET}"
    echo -e "${COLOR_DIM}Kubernetes component deployment${COLOR_RESET}"
    echo ""
    
    # Service Status
    log_info "📋 Service Status"
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
    local ready_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}•${COLOR_RESET} Pods: ${COLOR_BOLD}$ready_pods/$pod_count${COLOR_RESET} running"
    echo ""
    
    # Quick Commands
    log_info "⚡ Quick Commands"
    echo -e "  ${COLOR_CYAN}Check pods:${COLOR_RESET}       ${COLOR_BOLD}kubectl get pods -n $namespace${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Check services:${COLOR_RESET}   ${COLOR_BOLD}kubectl get svc -n $namespace${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}Check logs:${COLOR_RESET}       ${COLOR_BOLD}kubectl logs -n $namespace -l app=$component${COLOR_RESET}"
}

# =============================================================================
# FUNCTION EXPORTS
# =============================================================================

export -f show_component_summary
export -f show_docker_summary
export -f show_kubernetes_summary
export -f show_haproxy_summary
export -f show_helm_summary
export -f show_cert_manager_summary
export -f show_keycloak_summary
export -f show_jupyter_summary
export -f show_argocd_summary
export -f show_generic_summary