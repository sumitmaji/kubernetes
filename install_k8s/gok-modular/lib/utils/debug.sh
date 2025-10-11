#!/bin/bash

# GOK Kubernetes Debugging Utilities
# Enhanced debugging helpers based on install_k8s/util with modern Kubernetes tooling

# Initialize debug session with context
debug_init() {
    log_info "🐛 Initializing Kubernetes debugging session"
    
    # Set default namespace if not provided
    local current_ns=$(kubectl config get-contexts --no-headers | grep '^\*' | awk '{print $5}')
    export DEBUG_NAMESPACE="${current_ns:-default}"
    
    # Store current context
    export DEBUG_CONTEXT=$(kubectl config current-context 2>/dev/null)
    
    log_info "Debug context: $DEBUG_CONTEXT"
    log_info "Debug namespace: $DEBUG_NAMESPACE"
    
    # Show cluster info
    kubectl cluster-info --request-timeout=5s 2>/dev/null || log_warning "Cluster info unavailable"
}

# Enhanced namespace switching with validation
gcd() {
    local namespace="$1"
    
    if [[ -z "$namespace" ]]; then
        log_info "📂 Available namespaces:"
        local namespaces=$(kubectl get ns --no-headers 2>/dev/null | awk '{printf "%d>> %s (%s)\n", NR, $1, $2}')
        
        if [[ -z "$namespaces" ]]; then
            log_error "No namespaces found or cluster unreachable"
            return 1
        fi
        
        echo "$namespaces"
        echo
        read -p "Enter namespace index or name: " selection
        
        # Check if selection is a number (index) or name
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            namespace=$(echo "$namespaces" | grep "^${selection}>>" | awk '{print $2}')
        else
            namespace="$selection"
        fi
        
        if [[ -z "$namespace" ]]; then
            log_error "Invalid selection"
            return 1
        fi
    fi
    
    # Validate namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_error "Namespace '$namespace' not found"
        return 1
    fi
    
    # Switch namespace context
    kubectl config set-context --current --namespace="$namespace" >/dev/null 2>&1
    export DEBUG_NAMESPACE="$namespace"
    
    log_success "🔄 Switched to namespace: $namespace"
    
    # Show quick namespace summary
    local pod_count=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
    local svc_count=$(kubectl get services --no-headers 2>/dev/null | wc -l)
    local ing_count=$(kubectl get ingress --no-headers 2>/dev/null | wc -l)
    
    echo "  📊 Resources: ${pod_count} pods, ${svc_count} services, ${ing_count} ingress"
}

