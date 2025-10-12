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

show_ingress_summary() {
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Version:${COLOR_RESET} 4.12.1"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Namespace:${COLOR_RESET} ingress-nginx"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Service Type:${COLOR_RESET} NodePort"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}HTTP Port:${COLOR_RESET} 80"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}HTTPS Port:${COLOR_RESET} 443"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Default Backend:${COLOR_RESET} Enabled"
    echo ""
    
    
    # Show next steps
    echo -e "${COLOR_CYAN}🚀 Next Steps:${COLOR_RESET}"
    echo -e "   • Ingress controller will be available shortly"
    echo -e "   • Check status: ${COLOR_BOLD}kubectl get pods -n ingress-nginx${COLOR_RESET}"
    echo -e "   • Create ingress resources to route traffic"
    echo ""
}

show_registry_summary() {
    local namespace="${1:-registry}"

    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Component:${COLOR_RESET} Container Registry"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Namespace:${COLOR_RESET} $namespace"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Storage:${COLOR_RESET} 10Gi Persistent Volume"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}Authentication:${COLOR_RESET} HTTP Basic Auth"
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${COLOR_BOLD}TLS:${COLOR_RESET} Let's Encrypt Certificate"
    echo ""

    # Access Information
    echo -e "${COLOR_CYAN}🔗 Access Information:${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}Registry URL:${COLOR_RESET} https://$(registrySubdomain).$(rootDomain)"
    echo -e "  ${COLOR_BOLD}Registry API:${COLOR_RESET} https://$(registrySubdomain).$(rootDomain)/v2/"
    echo ""

    # Credentials
    local creds_dir="./registry-creds"
    if [[ -f "${creds_dir}/registry-user.txt" && -f "${creds_dir}/registry-pass.txt" ]]; then
        local registry_user=$(cat "${creds_dir}/registry-user.txt")
        echo -e "${COLOR_YELLOW}🔐 Credentials:${COLOR_RESET}"
        echo -e "  ${COLOR_BOLD}Username:${COLOR_RESET} $registry_user"
        echo -e "  ${COLOR_BOLD}Password:${COLOR_RESET} [stored in ${creds_dir}/registry-pass.txt]"
        echo ""
    fi

    # Usage Instructions
    echo -e "${COLOR_CYAN}🚀 Usage Instructions:${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}Login:${COLOR_RESET} docker login $(registrySubdomain).$(rootDomain)"
    echo -e "  ${COLOR_BOLD}Push Image:${COLOR_RESET} docker push $(registrySubdomain).$(rootDomain)/my-app:latest"
    echo -e "  ${COLOR_BOLD}Pull Image:${COLOR_RESET} docker pull $(registrySubdomain).$(rootDomain)/my-app:latest"
    echo ""

    # Next Steps
    echo -e "${COLOR_CYAN}📋 Next Steps:${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}•${COLOR_RESET} Configure Docker daemon to trust registry certificates"
    echo -e "  ${COLOR_YELLOW}•${COLOR_RESET} Push your first image to the registry"
    echo -e "  ${COLOR_YELLOW}•${COLOR_RESET} Set up image scanning and policies"
    echo -e "  ${COLOR_YELLOW}•${COLOR_RESET} Configure registry webhooks for CI/CD"
    echo ""

    # Troubleshooting
    echo -e "${COLOR_RED}🔧 Troubleshooting:${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Check status: ${COLOR_DIM}kubectl get pods -n $namespace${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} View logs: ${COLOR_DIM}kubectl logs -n $namespace deployment/registry${COLOR_RESET}"
    echo -e "  ${COLOR_RED}•${COLOR_RESET} Test access: ${COLOR_DIM}curl -k https://$(registrySubdomain).$(rootDomain)/v2/${COLOR_RESET}"
    echo ""
}

