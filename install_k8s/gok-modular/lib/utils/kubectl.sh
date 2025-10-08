#!/bin/bash

# GOK Kubectl Utilities Module - Enhanced kubectl operations

# Execute kubectl operations with log suppression and summary
kubectl_with_summary() {
    local operation="$1"
    local resource_type="${2:-resource}"
    shift 2
    
    local temp_file=$(mktemp)
    local error_file=$(mktemp)
    
    if kubectl "$operation" "$resource_type" "$@" >"$temp_file" 2>"$error_file"; then
        case "$operation" in
            "apply"|"create")
                log_success "Successfully applied $resource_type"
                ;;
            "delete")
                log_success "Successfully deleted $resource_type"
                ;;
            *)
                log_success "Successfully executed kubectl $operation"
                ;;
        esac
        rm -f "$temp_file" "$error_file"
        return 0
    else
        local exit_code=$?
        echo
        echo -e "${COLOR_RED}${COLOR_BOLD}┌─────────────────────────────────────────────────────────────────┐${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}│ ${EMOJI_ERROR} KUBECTL OPERATION FAILED - DEBUGGING INFORMATION${COLOR_RESET}${COLOR_RED}${COLOR_BOLD} │${COLOR_RESET}" >&2
        echo -e "${COLOR_RED}${COLOR_BOLD}└─────────────────────────────────────────────────────────────────┘${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_GEAR} Operation: ${COLOR_WHITE}kubectl $operation${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_PACKAGE} Resource: ${COLOR_WHITE}$resource_type${COLOR_RESET}" >&2
        echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_CROSS} Exit Code: ${COLOR_RED}$exit_code${COLOR_RESET}" >&2
        
        # Show kubectl error details
        if [[ -s "$error_file" ]]; then
            echo -e "${COLOR_RED}${COLOR_BOLD}${EMOJI_ERROR} kubectl Error Details:${COLOR_RESET}" >&2
            echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$error_file" >&2
            echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show kubectl output if available
        if [[ -s "$temp_file" ]]; then
            echo -e "${COLOR_YELLOW}${COLOR_BOLD}${EMOJI_INFO} kubectl Output:${COLOR_RESET}" >&2
            echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
            cat "$temp_file" >&2
            echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════${COLOR_RESET}" >&2
        fi
        
        # Show helpful debugging commands based on operation type
        echo -e "${COLOR_CYAN}${COLOR_BOLD}${EMOJI_TOOLS} Debugging Commands:${COLOR_RESET}" >&2
        case "$operation" in
            "apply"|"create")
                echo -e "  ${COLOR_CYAN}• kubectl get events --sort-by='.lastTimestamp'${COLOR_RESET} ${COLOR_DIM}(recent events)${COLOR_RESET}" >&2
                echo -e "  ${COLOR_CYAN}• kubectl describe $resource_type${COLOR_RESET} ${COLOR_DIM}(resource details)${COLOR_RESET}" >&2
                ;;
            "delete")
                echo -e "  ${COLOR_CYAN}• kubectl get $resource_type${COLOR_RESET} ${COLOR_DIM}(check if still exists)${COLOR_RESET}" >&2
                echo -e "  ${COLOR_CYAN}• kubectl patch $resource_type <name> -p '{\"metadata\":{\"finalizers\":null}}'${COLOR_RESET} ${COLOR_DIM}(force delete)${COLOR_RESET}" >&2
                ;;
            *)
                echo -e "  ${COLOR_CYAN}• kubectl get all -A${COLOR_RESET} ${COLOR_DIM}(check all resources)${COLOR_RESET}" >&2
                echo -e "  ${COLOR_CYAN}• kubectl cluster-info${COLOR_RESET} ${COLOR_DIM}(cluster status)${COLOR_RESET}" >&2
                ;;
        esac
        echo -e "  ${COLOR_CYAN}• kubectl version${COLOR_RESET} ${COLOR_DIM}(check kubectl/cluster versions)${COLOR_RESET}" >&2
        echo
        
        rm -f "$temp_file" "$error_file"
        return $exit_code
    fi
}