# Enhanced pod selection with better formatting
select_pod_container() {
    local action_name="${1:-operation}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    log_info "🔍 Scanning pods in namespace: $namespace"
    
    # Get pods with enhanced information
    local pods_info=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | \
        awk '{printf "%s|%s|%s|%s\n", $1, $2, $3, $4}')
    
    if [[ -z "$pods_info" ]]; then
        log_error "No pods found in namespace $namespace"
        return 1
    fi
    
    log_info "📋 Available pods:"
    echo
    printf "%-4s %-30s %-12s %-12s %-8s\n" "Idx" "Pod Name" "Ready" "Status" "Age"
    printf "%-4s %-30s %-12s %-12s %-8s\n" "---" "--------" "-----" "------" "---"
    
    local pod_index=1
    local pod_data=""
    
    while IFS='|' read -r pod_name ready status age; do
        # Color code based on status
        local status_color=""
        case "$status" in
            "Running") status_color="$COLOR_GREEN" ;;
            "Pending") status_color="$COLOR_YELLOW" ;;
            "Failed"|"Error"|"CrashLoopBackOff") status_color="$COLOR_RED" ;;
            *) status_color="$COLOR_DIM" ;;
        esac
        
        printf "${COLOR_CYAN}%-4s${COLOR_RESET} %-30s ${status_color}%-12s${COLOR_RESET} %-12s %-8s\n" \
            "$pod_index>>" "$pod_name" "$ready" "$status" "$age"
        
        pod_data="${pod_data}${pod_index}|${pod_name}\n"
        pod_index=$((pod_index + 1))
    done <<< "$pods_info"
    
    echo
    read -p "Enter pod index: " pod_index
    
    if ! [[ "$pod_index" =~ ^[0-9]+$ ]]; then
        log_error "Invalid pod index"
        return 1
    fi
    
    local selected_pod=$(echo -e "$pod_data" | grep "^${pod_index}|" | cut -d'|' -f2)
    if [[ -z "$selected_pod" ]]; then
        log_error "Invalid pod selection"
        return 1
    fi
    
    # Get containers for selected pod
    log_info "📦 Containers in pod: $selected_pod"
    
    local containers=$(kubectl get pod "$selected_pod" -n "$namespace" \
        -o jsonpath='{range .spec.initContainers[*]}{.name}{"|init"}{"\n"}{end}{range .spec.containers[*]}{.name}{"|main"}{"\n"}{end}' 2>/dev/null)
    
    if [[ -z "$containers" ]]; then
        log_error "No containers found in pod $selected_pod"
        return 1
    fi
    
    echo
    printf "%-4s %-25s %-8s\n" "Idx" "Container Name" "Type"
    printf "%-4s %-25s %-8s\n" "---" "--------------" "----"
    
    local container_index=1
    local container_data=""
    
    while IFS='|' read -r container_name container_type; do
        local type_color="$COLOR_GREEN"
        [[ "$container_type" == "init" ]] && type_color="$COLOR_YELLOW"
        
        printf "${COLOR_CYAN}%-4s${COLOR_RESET} %-25s ${type_color}%-8s${COLOR_RESET}\n" \
            "$container_index>>" "$container_name" "$container_type"
        
        container_data="${container_data}${container_index}|${container_name}\n"
        container_index=$((container_index + 1))
    done <<< "$containers"
    
    echo
    read -p "Enter container index: " container_index
    
    if ! [[ "$container_index" =~ ^[0-9]+$ ]]; then
        log_error "Invalid container index"
        return 1
    fi
    
    local selected_container=$(echo -e "$container_data" | grep "^${container_index}|" | cut -d'|' -f2)
    if [[ -z "$selected_container" ]]; then
        log_error "Invalid container selection"
        return 1
    fi
    
    # Export selection for use by calling function
    export DEBUG_SELECTED_POD="$selected_pod"
    export DEBUG_SELECTED_CONTAINER="$selected_container"
    
    log_success "✅ Selected: pod/$selected_pod, container/$selected_container"
}

# Enhanced logs viewer with multiple options
glogs() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    # Support direct pod/container specification
    if [[ -n "$1" && -n "$2" ]]; then
        export DEBUG_SELECTED_POD="$1"
        export DEBUG_SELECTED_CONTAINER="$2"
    else
        select_pod_container "view logs" || return 1
    fi
    
    local pod="$DEBUG_SELECTED_POD"
    local container="$DEBUG_SELECTED_CONTAINER"
    
    log_info "📜 Log viewing options for $pod/$container:"
    echo
    echo "1>> Recent logs (last 100 lines)"
    echo "2>> Follow logs (real-time)"
    echo "3>> Previous container logs"
    echo "4>> Logs with timestamps"
    echo "5>> Logs since time (e.g., 1h, 30m, 2h)"
    echo "6>> All logs"
    echo
    
    read -p "Select option [1-6]: " log_option
    
    local kubectl_cmd="kubectl logs $pod -n $namespace -c $container"
    
    case "$log_option" in
        1)
            log_info "📄 Showing recent logs (last 100 lines)..."
            $kubectl_cmd --tail=100
            ;;
        2)
            log_info "🔄 Following logs (Press Ctrl+C to stop)..."
            $kubectl_cmd --follow
            ;;
        3)
            log_info "⏮️ Showing previous container logs..."
            $kubectl_cmd --previous 2>/dev/null || log_error "No previous container found"
            ;;
        4)
            log_info "🕒 Showing logs with timestamps..."
            $kubectl_cmd --timestamps --tail=100
            ;;
        5)
            read -p "Enter time duration (e.g., 1h, 30m): " duration
            log_info "⏰ Showing logs since $duration..."
            $kubectl_cmd --since="$duration"
            ;;
        6)
            log_info "📚 Showing all logs..."
            $kubectl_cmd
            ;;
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
}

