#!/bin/bash

# GOK Status Command Module - System and component status checking

# Main status command handler
statusCmd() {
    local component="${1:-}"
    
    if [[ "$component" == "help" || "$component" == "--help" ]]; then
        show_status_help
        return 0
    fi
    
    # Check if a specific Helm release status is requested
    if [[ -n "$component" ]] && helm status "$component" >/dev/null 2>&1; then
        log_header "Helm Release Status" "$component"
        helm status "$component"
        return 0
    fi
    
    # Show comprehensive GOK platform status
    show_comprehensive_status
}

# Show status command help
show_status_help() {
    echo "gok status - Check GOK platform and component status"
    echo ""
    echo "Usage: gok status [component]"
    echo ""
    echo "Examples:"
    echo "  gok status                    # Show comprehensive GOK platform status"
    echo "  gok status <helm-release>     # Show specific Helm release status"
    echo ""
    echo "The comprehensive status shows all GOK platform services including:"
    echo "  • Core Infrastructure: ingress, cert-manager, registry, base services"
    echo "  • Security & Identity: kyverno, ldap, keycloak, oauth2, vault"
    echo "  • Monitoring: prometheus, grafana, opensearch, fluentd"
    echo "  • DevOps: jenkins, jupyter, argocd, spinnaker"
    echo "  • Developer Tools: che, workspaces, ttyd, cloudshell"
    echo "  • Platform: kubernetes, docker, gok-agent, gok-controller"
}

