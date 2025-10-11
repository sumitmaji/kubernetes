#!/bin/bash

# GOK Helm Utilities Module - Helm operations with enhanced logging and error handling

# Execute helm install with log suppression and summary
helm_install_with_summary() {
    local component="$1"
    local namespace="${2:-default}"
    shift 2
    
    log_info "Installing $component via Helm..."
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    local start_time=$(date +%s)
    
    # Use spinner for helm install command
    if execute_with_spinner "Installing $component via Helm" helm install "$@" >"$temp_file" 2>"$error_file"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Extract useful information from output
        local release_info=$(grep -E "NAME:|NAMESPACE:|STATUS:|REVISION:" "$temp_file" 2>/dev/null || echo "")
        
        # Success message already shown by spinner, just show summary
        echo -e "${COLOR_CYAN}${COLOR_BOLD}📋 Installation Summary:${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Component: ${COLOR_BOLD}$component${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Duration: ${COLOR_BOLD}${duration}s${COLOR_RESET}"
        if [[ -n "$release_info" ]]; then
            echo -e "  ${COLOR_GREEN}• Release Info:${COLOR_RESET}"
            echo "$release_info" | sed 's/^/    /'
        fi
        
        rm -f "$temp_file" "$error_file"
        return 0
    else
        local exit_code=$?
        echo
        echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}│ ${EMOJI_ERROR} HELM INSTALLATION FAILED - DEBUGGING INFORMATION${COLOR_RESET}${COLOR_RED}${COLOR_BOLD} │${COLOR_RESET}" >&2  
        echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_PACKAGE} Component: ${COLOR_WHITE}$component${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_NETWORK} Namespace: ${COLOR_WHITE}$namespace${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_CROSS} Exit Code: ${COLOR_RED}$exit_code${COLOR_RESET}" >&2
        
        # Show Helm-specific error details
        if [[ -s "$error_file" ]]; then
            echo -e "${COLOR_RED}${COLOR_BOLD}${EMOJI_ERROR} Helm Error Details:${COLOR_RESET}" >&2
            echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$error_file" >&2
            echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show full Helm output for debugging
        if [[ -s "$temp_file" ]]; then
            echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_INFO} Full Helm Output:${COLOR_RESET}" >&2
            echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$temp_file" >&2
            echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show helpful debugging commands
        echo -e "${COLOR_CYAN}${COLOR_BOLD}${EMOJI_TOOLS} Debugging Commands:${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• helm list -A${COLOR_RESET} ${COLOR_DIM}(check all releases)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• helm status $component -n $namespace${COLOR_RESET} ${COLOR_DIM}(check release status)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• kubectl get pods -n $namespace${COLOR_RESET} ${COLOR_DIM}(check pods)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• kubectl describe pods -n $namespace${COLOR_RESET} ${COLOR_DIM}(pod details)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• kubectl logs -n $namespace -l app=$component${COLOR_RESET} ${COLOR_DIM}(application logs)${COLOR_RESET}" >&2
        echo
        
        rm -f "$temp_file" "$error_file"
        return $exit_code
    fi
}

# Execute helm uninstall with log suppression and summary
helm_uninstall_with_summary() {
    local component="$1"
    local namespace="${2:-default}"
    shift 2
    
    log_info "Uninstalling $component via Helm..."
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    if helm uninstall "$@" >"$temp_file" 2>"$error_file"; then
        log_success "Helm uninstallation completed for $component"
        echo -e "${COLOR_CYAN}${COLOR_BOLD}📋 Uninstallation Summary:${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Component: ${COLOR_BOLD}$component${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Namespace: ${COLOR_BOLD}$namespace${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}• Status: ${COLOR_BOLD}Successfully removed${COLOR_RESET}"
        
        rm -f "$temp_file" "$error_file"
        return 0
    else
        local exit_code=$?
        echo
        echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}│ ${EMOJI_ERROR} HELM UNINSTALLATION FAILED - DEBUGGING INFORMATION ${COLOR_RESET}${COLOR_RED}${COLOR_BOLD}│${COLOR_RESET}" >&2  
        echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_PACKAGE} Component: ${COLOR_WHITE}$component${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_NETWORK} Namespace: ${COLOR_WHITE}$namespace${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_CROSS} Exit Code: ${COLOR_RED}$exit_code${COLOR_RESET}" >&2
        
        # Show Helm uninstall error details
        if [[ -s "$error_file" ]]; then
            echo -e "${COLOR_RED}${COLOR_BOLD}${EMOJI_ERROR} Helm Error Details:${COLOR_RESET}" >&2
            echo -e "${COLOR_RED}══════════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$error_file" >&2
            echo -e "${COLOR_RED}══════════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show Helm output if available
        if [[ -s "$temp_file" ]]; then
            echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_INFO} Helm Output:${COLOR_RESET}" >&2
            echo -e "${COLOR_YELLOW}══════════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$temp_file" >&2
            echo -e "${COLOR_YELLOW}══════════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show helpful debugging commands for uninstallation issues
        echo -e "${COLOR_CYAN}${COLOR_BOLD}${EMOJI_TOOLS} Debugging Commands:${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• helm list -A${COLOR_RESET} ${COLOR_DIM}(check all releases)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• helm status $component -n $namespace${COLOR_RESET} ${COLOR_DIM}(check release status)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• kubectl get all -n $namespace${COLOR_RESET} ${COLOR_DIM}(check remaining resources)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• kubectl delete namespace $namespace --force --grace-period=0${COLOR_RESET} ${COLOR_DIM}(force namespace deletion)${COLOR_RESET}" >&2
        echo -e "  ${COLOR_CYAN}• helm uninstall $component -n $namespace --no-hooks${COLOR_RESET} ${COLOR_DIM}(skip hooks)${COLOR_RESET}" >&2
        echo
        
        rm -f "$temp_file" "$error_file"
        return $exit_code
    fi
}