# Enhanced tail with multiple pods support
gtail() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    if [[ "$1" == "--all" ]]; then
        log_info "🔄 Tailing logs from all pods in namespace $namespace..."
        
        # Get all pods and tail their logs
        local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | \
            grep -E "(Running|ContainerCreating)" | awk '{print $1}')
        
        if [[ -z "$pods" ]]; then
            log_error "No running pods found"
            return 1
        fi
        
        # Use kubectl logs with label selector if available, otherwise stern-like approach
        log_info "📋 Tailing logs from pods: $(echo $pods | tr '\n' ' ')"
        
        # Simple multi-pod tail (basic version)
        for pod in $pods; do
            echo "=== Starting logs for $pod ==="
            kubectl logs "$pod" -n "$namespace" --follow --tail=10 &
        done
        
        wait
    else
        # Single pod selection
        select_pod_container "tail logs" || return 1
        
        local pod="$DEBUG_SELECTED_POD"
        local container="$DEBUG_SELECTED_CONTAINER"
        
        log_info "🔄 Tailing logs for $pod/$container (Press Ctrl+C to stop)..."
        kubectl logs "$pod" -n "$namespace" -c "$container" --follow --tail=50
    fi
}

# Enhanced watch with multiple resource types
gwatch() {
    local resource_type="$1"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    if [[ -z "$resource_type" ]]; then
        log_info "🔍 Available resources to watch:"
        echo
        echo "1>> pods (default)"
        echo "2>> services"
        echo "3>> deployments"
        echo "4>> ingress"
        echo "5>> events"
        echo "6>> all resources"
        echo "7>> custom resource type"
        echo
        
        read -p "Select resource type [1-7]: " selection
        
        case "$selection" in
            1|"") resource_type="pods" ;;
            2) resource_type="services" ;;
            3) resource_type="deployments" ;;
            4) resource_type="ingress" ;;
            5) resource_type="events" ;;
            6) resource_type="all" ;;
            7) 
                read -p "Enter resource type: " resource_type
                if [[ -z "$resource_type" ]]; then
                    log_error "Resource type cannot be empty"
                    return 1
                fi
                ;;
            *)
                log_error "Invalid selection"
                return 1
                ;;
        esac
    fi
    
    log_info "👀 Watching $resource_type in namespace $namespace (Press Ctrl+C to stop)..."
    echo
    
    case "$resource_type" in
        "events")
            kubectl get events -n "$namespace" --watch --sort-by='.lastTimestamp'
            ;;
        "all")
            kubectl get all -n "$namespace" --watch
            ;;
        *)
            kubectl get "$resource_type" -n "$namespace" --watch
            ;;
    esac
}

# Enhanced bash shell with better selection
gbash() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    select_pod_container "open shell" || return 1
    
    local pod="$DEBUG_SELECTED_POD"
    local container="$DEBUG_SELECTED_CONTAINER"
    
    log_info "🐚 Available shells to try:"
    echo "1>> /bin/bash"
    echo "2>> /bin/sh"
    echo "3>> /bin/zsh"
    echo "4>> Custom command"
    echo
    
    read -p "Select shell [1-4] (default: bash): " shell_option
    
    local shell_cmd
    case "$shell_option" in
        1|"") shell_cmd="/bin/bash" ;;
        2) shell_cmd="/bin/sh" ;;
        3) shell_cmd="/bin/zsh" ;;
        4) 
            read -p "Enter custom command: " shell_cmd
            if [[ -z "$shell_cmd" ]]; then
                log_error "Command cannot be empty"
                return 1
            fi
            ;;
        *)
            log_error "Invalid selection"
            return 1
            ;;
    esac
    
    log_info "🚀 Opening $shell_cmd in $pod/$container..."
    echo "💡 Tip: Type 'exit' to return to your host shell"
    echo
    
    kubectl exec -it "$pod" -n "$namespace" -c "$container" -- "$shell_cmd"
}

