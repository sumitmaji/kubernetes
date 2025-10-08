#!/bin/bash

# GOK Validation Module - Input validation and system checks

# Validate component name
validate_component() {
    local component="$1"
    
    # Check if component is provided
    if [[ -z "$component" ]]; then
        log_error "Component name cannot be empty"
        return 1
    fi
    
    # Valid component names (from original gok functionality)
    local valid_components=(
        "docker" "dockerk" "k8s" "helm" "calico" "ingress" "dashboard"
        "heapster" "metric-server" "prometheus-grafana" "cadvisor"
        "registry" "chart-registry" "jenkins" "spinnaker" "vault"
        "ldap" "ldapclient" "kerberos" "kerberizedservices" "keycloak"
        "oauth2-proxy" "cert-manager" "fluentd" "opensearch" "rabbitmq"
        "argocd" "istio" "jupyter" "jupyterhub" "console" "ttyd"
        "eclipseche" "cloud-shell" "gok-cloud" "gok-debug" "gok-login"
        "base" "kb" "service-generator" "scripts" "all"
    )
    
    local found=false
    for valid in "${valid_components[@]}"; do
        if [[ "$component" == "$valid" ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" == false ]]; then
        log_error "Invalid component: $component"
        log_info "Valid components: ${valid_components[*]}"
        return 1
    fi
    
    return 0
}

# Validate namespace name
validate_namespace() {
    local namespace="$1"
    
    if [[ -z "$namespace" ]]; then
        log_error "Namespace cannot be empty"
        return 1
    fi
    
    # Kubernetes namespace naming rules
    if [[ ! "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log_error "Invalid namespace format: $namespace"
        log_info "Namespace must be lowercase alphanumeric with hyphens, start and end with alphanumeric"
        return 1
    fi
    
    if [[ ${#namespace} -gt 63 ]]; then
        log_error "Namespace too long: $namespace (max 63 characters)"
        return 1
    fi
    
    return 0
}

# Validate environment variables
validate_environment() {
    # Skip validation for help commands or if explicitly disabled
    if [[ "$GOK_SKIP_VALIDATION" == "true" ]]; then
        return 0
    fi
    
    local missing_vars=()
    
    # Check required environment variables
    local required_vars=(
        "KUBECTL_PATH"
        "HELM_PATH"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Check if kubectl is accessible
    if [[ ! -x "$KUBECTL_PATH" ]]; then
        log_error "kubectl not found or not executable: $KUBECTL_PATH"
        return 1
    fi
    
    # Check if helm is accessible
    if [[ ! -x "$HELM_PATH" ]]; then
        log_error "Helm not found or not executable: $HELM_PATH"
        return 1
    fi
    
    return 0
}

# Validate file paths
validate_file_path() {
    local file_path="$1"
    local must_exist="${2:-true}"
    
    if [[ -z "$file_path" ]]; then
        log_error "File path cannot be empty"
        return 1
    fi
    
    if [[ "$must_exist" == "true" && ! -f "$file_path" ]]; then
        log_error "File does not exist: $file_path"
        return 1
    fi
    
    # Check if directory exists for the file
    local dir_path=$(dirname "$file_path")
    if [[ ! -d "$dir_path" ]]; then
        log_error "Directory does not exist: $dir_path"
        return 1
    fi
    
    return 0
}

# Validate directory paths
validate_directory_path() {
    local dir_path="$1"
    local must_exist="${2:-true}"
    
    if [[ -z "$dir_path" ]]; then
        log_error "Directory path cannot be empty"
        return 1
    fi
    
    if [[ "$must_exist" == "true" && ! -d "$dir_path" ]]; then
        log_error "Directory does not exist: $dir_path"
        return 1
    fi
    
    return 0
}

# Check system prerequisites
check_system_prerequisites() {
    log_info "Checking system prerequisites..."
    
    local missing_tools=()
    local required_tools=(
        "curl"
        "wget"
        "tar"
        "gzip"
        "git"
        "docker"
    )
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required system tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker ps &> /dev/null; then
        log_warning "Docker daemon is not running or not accessible"
        log_info "Some components may require Docker to be running"
    fi
    
    log_success "System prerequisites check completed"
    return 0
}

# Check Kubernetes cluster connectivity
check_cluster_connectivity() {
    log_info "Checking Kubernetes cluster connectivity..."
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Please check your kubeconfig and cluster status"
        return 1
    fi
    
    # Get cluster version
    local cluster_version=$(kubectl version --short --client=false 2>/dev/null | grep "Server Version" | cut -d: -f2 | xargs)
    if [[ -n "$cluster_version" ]]; then
        log_success "Connected to Kubernetes cluster (version: $cluster_version)"
    else
        log_warning "Connected to cluster but version information unavailable"
    fi
    
    return 0
}

# Validate Helm configuration
validate_helm_config() {
    log_info "Validating Helm configuration..."
    
    # Check if Helm is installed and accessible
    if ! helm version &> /dev/null; then
        log_error "Helm is not accessible"
        return 1
    fi
    
    # Get Helm version
    local helm_version=$(helm version --short --client 2>/dev/null | cut -d: -f2 | xargs)
    if [[ -n "$helm_version" ]]; then
        log_success "Helm is configured (version: $helm_version)"
    else
        log_warning "Helm is accessible but version information unavailable"
    fi
    
    return 0
}

# Check component dependencies
check_component_dependencies() {
    local component="$1"
    
    log_info "Checking dependencies for component: $component"
    
    # Define component dependencies
    declare -A dependencies=(
        ["registry"]="docker"
        ["chart-registry"]="helm"
        ["jenkins"]="ingress"
        ["prometheus-grafana"]="metric-server"
        ["fluentd"]="opensearch"
        ["argocd"]="ingress"
        ["jupyter"]="ingress"
        ["keycloak"]="ingress"
        ["oauth2-proxy"]="keycloak"
    )
    
    # Check if component has dependencies
    local deps="${dependencies[$component]:-}"
    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            if ! is_component_successful "$dep"; then
                log_error "Component $component requires $dep to be installed first"
                return 1
            fi
        done
        log_success "All dependencies satisfied for: $component"
    else
        log_info "No dependencies required for: $component"
    fi
    
    return 0
}