# Wait for pods to be ready
wait_for_pods_ready() {
    local namespace="${1:-default}"
    local selector="${2:-}"
    local timeout="${3:-300}"
    
    local selector_args=""
    if [[ -n "$selector" ]]; then
        selector_args="-l $selector"
    fi
    
    log_info "Waiting for pods to be ready in namespace '$namespace'..."
    
    local end_time=$(($(date +%s) + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local pods_status=$(kubectl get pods -n "$namespace" $selector_args -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
        
        if [[ -z "$pods_status" ]]; then
            log_substep "No pods found, waiting..."
            sleep 10
            continue
        fi
        
        local all_ready=true
        for status in $pods_status; do
            if [[ "$status" != "Running" && "$status" != "Succeeded" ]]; then
                all_ready=false
                break
            fi
        done
        
        if [[ "$all_ready" == "true" ]]; then
            log_success "All pods are ready in namespace '$namespace'"
            return 0
        else
            log_substep "Some pods are not ready yet, waiting..."
            sleep 10
        fi
    done
    
    log_error "Timeout waiting for pods to be ready"
    return 1
}

# Get pod by interactive selection
getpod() {
    local pods=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2>/dev/null)
    
    if [[ -z "$pods" ]]; then
        log_error "No pods found in current namespace"
        return 1
    fi
    
    echo "Available pods:"
    local -a pod_array
    local i=1
    while IFS= read -r pod; do
        echo "$i) $pod"
        pod_array[i]="$pod"
        ((i++))
    done <<< "$pods"
    
    read -p "Select pod number: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ -n "${pod_array[$selection]}" ]]; then
        echo "${pod_array[$selection]}"
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Check deployment readiness
check_deployment_readiness() {
    local deployment="$1"
    local namespace="${2:-default}"
    local timeout="${3:-300}"
    
    log_info "Checking readiness of deployment '$deployment'..."
    
    if ! kubectl get deployment "$deployment" -n "$namespace" >/dev/null 2>&1; then
        log_error "Deployment '$deployment' not found in namespace '$namespace'"
        return 1
    fi
    
    if kubectl wait --for=condition=available deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" >/dev/null 2>&1; then
        log_success "Deployment '$deployment' is ready"
        return 0
    else
        log_error "Deployment '$deployment' is not ready after ${timeout}s"
        return 1
    fi
}

# Check statefulset readiness
check_statefulset_readiness() {
    local statefulset="$1"
    local namespace="${2:-default}"
    local timeout="${3:-300}"
    
    log_info "Checking readiness of statefulset '$statefulset'..."
    
    if ! kubectl get statefulset "$statefulset" -n "$namespace" >/dev/null 2>&1; then
        log_error "StatefulSet '$statefulset' not found in namespace '$namespace'"
        return 1
    fi
    
    local end_time=$(($(date +%s) + timeout))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local ready_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready_replicas" -eq "$replicas" ]]; then
            log_success "StatefulSet '$statefulset' is ready ($ready_replicas/$replicas)"
            return 0
        else
            log_substep "StatefulSet readiness: $ready_replicas/$replicas"
            sleep 10
        fi
    done
    
    log_error "StatefulSet '$statefulset' is not ready after ${timeout}s"
    return 1
}

# Check service connectivity
check_service_connectivity() {
    local service="$1"
    local namespace="${2:-default}"
    local port="${3:-80}"
    
    log_info "Checking connectivity to service '$service'..."
    
    if ! kubectl get service "$service" -n "$namespace" >/dev/null 2>&1; then
        log_error "Service '$service' not found in namespace '$namespace'"
        return 1
    fi
    
    local service_ip=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    if [[ -z "$service_ip" || "$service_ip" == "None" ]]; then
        log_warning "Service '$service' has no cluster IP (might be headless)"
        return 0
    fi
    
    # Test connectivity using a temporary pod
    local test_pod_name="connectivity-test-$(date +%s)"
    
    kubectl run "$test_pod_name" --image=curlimages/curl --restart=Never --rm -i --timeout=30s -- \
        sh -c "curl -s --connect-timeout 10 http://${service_ip}:${port} >/dev/null && echo 'SUCCESS' || echo 'FAILED'" 2>/dev/null | grep -q "SUCCESS"
    
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        log_success "Service '$service' is reachable"
        return 0
    else
        log_warning "Service '$service' connectivity test failed"
        return 1
    fi
}

# Apply YAML with validation
kubectl_apply_with_validation() {
    local file="$1"
    local namespace="${2:-}"
    
    if [[ ! -f "$file" ]]; then
        log_error "YAML file not found: $file"
        return 1
    fi
    
    log_info "Validating YAML file: $file"
    
    # First validate the YAML syntax
    if ! kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
        log_error "YAML validation failed for: $file"
        return 1
    fi
    
    # Apply the YAML
    local kubectl_args=("-f" "$file")
    if [[ -n "$namespace" ]]; then
        kubectl_args+=("-n" "$namespace")
    fi
    
    kubectl_with_summary "apply" "resource" "${kubectl_args[@]}"
}

# Create namespace if it doesn't exist
ensure_namespace() {
    local namespace="$1"
    
    if [[ -z "$namespace" || "$namespace" == "default" ]]; then
        return 0
    fi
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_info "Namespace '$namespace' already exists"
        return 0
    fi
    
    log_info "Creating namespace: $namespace"
    kubectl create namespace "$namespace" >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_success "Namespace '$namespace' created successfully"
        return 0
    else
        log_error "Failed to create namespace: $namespace"
        return 1
    fi
}