# Add or update Helm repository
helm_add_repo() {
    local name="$1"
    local url="$2"
    
    if [[ -z "$name" || -z "$url" ]]; then
        log_error "helm_add_repo requires name and URL"
        return 1
    fi
    
    log_info "Adding Helm repository: $name"
    
    if helm repo add "$name" "$url" 2>/dev/null; then
        log_success "Helm repository '$name' added successfully"
    else
        log_warning "Failed to add repository '$name', it might already exist"
    fi
    
    # Update repositories
    helm repo update >/dev/null 2>&1 || true
}

# Wait for Helm release to be ready
wait_for_helm_release() {
    local release="$1"
    local namespace="${2:-default}"
    local timeout="${3:-300}"
    
    log_info "Waiting for Helm release '$release' to be ready..."
    
    local end_time=$(($(date +%s) + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local status=$(helm status "$release" -n "$namespace" -o json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "unknown")
        
        case "$status" in
            "deployed")
                log_success "Helm release '$release' is ready"
                return 0
                ;;
            "failed")
                log_error "Helm release '$release' failed"
                return 1
                ;;
            "pending-install"|"pending-upgrade")
                log_substep "Release status: $status, waiting..."
                sleep 10
                ;;
            *)
                log_substep "Unknown status: $status, waiting..."
                sleep 10
                ;;
        esac
    done
    
    log_error "Timeout waiting for Helm release '$release'"
    return 1
}

# Get Helm release status
get_helm_release_status() {
    local release="$1"
    local namespace="${2:-default}"
    
    helm status "$release" -n "$namespace" -o json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "not-found"
}

# Check if Helm release exists
helm_release_exists() {
    local release="$1"
    local namespace="${2:-default}"
    
    helm list -n "$namespace" -q 2>/dev/null | grep -q "^${release}$"
}

# Helm template with validation
helm_template_with_validation() {
    local release="$1"
    local chart="$2"
    shift 2
    
    log_info "Generating and validating Helm templates for $release..."
    
    local temp_dir=$(mktemp -d)
    
    if helm template "$release" "$chart" "$@" --output-dir "$temp_dir" 2>/dev/null; then
        # Validate generated YAML files
        local valid=true
        for yaml_file in $(find "$temp_dir" -name "*.yaml" -type f); do
            if ! kubectl apply --dry-run=client -f "$yaml_file" >/dev/null 2>&1; then
                log_warning "Invalid YAML template: $(basename "$yaml_file")"
                valid=false
            fi
        done
        
        if [[ "$valid" == "true" ]]; then
            log_success "Helm templates validated successfully"
        else
            log_warning "Some templates failed validation"
        fi
        
        rm -rf "$temp_dir"
        return 0
    else
        log_error "Failed to generate Helm templates"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Install Helm chart with common repositories
helmInst() {
    log_info "Installing Helm package manager..."
    
    # Add common Helm repositories
    local repos=(
        "bitnami:https://charts.bitnami.com/bitnami"
        "prometheus-community:https://prometheus-community.github.io/helm-charts"
        "ingress-nginx:https://kubernetes.github.io/ingress-nginx"
        "jetstack:https://charts.jetstack.io"
        "elastic:https://helm.elastic.co"
        "grafana:https://grafana.github.io/helm-charts"
    )
    
    for repo in "${repos[@]}"; do
        local name="${repo%%:*}"
        local url="${repo#*:}"
        helm_add_repo "$name" "$url"
    done
    
    log_success "Helm installation and repository setup completed"
}