# Show comprehensive GOK platform status
show_comprehensive_status() {
    log_header "GOK Platform Status Overview"
    
    # System Overview Section
    log_section "System Overview"
    
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo "unknown")
        log_success "Docker: $docker_version"
    else
        log_error "Docker: Not installed"
    fi
    
    # Check Kubernetes
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl cluster-info >/dev/null 2>&1; then
            log_success "Kubernetes: Cluster is running"
            local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
            log_info "Nodes: $nodes"
        else
            log_error "Kubernetes: Cluster not accessible"
        fi
    else
        log_error "Kubernetes: Not installed"
    fi
    
    # Check Helm
    if command -v helm >/dev/null 2>&1; then
        local helm_version=$(helm version --short 2>/dev/null || echo "unknown")
        log_success "Helm: $helm_version"
        local releases=$(helm list -A --short 2>/dev/null | wc -l || echo "0")
        log_info "Helm releases: $releases"
    else
        log_error "Helm: Not installed"
    fi
    
    echo ""
    
    # Check installed components
    log_section "Installed Components"
    local installed_file="${GOK_CACHE_DIR}/installed_components"
    if [[ -f "$installed_file" ]]; then
        while IFS=':' read -r component timestamp; do
            local install_date=$(date -d "@$timestamp" 2>/dev/null || echo "Unknown")
            log_info "$component: Installed on $install_date"
        done < "$installed_file"
    else
        log_info "No tracked component installations found"
    fi
    
    echo ""
    
    # Core Infrastructure Services (Priority Order)
    log_section "Core Infrastructure Services"
    
    local index=1
    
    # Priority services in specified order
    printf "  %2d. %-15s %s  %s\n" $index "ingress" "$(check_ingress_status)" "NGINX Ingress Controller"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "cert-manager" "$(check_certmanager_status)" "TLS Certificate Management"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "registry" "$(check_registry_status)" "Docker Registry"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "base" "$(check_base_status)" "Base System Components"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "kyverno" "$(check_kyverno_status)" "Policy Engine"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "ldap" "$(check_ldap_status)" "LDAP Directory Service"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "keycloak" "$(check_keycloak_status)" "Identity & Access Management"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "oauth2" "$(check_oauth2_status)" "OAuth2 Proxy"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "rabbitmq" "$(check_rabbitmq_status)" "Message Broker"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "vault" "$(check_vault_status)" "Secrets Management"
    ((index++))
    
    printf "  %2d. %-15s %s  %s\n" $index "gok-login" "$(check_goklogin_status)" "GOK Authentication Service"
    ((index++))
    
    echo ""
    log_section "Additional Services"
    
    # Monitoring & Observability Services
    echo "🔍 Monitoring & Observability:"
    local monitoring_services=(
        "monitoring:prometheus-operator:monitoring:Prometheus/Grafana Monitoring:deployment"
        "opensearch:opensearch-cluster-master:opensearch:OpenSearch Logging:statefulset"
        "fluentd:fluentd:fluentd:Log Collection:deployment"
    )
    
    for service_info in "${monitoring_services[@]}"; do
        IFS=':' read -r service_name deployment_name namespace description resource_type <<< "$service_info"
        if [[ "$resource_type" == "statefulset" ]]; then
            status=$(check_service_status_statefulset "$deployment_name" "$namespace" "$service_name" "statefulset")
        else
            status=$(check_service_status "$deployment_name" "$namespace" "$service_name" "kubectl")
        fi
        printf "  %2d. %-15s %s  %s\n" $index "$service_name" "$status" "$description"
        ((index++))
    done
    
    echo ""
    echo "🚀 Development & CI/CD:"
    local devops_services=(
        "jenkins:jenkins:jenkins:CI/CD Pipeline"
        "jupyter:jupyterhub:jupyterhub:JupyterHub Development"
        "argocd:argocd-server:argocd:GitOps Deployment"
        "spinnaker:spin-deck:spinnaker:Multi-cloud Deployment Platform"
    )
    
    for service_info in "${devops_services[@]}"; do
        IFS=':' read -r service_name deployment_name namespace description <<< "$service_info"
        printf "  %2d. %-15s %s  %s\n" $index "$service_name" "$(check_service_status "$deployment_name" "$namespace" "$service_name" "kubectl")" "$description"
        ((index++))
    done
    
    echo ""
    echo "💻 Developer Tools & IDEs:"
    local dev_tools=(
        "che:che:eclipse-che:Eclipse Che IDE"
        "devworkspace:devworkspace:devworkspace:Developer Workspace (Legacy)"
        "workspace:workspace-v2:workspace:Enhanced Developer Workspace"
        "ttyd:ttyd:ttyd:Terminal over HTTP"
        "cloudshell:cloudshell:cloudshell:Cloud-based Terminal"
        "console:console:console:Web-based Console"
    )
    
    for service_info in "${dev_tools[@]}"; do
        IFS=':' read -r service_name deployment_name namespace description <<< "$service_info"
        printf "  %2d. %-15s %s  %s\n" $index "$service_name" "$(check_service_status "$deployment_name" "$namespace" "$service_name" "kubectl")" "$description"
        ((index++))
    done
    
    echo ""
    echo "🌐 Service Mesh & Management:"
    local mesh_services=(
        "istio:istiod:istio-system:Service Mesh"
        "dashboard:kubernetes-dashboard:kubernetes-dashboard:K8s Dashboard"
        "chart:chartmuseum:chartmuseum:Helm Chart Repository"
    )
    
    for service_info in "${mesh_services[@]}"; do
        IFS=':' read -r service_name deployment_name namespace description <<< "$service_info"
        printf "  %2d. %-15s %s  %s\n" $index "$service_name" "$(check_service_status "$deployment_name" "$namespace" "$service_name" "kubectl")" "$description"
        ((index++))
    done
    
    echo ""
    echo "🏗️ Platform & Infrastructure:"
    local platform_services=(
        "kubernetes:kube-apiserver:kube-system:Kubernetes Control Plane"
        "docker:::Docker Container Runtime"
        "gok-agent:gok-agent:gok-agent:GOK Distributed System Agent"
        "gok-controller:gok-controller:gok-controller:GOK Controller"
        "base-services:::Complete Base Services Stack"
    )
    
    for service_info in "${platform_services[@]}"; do
        IFS=':' read -r service_name deployment_name namespace description <<< "$service_info"
        if [[ "$service_name" == "kubernetes" ]]; then
            # Use kubectl cluster-info for Kubernetes cluster status
            status="$(check_kubernetes_status_simple)"
        elif [[ "$service_name" == "docker" ]]; then
            # Special check for Docker
            if systemctl is-active --quiet docker 2>/dev/null; then
                status="✅"
            else
                status="❌"
            fi
        elif [[ "$service_name" == "base-services" ]]; then
            # Special check for base-services (combination check)
            if [[ "$(check_base_status)" == "✅" ]] && [[ "$(check_ingress_status)" == "✅" ]] && [[ "$(check_certmanager_status)" == "✅" ]]; then
                status="✅"
            elif [[ "$(check_base_status)" == "❌" ]] && [[ "$(check_ingress_status)" == "❌" ]] && [[ "$(check_certmanager_status)" == "❌" ]]; then
                status="❌"
            else
                status="⚠️"
            fi
        else
            status="$(check_service_status "$deployment_name" "$namespace" "$service_name" "kubectl")"
        fi
        printf "  %2d. %-15s %s  %s\n" $index "$service_name" "$status" "$description"
        ((index++))
    done
    
    echo ""
    echo "📍 Status Legend:"
    echo "   ✅ Installed and Running"
    echo "   ⚠️  Installed but Issues Detected"
    echo "   ❌ Not Installed"
    echo ""
    echo "💡 Usage:"
    echo "   gok status                    # Show all services status"
    echo "   gok status <helm-release>     # Show specific Helm release status"
    echo ""
}

# Check specific component status  
check_component_status() {
    local component="$1"
    
    log_section "Component Status: $component"
    
    case "$component" in
        "kubernetes")
            check_kubernetes_status
            ;;
        "docker")
            check_docker_status
            ;;
        "helm")
            check_helm_status
            ;;
        *)
            log_info "Checking generic component: $component"
            check_generic_component_status "$component"
            ;;
    esac
}