# Enhanced describe with better formatting
gdesc() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    if [[ -z "$resource_type" ]]; then
        log_info "📋 Common resource types:"
        echo
        echo "1>> pod"
        echo "2>> service"
        echo "3>> deployment"
        echo "4>> ingress"
        echo "5>> secret"
        echo "6>> configmap"
        echo "7>> pvc (PersistentVolumeClaim)"
        echo "8>> node"
        echo
        
        read -p "Select resource type [1-8]: " selection
        
        case "$selection" in
            1) resource_type="pod" ;;
            2) resource_type="service" ;;
            3) resource_type="deployment" ;;
            4) resource_type="ingress" ;;
            5) resource_type="secret" ;;
            6) resource_type="configmap" ;;
            7) resource_type="pvc" ;;
            8) resource_type="node" ;;
            *)
                log_error "Invalid selection"
                return 1
                ;;
        esac
    fi
    
    # If resource name not provided, show list to select from
    if [[ -z "$resource_name" ]]; then
        local ns_flag=""
        [[ "$resource_type" != "node" ]] && ns_flag="-n $namespace"
        
        local resources=$(kubectl get "$resource_type" $ns_flag --no-headers 2>/dev/null | \
            awk '{printf "%d>> %s (%s)\n", NR, $1, $3}')
        
        if [[ -z "$resources" ]]; then
            log_error "No $resource_type resources found"
            return 1
        fi
        
        log_info "📂 Available $resource_type resources:"
        echo "$resources"
        echo
        
        read -p "Enter resource index or name: " selection
        
        # Check if selection is a number (index) or name
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            resource_name=$(echo "$resources" | grep "^${selection}>>" | awk '{print $2}')
        else
            resource_name="$selection"
        fi
        
        if [[ -z "$resource_name" ]]; then
            log_error "Invalid selection"
            return 1
        fi
    fi
    
    log_info "📊 Describing $resource_type/$resource_name..."
    echo
    
    local ns_flag=""
    [[ "$resource_type" != "node" ]] && ns_flag="-n $namespace"
    
    kubectl describe "$resource_type" "$resource_name" $ns_flag
}

# Enhanced secret decoder with better interface
gdecode() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    log_info "🔐 Available secrets in namespace $namespace:"
    
    local secrets_info=$(kubectl get secrets -n "$namespace" --no-headers 2>/dev/null | \
        awk '{printf "%d>> %s (%s) - %s\n", NR, $1, $2, $3}')
    
    if [[ -z "$secrets_info" ]]; then
        log_error "No secrets found in namespace $namespace"
        return 1
    fi
    
    echo "$secrets_info"
    echo
    
    read -p "Enter secret index: " secret_index
    
    if ! [[ "$secret_index" =~ ^[0-9]+$ ]]; then
        log_error "Invalid secret index"
        return 1
    fi
    
    local secret_name=$(echo "$secrets_info" | grep "^${secret_index}>>" | awk '{print $2}')
    if [[ -z "$secret_name" ]]; then
        log_error "Invalid secret selection"
        return 1
    fi
    
    # Get secret data keys
    local data_keys=$(kubectl get secret "$secret_name" -n "$namespace" \
        -o jsonpath='{.data}' 2>/dev/null | jq -r 'keys[]' 2>/dev/null)
    
    if [[ -z "$data_keys" ]]; then
        log_error "No data found in secret $secret_name"
        return 1
    fi
    
    log_info "🗝️  Available data keys in secret $secret_name:"
    echo
    
    local key_index=1
    local key_data=""
    
    while read -r key; do
        echo "${key_index}>> $key"
        key_data="${key_data}${key_index}|${key}\n"
        key_index=$((key_index + 1))
    done <<< "$data_keys"
    
    echo
    read -p "Enter key index: " key_selection
    
    if ! [[ "$key_selection" =~ ^[0-9]+$ ]]; then
        log_error "Invalid key index"
        return 1
    fi
    
    local selected_key=$(echo -e "$key_data" | grep "^${key_selection}|" | cut -d'|' -f2)
    if [[ -z "$selected_key" ]]; then
        log_error "Invalid key selection"
        return 1
    fi
    
    log_info "📄 Decoding $secret_name/$selected_key..."
    echo
    
    local decoded_value=$(kubectl get secret "$secret_name" -n "$namespace" \
        -o jsonpath="{.data.${selected_key}}" 2>/dev/null | base64 -d 2>/dev/null)
    
    if [[ -z "$decoded_value" ]]; then
        log_error "Failed to decode secret value"
        return 1
    fi
    
    # Check if it looks like a certificate
    if echo "$decoded_value" | grep -q "BEGIN CERTIFICATE"; then
        echo "🔒 Certificate detected - showing certificate details:"
        echo
        echo "$decoded_value" | openssl x509 -text -noout 2>/dev/null || echo "$decoded_value"
    else
        echo "📋 Decoded value:"
        echo "$decoded_value"
    fi
}