show_kubernetes_summary() {
    
    # Check if we can connect to cluster
    local cluster_accessible=false
    if kubectl cluster-info >/dev/null 2>&1; then
        cluster_accessible=true
    fi
    
    # 1. System Components Status
    log_step "1 System Components"
    
    # Check component versions
    local kubectl_version=$(kubectl version --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "not-installed")
    local kubeadm_version=$(kubeadm version -o short 2>/dev/null || echo "not-installed")
    local kubelet_version=$(kubelet --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "not-installed")
    local docker_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "not-installed")
    
    if [[ "$kubectl_version" != "not-installed" ]]; then
        echo -e "  ${COLOR_GREEN}✓ kubectl: ${kubectl_version}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ kubectl: not installed${COLOR_RESET}"
    fi
    
    if [[ "$kubeadm_version" != "not-installed" ]]; then
        echo -e "  ${COLOR_GREEN}✓ kubeadm: ${kubeadm_version}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ kubeadm: not installed${COLOR_RESET}"
    fi
    
    if [[ "$kubelet_version" != "not-installed" ]]; then
        echo -e "  ${COLOR_GREEN}✓ kubelet: ${kubelet_version}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ kubelet: not installed${COLOR_RESET}"
    fi
    
    if [[ "$docker_version" != "not-installed" ]]; then
        echo -e "  ${COLOR_GREEN}✓ docker: ${docker_version}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ docker: not installed${COLOR_RESET}"
    fi
    
    echo ""
    
    # 2. Cluster Status
    log_step "2 Cluster Status"
    
    if [[ "$cluster_accessible" == "true" ]]; then
        echo -e "  ${COLOR_GREEN}✓ Cluster: accessible${COLOR_RESET}"
        
        # Show cluster info
        local cluster_info=$(kubectl cluster-info 2>/dev/null)
        if [[ -n "$cluster_info" ]]; then
            echo -e "    ${COLOR_DIM}$(echo "$cluster_info" | head -2)${COLOR_RESET}"
        fi
        
        # Node status
        echo ""
        log_substep "Node Status:"
        if kubectl get nodes --no-headers 2>/dev/null | while read -r line; do
            local node_name=$(echo "$line" | awk '{print $1}')
            local node_status=$(echo "$line" | awk '{print $2}')
            local node_roles=$(echo "$line" | awk '{print $3}')
            local node_age=$(echo "$line" | awk '{print $4}')
            local node_version=$(echo "$line" | awk '{print $5}')
            
            if [[ "$node_status" == "Ready" ]]; then
                echo -e "    ${COLOR_GREEN}✓ ${node_name} (${node_roles}): ${node_status} - ${node_version} (${node_age})${COLOR_RESET}"
            else
                echo -e "    ${COLOR_YELLOW}⚠ ${node_name} (${node_roles}): ${node_status} - ${node_version} (${node_age})${COLOR_RESET}"
            fi
        done; then
            :
        else
            echo -e "    ${COLOR_RED}✗ Unable to get node status${COLOR_RESET}"
        fi
        
    else
        echo -e "  ${COLOR_RED}✗ Cluster: not accessible${COLOR_RESET}"
        echo -e "    ${COLOR_DIM}Run: gok k8sInst to install Kubernetes${COLOR_RESET}"
    fi
    
    echo ""
    
    # 3. System Pods Status
    if [[ "$cluster_accessible" == "true" ]]; then
        log_step "3 System Pods"
        
        # Check critical system pods
        local system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null)
        if [[ -n "$system_pods" ]]; then
            echo "$system_pods" | while read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local ready_status=$(echo "$line" | awk '{print $2}')
                local pod_status=$(echo "$line" | awk '{print $3}')
                local restarts=$(echo "$line" | awk '{print $4}')
                local age=$(echo "$line" | awk '{print $5}')
                
                if [[ "$pod_status" == "Running" ]]; then
                    echo -e "    ${COLOR_GREEN}✓ ${pod_name}: ${pod_status} (${ready_status}) - ${age}${COLOR_RESET}"
                elif [[ "$pod_status" == "Pending" ]]; then
                    echo -e "    ${COLOR_YELLOW}⚠ ${pod_name}: ${pod_status} (${ready_status}) - ${age}${COLOR_RESET}"
                else
                    echo -e "    ${COLOR_RED}✗ ${pod_name}: ${pod_status} (${ready_status}) - ${age}${COLOR_RESET}"
                fi
            done
        else
            echo -e "    ${COLOR_RED}✗ Unable to get system pods status${COLOR_RESET}"
        fi
        
        echo ""
    fi
    
    # 4. Network Configuration
    log_step "4 Network Configuration"
    
    if [[ "$cluster_accessible" == "true" ]]; then
        # Check for Calico
        local calico_pods=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l || echo "0")
        if [[ "$calico_pods" -gt 0 ]]; then
            local calico_running=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | grep "Running" | wc -l || echo "0")
            echo -e "  ${COLOR_GREEN}✓ Calico CNI: installed (${calico_running}/${calico_pods} pods running)${COLOR_RESET}"
        else
            echo -e "  ${COLOR_RED}✗ Calico CNI: not installed${COLOR_RESET}"
        fi
        
        # Check CoreDNS custom configuration
        local coredns_config=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' 2>/dev/null)
        if [[ -n "$coredns_config" ]] && echo "$coredns_config" | grep -q "cloud.com\|gokcloud.com"; then
            echo -e "  ${COLOR_GREEN}✓ Custom DNS: configured${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• CoreDNS custom zones: cloud.com, gokcloud.com → ${MASTER_HOST_IP:-<master-ip>}${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• Kubernetes internal DNS: cloud.uat domain with 30s TTL${COLOR_RESET}"
        else
            echo -e "  ${COLOR_YELLOW}⚠ Custom DNS: default CoreDNS configuration${COLOR_RESET}"
        fi
    else
        echo -e "  ${COLOR_RED}✗ Network status: cluster not accessible${COLOR_RESET}"
    fi
    
    echo ""
    
    # 5. Utility Pods
    log_step "5 Utility Pods"
    
    if [[ "$cluster_accessible" == "true" ]]; then
        # Check dnsutils pod
        if kubectl get pod dnsutils -n default >/dev/null 2>&1; then
            local dns_status=$(kubectl get pod dnsutils -n default --no-headers 2>/dev/null | awk '{print $3}')
            if [[ "$dns_status" == "Running" ]]; then
                echo -e "  ${COLOR_GREEN}✓ DNS utilities: available${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Pod: dnsutils (jessie-dnsutils:1.3) in default namespace${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Usage: gok checkDns <domain> for DNS resolution testing${COLOR_RESET}"
            else
                echo -e "  ${COLOR_YELLOW}⚠ DNS utilities: ${dns_status}${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_RED}✗ DNS utilities: not installed${COLOR_RESET}"
        fi
        
        # Check curl pod
        if kubectl get pod curl -n default >/dev/null 2>&1; then
            local curl_status=$(kubectl get pod curl -n default --no-headers 2>/dev/null | awk '{print $3}')
            if [[ "$curl_status" == "Running" ]]; then
                echo -e "  ${COLOR_GREEN}✓ Curl utility: available${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Pod: curl (curlimages/curl) in default namespace${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Usage: gok checkCurl <url> for HTTP testing within cluster${COLOR_RESET}"
            else
                echo -e "  ${COLOR_YELLOW}⚠ Curl utility: ${curl_status}${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_RED}✗ Curl utility: not installed${COLOR_RESET}"
        fi
    else
        echo -e "  ${COLOR_RED}✗ Utility pods: cluster not accessible${COLOR_RESET}"
    fi
    
    echo ""
    
    # 6. RBAC Configuration
    log_step "6 RBAC Configuration"
    
    if [[ "$cluster_accessible" == "true" ]]; then
        # Check OAuth admin role binding
        if kubectl get clusterrolebinding oauth-cluster-admin >/dev/null 2>&1; then
            echo -e "  ${COLOR_GREEN}✓ OAuth admin: configured${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• ClusterRoleBinding: oauth-cluster-admin${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• Role: cluster-admin (full cluster access)${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• Subject: Group 'administrators' (OAuth group mapping)${COLOR_RESET}"
        else
            echo -e "  ${COLOR_RED}✗ OAuth admin: not configured${COLOR_RESET}"
        fi
        
        # Check OAuth configuration
        echo ""
        log_substep "OAuth Integration:"
        
        # Check if oauth2-proxy is deployed
        if kubectl get deployment oauth2-proxy -n kube-system >/dev/null 2>&1; then
            local oauth_pods=$(kubectl get pods -n kube-system -l app=oauth2-proxy --no-headers 2>/dev/null | wc -l)
            local oauth_running=$(kubectl get pods -n kube-system -l app=oauth2-proxy --no-headers 2>/dev/null | grep "Running" | wc -l)
            echo -e "  ${COLOR_GREEN}✓ OAuth2-Proxy: deployed (${oauth_running}/${oauth_pods} pods running)${COLOR_RESET}"
            
            # Get OAuth service details
            local oauth_svc=$(kubectl get svc oauth2-proxy -n kube-system --no-headers 2>/dev/null)
            if [[ -n "$oauth_svc" ]]; then
                local oauth_ip=$(echo "$oauth_svc" | awk '{print $3}')
                local oauth_port=$(echo "$oauth_svc" | awk '{print $5}' | cut -d: -f1)
                echo -e "    ${COLOR_DIM}• Service: oauth2-proxy (ClusterIP: ${oauth_ip}:${oauth_port})${COLOR_RESET}"
            fi
            
            # Check OAuth configuration
            local oauth_config=$(kubectl get configmap oauth2-proxy -n kube-system -o jsonpath='{.data.OAUTH2_PROXY_CFG}' 2>/dev/null)
            if [[ -n "$oauth_config" ]]; then
                local client_id=$(echo "$oauth_config" | grep -oP 'client-id=\K[^ ]*' || echo "<configured>")
                local provider=$(echo "$oauth_config" | grep -oP 'provider=\K[^ ]*' || echo "<configured>")
                echo -e "    ${COLOR_DIM}• Provider: ${provider}${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Client ID: ${client_id}${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_RED}✗ OAuth2-Proxy: not deployed${COLOR_RESET}"
        fi
        
        # Check Keycloak integration
        if kubectl get deployment keycloak -n keycloak >/dev/null 2>&1; then
            local keycloak_pods=$(kubectl get pods -n keycloak -l app=keycloak --no-headers 2>/dev/null | wc -l)
            local keycloak_running=$(kubectl get pods -n keycloak -l app=keycloak --no-headers 2>/dev/null | grep "Running" | wc -l)
            echo -e "  ${COLOR_GREEN}✓ Keycloak: deployed (${keycloak_running}/${keycloak_pods} pods running)${COLOR_RESET}"
            
            # Get Keycloak service details
            local keycloak_svc=$(kubectl get svc keycloak -n keycloak --no-headers 2>/dev/null)
            if [[ -n "$keycloak_svc" ]]; then
                local keycloak_ip=$(echo "$keycloak_svc" | awk '{print $3}')
                local keycloak_port=$(echo "$keycloak_svc" | awk '{print $5}' | cut -d: -f1)
                echo -e "    ${COLOR_DIM}• Service: keycloak (ClusterIP: ${keycloak_ip}:${keycloak_port})${COLOR_RESET}"
                echo -e "    ${COLOR_DIM}• Admin Console: https://${keycloak_ip}:${keycloak_port}/auth/admin${COLOR_RESET}"
            fi
            
            # Check Keycloak ingress
            local keycloak_ing=$(kubectl get ingress keycloak -n keycloak --no-headers 2>/dev/null)
            if [[ -n "$keycloak_ing" ]]; then
                local keycloak_host=$(echo "$keycloak_ing" | awk '{print $3}')
                echo -e "    ${COLOR_DIM}• Ingress: https://${keycloak_host}${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_YELLOW}⚠ Keycloak: not deployed${COLOR_RESET}"
        fi
        
        # Check OAuth certificates
        if kubectl get secret oauth2-proxy-tls -n kube-system >/dev/null 2>&1; then
            echo -e "  ${COLOR_GREEN}✓ OAuth TLS: configured${COLOR_RESET}"
            echo -e "    ${COLOR_DIM}• Certificate: oauth2-proxy-tls${COLOR_RESET}"
        else
            echo -e "  ${COLOR_YELLOW}⚠ OAuth TLS: not configured${COLOR_RESET}"
        fi
        
        # Check OIDC configuration in kube-apiserver
        echo ""
        log_substep "OIDC Integration:"
        
        # Check if OIDC is configured by looking at the running API server pod
        local oidc_configured=false
        
        # Get the kube-apiserver pod name
        local apiserver_pod=$(kubectl get pods -n kube-system --no-headers -l component=kube-apiserver 2>/dev/null | head -1 | awk '{print $1}' || echo "")
        
        if [[ -n "$apiserver_pod" ]]; then
            # Check the API server pod's command line arguments for OIDC parameters
            local api_args=$(kubectl describe pod "$apiserver_pod" -n kube-system 2>/dev/null | grep "oidc" || echo "")
            
            if [[ -n "$api_args" ]]; then
                oidc_configured=true
                echo -e "  ${COLOR_GREEN}✓ OIDC: configured in API server${COLOR_RESET}"
                
                # Extract OIDC configuration details
                local oidc_issuer_url=$(echo "$api_args" | grep -oP 'oidc-issuer-url=\K[^\s]*' || echo "")
                if [[ -n "$oidc_issuer_url" ]]; then
                    echo -e "    ${COLOR_DIM}• Issuer URL: ${oidc_issuer_url}${COLOR_RESET}"
                fi
                
                local oidc_client_id=$(echo "$api_args" | grep -oP 'oidc-client-id=\K[^\s]*' || echo "")
                if [[ -n "$oidc_client_id" ]]; then
                    echo -e "    ${COLOR_DIM}• Client ID: ${oidc_client_id}${COLOR_RESET}"
                fi
                
                local oidc_username_claim=$(echo "$api_args" | grep -oP 'oidc-username-claim=\K[^\s]*' || echo "")
                if [[ -n "$oidc_username_claim" ]]; then
                    echo -e "    ${COLOR_DIM}• Username Claim: ${oidc_username_claim}${COLOR_RESET}"
                fi
                
                local oidc_groups_claim=$(echo "$api_args" | grep -oP 'oidc-groups-claim=\K[^\s]*' || echo "")
                if [[ -n "$oidc_groups_claim" ]]; then
                    echo -e "    ${COLOR_DIM}• Groups Claim: ${oidc_groups_claim}${COLOR_RESET}"
                fi
            fi
        fi
        
        # Alternative: Check for OIDC-related environment variables or secrets
        if [[ "$oidc_configured" == "false" ]]; then
            # Check if there are any OIDC-related secrets
            local oidc_secrets=$(kubectl get secrets --all-namespaces --no-headers 2>/dev/null | grep -i oidc | wc -l || echo "0")
            if [[ "$oidc_secrets" -gt 0 ]]; then
                echo -e "  ${COLOR_YELLOW}⚠ OIDC: potentially configured (found ${oidc_secrets} OIDC-related secrets)${COLOR_RESET}"
                oidc_configured=true
            fi
        fi
        
        if [[ "$oidc_configured" == "false" ]]; then
            echo -e "  ${COLOR_YELLOW}⚠ OIDC: not configured in API server${COLOR_RESET}"
        fi
        
        # Check kube-login configuration
        if kubectl get deployment kube-login -n kube-system >/dev/null 2>&1; then
            local login_pods=$(kubectl get pods -n kube-system -l app=kube-login --no-headers 2>/dev/null | wc -l)
            local login_running=$(kubectl get pods -n kube-system -l app=kube-login --no-headers 2>/dev/null | grep "Running" | wc -l)
            echo -e "  ${COLOR_GREEN}✓ Kube-login: deployed (${login_running}/${login_pods} pods running)${COLOR_RESET}"
            
            # Get kube-login service details
            local login_svc=$(kubectl get svc kube-login -n kube-system --no-headers 2>/dev/null)
            if [[ -n "$login_svc" ]]; then
                local login_ip=$(echo "$login_svc" | awk '{print $3}')
                local login_port=$(echo "$login_svc" | awk '{print $5}' | cut -d: -f1)
                echo -e "    ${COLOR_DIM}• Service: kube-login (ClusterIP: ${login_ip}:${login_port})${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_YELLOW}⚠ Kube-login: not deployed${COLOR_RESET}"
        fi
        
    else
        echo -e "  ${COLOR_RED}✗ RBAC status: cluster not accessible${COLOR_RESET}"
    fi
    
    echo ""
    
    # 7. Next Steps
    log_step "7 Available Commands"
    
    echo -e "  ${COLOR_CYAN}Cluster Management:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok k8sInst                     # Install/reinstall Kubernetes${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok k8sSummary                  # Show installation summary (this command)${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok calicoInst                  # Install Calico network plugin${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok k8sReset                    # Reset cluster${COLOR_RESET}"
    
    echo -e "  ${COLOR_CYAN}Utilities:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok dnsUtils                    # Install DNS testing utilities${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok kcurl                       # Install curl testing utilities${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok checkDns <domain>           # Test DNS resolution${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok checkCurl <url>             # Test HTTP connectivity${COLOR_RESET}"
    
    echo -e "  ${COLOR_CYAN}Configuration:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok customDns                   # Configure custom DNS zones${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok oauthAdmin                  # Configure OAuth admin access${COLOR_RESET}"
    
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Summary complete! Use the commands above to manage your cluster.${COLOR_RESET}"
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
    local verbose_mode="${2:-false}"

    local cluster_accessible=false
    if kubectl cluster-info >/dev/null 2>&1; then
        cluster_accessible=true
    fi

    # 1. Installation Status
    log_step "1" "Installation Status"
    if [[ "$cluster_accessible" == "true" ]]; then
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            echo -e "  ${COLOR_GREEN}✓ Namespace: $namespace exists${COLOR_RESET}"
            local helm_status=$(helm list -n "$namespace" --output json 2>/dev/null | jq -r '.[] | select(.name=="cert-manager") | .status' 2>/dev/null || echo "not-found")
            if [[ "$helm_status" == "deployed" ]]; then
                local chart_version=$(helm list -n "$namespace" --output json 2>/dev/null | jq -r '.[] | select(.name=="cert-manager") | .chart' 2>/dev/null || echo "unknown")
                echo -e "  ${COLOR_GREEN}✓ Helm Chart: $chart_version (deployed)${COLOR_RESET}"
            else
                echo -e "  ${COLOR_RED}✗ Helm Chart: not deployed${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_RED}✗ Namespace: $namespace not found${COLOR_RESET}"
        fi
    else
        echo -e "  ${COLOR_RED}✗ Installation status: cluster not accessible${COLOR_RESET}"
    fi
    echo ""

    # 2. Pods Status
    if [[ "$cluster_accessible" == "true" ]]; then
        log_step "2" "cert-manager Pods"
        local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null)
        if [[ -n "$pods" ]]; then
            echo "$pods" | while read -r line; do
                local pod_name=$(echo "$line" | awk '{print $1}')
                local pod_status=$(echo "$line" | awk '{print $3}')
                local ready_status=$(echo "$line" | awk '{print $2}')
                if [[ "$pod_status" == "Running" ]]; then
                    echo -e "    ${COLOR_GREEN}✓ ${pod_name}: ${pod_status} (${ready_status})${COLOR_RESET}"
                else
                    echo -e "    ${COLOR_RED}✗ ${pod_name}: ${pod_status} (${ready_status})${COLOR_RESET}"
                fi
            done
        else
            echo -e "    ${COLOR_RED}✗ No cert-manager pods found${COLOR_RESET}"
        fi
        echo ""
    fi

    # 3. Issuers and Certificates
    if [[ "$cluster_accessible" == "true" ]]; then
        log_step "3" "Certificate Issuers"
        local issuers=$(kubectl get clusterissuers --no-headers 2>/dev/null)
        if [[ -n "$issuers" ]]; then
            echo "$issuers" | while read -r line; do
                local issuer_name=$(echo "$line" | awk '{print $1}')
                local ready=$(echo "$line" | awk '{print $2}')
                if [[ "$ready" == "True" ]]; then
                    echo -e "    ${COLOR_GREEN}✓ ClusterIssuer: ${issuer_name} (Ready)${COLOR_RESET}"
                else
                    echo -e "    ${COLOR_YELLOW}⚠ ClusterIssuer: ${issuer_name} (Not Ready)${COLOR_RESET}"
                fi
            done
        else
            echo -e "    ${COLOR_CYAN}• No ClusterIssuers configured${COLOR_RESET}"
        fi

        local certificates=$(kubectl get certificates --all-namespaces --no-headers 2>/dev/null)
        if [[ -n "$certificates" ]]; then
            echo -e "  ${COLOR_CYAN}Active Certificates:${COLOR_RESET}"
            echo "$certificates" | head -5 | while read -r line; do
                local namespace_cert=$(echo "$line" | awk '{print $1}')
                local cert_name=$(echo "$line" | awk '{print $2}')
                local ready=$(echo "$line" | awk '{print $3}')
                if [[ "$ready" == "True" ]]; then
                    echo -e "    ${COLOR_GREEN}✓ ${namespace_cert}/${cert_name}${COLOR_RESET}"
                else
                    echo -e "    ${COLOR_YELLOW}⚠ ${namespace_cert}/${cert_name}${COLOR_RESET}"
                fi
            done
        fi
        echo ""
    fi

    # 4. Available Commands
    log_step "4" "Available Commands"
    echo -e "  ${COLOR_CYAN}cert-manager Management:${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok install cert-manager        # Install cert-manager${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok show cert-manager           # Show this summary${COLOR_RESET}"
    echo -e "    ${COLOR_DIM}gok reset cert-manager          # Reset cert-manager${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BRIGHT_GREEN}📋 Summary Complete${COLOR_RESET}"
    echo ""
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