# Check Kubernetes status
check_kubernetes_status() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl not found"
        return 1
    fi
    
    # Cluster info
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster is accessible"
        
        # Node status
        log_substep "Nodes:"
        kubectl get nodes --no-headers 2>/dev/null | while read line; do
            local node_name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $2}')
            if [[ "$status" == "Ready" ]]; then
                log_info "  $node_name: $status"
            else
                log_warning "  $node_name: $status"  
            fi
        done
        
        # System pods
        log_substep "System pods:"
        local total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
        local running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep "Running" | wc -l)
        log_info "  Running: $running_pods/$total_pods"
        
    else
        log_error "Cluster is not accessible"
        return 1
    fi
}

# Check Docker status
check_docker_status() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found"
        return 1
    fi
    
    log_success "Docker version: $(docker --version)"
    
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon is running"
        
        # Container stats
        local running=$(docker ps -q 2>/dev/null | wc -l)
        local total=$(docker ps -aq 2>/dev/null | wc -l)
        log_info "Containers: $running running, $total total"
        
        # Image stats  
        local images=$(docker images -q 2>/dev/null | wc -l)
        log_info "Images: $images"
    else
        log_error "Docker daemon is not running"
        return 1
    fi
}

# Check Helm status
check_helm_status() {
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm not found"
        return 1
    fi
    
    log_success "Helm version: $(helm version --short)"
    
    # List releases
    log_substep "Helm releases:"
    if helm list -A --short 2>/dev/null | head -10 | while read release; do
        if [[ -n "$release" ]]; then
            log_info "  $release"
        fi
    done
    then
        local total_releases=$(helm list -A --short 2>/dev/null | wc -l)
        if [[ $total_releases -gt 10 ]]; then
            log_info "  ... and $((total_releases - 10)) more"
        fi
    else
        log_info "  No releases found"
    fi
}

# Check generic component status
check_generic_component_status() {
    local component="$1"
    
    # Check if it's a Helm release
    local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -i "$component" || true)
    
    if [[ -n "$namespaces" ]]; then
        for ns in $namespaces; do
            log_info "Namespace: $ns"
            local pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            local running=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "Running" | wc -l)
            log_substep "Pods in $ns: $running/$pods running"
        done
    else
        log_warning "No namespace found for component: $component"
    fi
}

# Service status checking functions
check_service_status() {
    local deployment="$1"
    local namespace="$2"
    local service_name="$3"
    local check_type="${4:-kubectl}"
    
    if [[ "$check_type" == "helm" ]]; then
        if helm status "$service_name" >/dev/null 2>&1; then
            echo "✅"
        else
            echo "❌"
        fi
    else
        # Check if deployment/statefulset exists and is ready
        if kubectl get deployment "$deployment" -n "$namespace" >/dev/null 2>&1 2>/dev/null; then
            local ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
            if [[ "$ready_replicas" == "$desired_replicas" ]] && [[ "$desired_replicas" -gt 0 ]]; then
                echo "✅"
            elif [[ "$ready_replicas" -gt 0 ]]; then
                echo "⚠️"
            else
                echo "❌"
            fi
        else
            echo "❌"
        fi
    fi
}

check_service_status_statefulset() {
    local statefulset="$1"
    local namespace="$2"
    local service_name="$3"
    local check_type="${4:-kubectl}"
    
    if kubectl get statefulset "$statefulset" -n "$namespace" >/dev/null 2>&1 2>/dev/null; then
        local ready_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
        if [[ "$ready_replicas" == "$desired_replicas" ]] && [[ "$desired_replicas" -gt 0 ]]; then
            echo "✅"
        elif [[ "$ready_replicas" -gt 0 ]]; then
            echo "⚠️"
        else
            echo "❌"
        fi
    else
        echo "❌"
    fi
}

# Component-specific status check functions
check_ingress_status() {
    check_service_status "ingress-nginx-controller" "ingress-nginx" "ingress"
}

check_certmanager_status() {
    check_service_status "cert-manager" "cert-manager" "cert-manager"
}

check_registry_status() {
    check_service_status "registry" "default" "registry"
}

check_base_status() {
    # Check if basic services are running
    if kubectl get pods -n kube-system -l k8s-app=kube-dns >/dev/null 2>&1 2>/dev/null; then
        echo "✅"
    else
        echo "❌"
    fi
}

check_kyverno_status() {
    check_service_status "kyverno" "kyverno" "kyverno"
}

check_ldap_status() {
    check_service_status "ldap" "ldap" "ldap"
}

check_keycloak_status() {
    check_service_status "keycloak" "keycloak" "keycloak"
}

check_oauth2_status() {
    check_service_status "oauth2-proxy" "oauth2" "oauth2"
}

check_rabbitmq_status() {
    check_service_status "rabbitmq" "rabbitmq" "rabbitmq"
}

check_vault_status() {
    check_service_status "vault" "vault" "vault"
}

check_goklogin_status() {
    check_service_status "gok-login" "gok-login" "gok-login"
}

check_kubernetes_status_simple() {
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
    fi
}