# Enhanced port forwarding with service discovery
gforward() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    local service_name="$1"
    local local_port="$2"
    local remote_port="$3"
    
    if [[ -z "$service_name" ]]; then
        log_info "🌐 Available services in namespace $namespace:"
        
        local services=$(kubectl get services -n "$namespace" --no-headers 2>/dev/null | \
            awk '{printf "%d>> %s (%s:%s)\n", NR, $1, $3, $5}')
        
        if [[ -z "$services" ]]; then
            log_error "No services found in namespace $namespace"
            return 1
        fi
        
        echo "$services"
        echo
        
        read -p "Enter service index: " service_index
        
        if ! [[ "$service_index" =~ ^[0-9]+$ ]]; then
            log_error "Invalid service index"
            return 1
        fi
        
        service_name=$(echo "$services" | grep "^${service_index}>>" | awk '{print $2}')
        if [[ -z "$service_name" ]]; then
            log_error "Invalid service selection"
            return 1
        fi
        
        # Get service ports
        local ports=$(kubectl get service "$service_name" -n "$namespace" \
            -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)
        
        echo "📡 Available ports for service $service_name: $ports"
        
        if [[ -z "$remote_port" ]]; then
            read -p "Enter remote port: " remote_port
        fi
        
        if [[ -z "$local_port" ]]; then
            read -p "Enter local port (default: $remote_port): " local_port
            local_port="${local_port:-$remote_port}"
        fi
    fi
    
    log_info "🔄 Port forwarding: localhost:$local_port -> $service_name:$remote_port"
    log_info "💡 Access the service at: http://localhost:$local_port"
    log_info "⏹️  Press Ctrl+C to stop forwarding"
    echo
    
    kubectl port-forward service/"$service_name" -n "$namespace" "$local_port:$remote_port"
}

# Enhanced cluster debugging with system checks
gcluster() {
    local action="${1:-status}"
    
    case "$action" in
        "status"|"info")
            log_info "🏥 Cluster Health Overview"
            echo
            
            # Cluster info
            log_substep "📊 Cluster Information:"
            kubectl cluster-info --request-timeout=10s 2>/dev/null || log_error "Cluster unreachable"
            echo
            
            # Node status
            log_substep "🖥️  Node Status:"
            kubectl get nodes -o wide 2>/dev/null || log_error "Cannot get node status"
            echo
            
            # System pods
            log_substep "🔧 System Pods (kube-system):"
            kubectl get pods -n kube-system --no-headers 2>/dev/null | \
                awk '{printf "%-30s %s\n", $1, $3}' | column -t || log_error "Cannot get system pods"
            echo
            
            # Resource usage
            log_substep "💾 Resource Usage:"
            kubectl top nodes 2>/dev/null || log_info "Metrics server not available"
            ;;
        "events")
            log_info "📰 Recent Cluster Events"
            kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
            ;;
        "namespaces")
            log_info "📂 Namespace Overview"
            kubectl get namespaces -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp" --sort-by='.metadata.name'
            ;;
        "storage")
            log_info "💾 Storage Overview"
            echo
            log_substep "Persistent Volumes:"
            kubectl get pv 2>/dev/null || log_info "No persistent volumes"
            echo
            log_substep "Storage Classes:"
            kubectl get storageclass 2>/dev/null || log_info "No storage classes"
            ;;
        *)
            log_info "🏥 Cluster debugging commands:"
            echo "  gcluster status     - Cluster health overview"
            echo "  gcluster events     - Recent cluster events"
            echo "  gcluster namespaces - Namespace overview" 
            echo "  gcluster storage    - Storage overview"
            ;;
    esac
}

# Enhanced resource monitoring
gresources() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    local resource_type="${1:-pods}"
    
    case "$resource_type" in
        "pods")
            log_info "📊 Pod Resource Usage in namespace: $namespace"
            kubectl top pods -n "$namespace" 2>/dev/null || log_warning "Metrics server unavailable"
            ;;
        "nodes")
            log_info "🖥️  Node Resource Usage"
            kubectl top nodes 2>/dev/null || log_warning "Metrics server unavailable"
            ;;
        "summary")
            log_info "📈 Resource Summary"
            echo
            log_substep "Node Resources:"
            kubectl top nodes 2>/dev/null || log_warning "Node metrics unavailable"
            echo
            log_substep "Pod Resources (namespace: $namespace):"
            kubectl top pods -n "$namespace" 2>/dev/null || log_warning "Pod metrics unavailable"
            ;;
        *)
            log_info "📊 Available resource monitoring:"
            echo "  gresources pods    - Pod resource usage"
            echo "  gresources nodes   - Node resource usage"
            echo "  gresources summary - Complete resource summary"
            ;;
    esac
}

# Network debugging utilities
gnetwork() {
    local action="${1:-status}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "services")
            log_info "🌐 Network Services in namespace: $namespace"
            kubectl get services -n "$namespace" -o wide
            ;;
        "endpoints")
            log_info "🔗 Service Endpoints in namespace: $namespace"
            kubectl get endpoints -n "$namespace"
            ;;
        "ingress")
            log_info "🚪 Ingress Resources in namespace: $namespace"
            kubectl get ingress -n "$namespace" -o wide
            ;;
        "dns")
            log_info "🌍 DNS Debugging"
            echo
            log_substep "Testing DNS resolution from dnsutils pod..."
            
            # Check if dnsutils pod exists
            if kubectl get pod dnsutils -n default >/dev/null 2>&1; then
                echo "Testing kubernetes service resolution:"
                kubectl exec dnsutils -n default -- nslookup kubernetes.default.svc.cluster.local
                echo
                echo "Testing external DNS:"
                kubectl exec dnsutils -n default -- nslookup google.com
            else
                log_warning "dnsutils pod not found. Creating temporary pod..."
                kubectl run dnsutils-temp --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
            fi
            ;;
        "connectivity")
            log_info "🔌 Network Connectivity Test"
            
            # Create a temporary pod for connectivity testing
            log_substep "Creating temporary network test pod..."
            kubectl run nettest-temp --image=busybox:1.28 --rm -it --restart=Never -- /bin/sh -c "
                echo 'Testing internal connectivity...'
                wget -qO- --timeout=5 kubernetes.default.svc.cluster.local:443 >/dev/null 2>&1 && echo '✅ Kubernetes API reachable' || echo '❌ Kubernetes API unreachable'
                echo 'Testing external connectivity...'
                wget -qO- --timeout=5 google.com >/dev/null 2>&1 && echo '✅ External connectivity OK' || echo '❌ External connectivity failed'
            "
            ;;
        *)
            log_info "🌐 Network debugging commands:"
            echo "  gnetwork services     - List services"
            echo "  gnetwork endpoints    - List service endpoints"
            echo "  gnetwork ingress      - List ingress resources"
            echo "  gnetwork dns         - Test DNS resolution"
            echo "  gnetwork connectivity - Test network connectivity"
            ;;
    esac
}

# Configuration and troubleshooting
gtroubleshoot() {
    local component="${1:-all}"
    
    case "$component" in
        "pods")
            log_info "🩺 Pod Troubleshooting"
            echo
            
            # Failed pods
            log_substep "Failed Pods:"
            local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null)
            if [[ -n "$failed_pods" ]]; then
                echo "$failed_pods"
            else
                echo "No failed pods found"
            fi
            echo
            
            # Pending pods
            log_substep "Pending Pods:"
            local pending_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null)
            if [[ -n "$pending_pods" ]]; then
                echo "$pending_pods"
            else
                echo "No pending pods found"
            fi
            echo
            
            # Pods with restarts
            log_substep "Pods with High Restart Count (>5):"
            kubectl get pods --all-namespaces --no-headers 2>/dev/null | awk '$5 > 5 {print $0}' | head -10
            ;;
        "nodes")
            log_info "🖥️  Node Troubleshooting"
            echo
            
            # Node conditions
            log_substep "Node Conditions:"
            kubectl describe nodes | grep -E "(Name:|Conditions:|Ready|OutOfDisk|MemoryPressure|DiskPressure)" | head -20
            ;;
        "storage")
            log_info "💾 Storage Troubleshooting"
            echo
            
            # PVC status
            log_substep "PVC Status:"
            kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -v "Bound" | head -10
            ;;
        "all"|*)
            log_info "🔧 Complete Cluster Troubleshooting"
            echo
            
            gtroubleshoot "pods"
            echo
            gtroubleshoot "nodes" 
            echo
            gtroubleshoot "storage"
            ;;
    esac
}

# Debug command help
gdebug_help() {
    echo "🐛 GOK Kubernetes Debugging Utilities"
    echo
    echo "Session Management:"
    echo "  debug_init              - Initialize debug session"
    echo "  gcd [namespace]         - Change/select namespace"
    echo
    echo "Pod & Container Operations:"
    echo "  gbash                   - Open shell in pod container"
    echo "  glogs [pod] [container] - View container logs with options"
    echo "  gtail [--all]          - Tail logs (single pod or all pods)"
    echo "  gdesc [type] [name]    - Describe Kubernetes resources"
    echo
    echo "Monitoring & Watching:"
    echo "  gwatch [resource]      - Watch resource changes"
    echo "  gresources [type]      - Show resource usage (pods/nodes/summary)"
    echo
    echo "Network & Connectivity:"
    echo "  gforward [svc] [local] [remote] - Port forward to services"
    echo "  gnetwork [action]      - Network debugging (services/dns/connectivity)"
    echo
    echo "Security & Configuration:"
    echo "  gdecode                - Decode secrets with interface"
    echo
    echo "Cluster Analysis:"
    echo "  gcluster [action]      - Cluster info (status/events/namespaces/storage)"
    echo "  gtroubleshoot [component] - Troubleshoot issues (pods/nodes/storage/all)"
    echo
    echo "Environment Variables:"
    echo "  DEBUG_NAMESPACE        - Current debugging namespace"
    echo "  DEBUG_CONTEXT          - Current kubectl context" 
    echo "  DEBUG_SELECTED_POD     - Last selected pod"
    echo "  DEBUG_SELECTED_CONTAINER - Last selected container"
    echo
    echo "Examples:"
    echo "  debug_init             # Start debugging session"
    echo "  gcd kube-system        # Switch to kube-system namespace"  
    echo "  gbash                  # Open shell (with selection interface)"
    echo "  glogs                  # View logs (with selection interface)"
    echo "  gtail --all            # Tail all pod logs in current namespace"
    echo "  gwatch events          # Watch cluster events"
    echo "  gnetwork dns           # Test DNS resolution"
    echo "  gtroubleshoot pods     # Find problematic pods"
}

# Export all debugging functions
export -f debug_init gcd select_pod_container
export -f glogs gtail gwatch gbash gdesc gdecode
export -f gforward gcluster gresources gnetwork gtroubleshoot
export -f gdebug_help

# Auto-initialize if not already done
if [[ -z "$DEBUG_NAMESPACE" ]]; then
    debug_init 2>/dev/null || true
fi

# Show help on load
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gdebug_help
fi