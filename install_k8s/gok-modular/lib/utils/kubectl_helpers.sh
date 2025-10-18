#!/bin/bash

# GOK Kubernetes Advanced Utilities
# Additional helper functions for advanced Kubernetes operations

# Enhanced kubectl with OAuth integration (if available)
gkctl() {
    local oauth_config="/root/oauth.conf"
    local auth_script="/root/kubernetes/install_k8s/kube-login/cli-auth.py"
    
    if [[ -f "$oauth_config" && -f "$auth_script" ]]; then
        log_info "🔐 Using OAuth authentication"
        local token=$(python3 "$auth_script" 2>/dev/null)
        if [[ -n "$token" ]]; then
            kubectl --kubeconfig="$oauth_config" --token="$token" "$@"
        else
            log_warning "OAuth token generation failed, using default kubectl"
            kubectl "$@"
        fi
    else
        kubectl "$@"
    fi
}

# Current context and namespace info
gcurrent() {
    local context=$(kubectl config current-context 2>/dev/null)
    local namespace=$(kubectl config get-contexts --no-headers | grep '^\*' | awk '{print $5}')
    
    echo "🏷️  Current Context: ${context:-<none>}"
    echo "📂 Current Namespace: ${namespace:-<default>}"
    
    if command -v kubectl >/dev/null 2>&1; then
        local cluster_info=$(kubectl cluster-info --request-timeout=5s 2>/dev/null | head -1)
        echo "🌐 Cluster: ${cluster_info:-<unreachable>}"
    fi
}

# Extract data from Kubernetes secret
# Usage: dataFromSecret <secret-name> <namespace> <key>
dataFromSecret() {
    local secret_name="$1"
    local namespace="$2"
    local key="$3"
    
    if [[ -z "$secret_name" || -z "$namespace" || -z "$key" ]]; then
        log_error "Usage: dataFromSecret <secret-name> <namespace> <key>"
        return 1
    fi
    
    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{['data']['$key']}" 2>/dev/null | base64 --decode 2>/dev/null
}

# Get full Keycloak URL
# Usage: fullKeycloakUrl
fullKeycloakUrl() {
    echo "${KEYCLOAK}.${GOK_ROOT_DOMAIN}"
}

# Get full Registry URL
# Usage: fullRegistryUrl
fullRegistryUrl() {
    echo "${REGISTRY}.${GOK_ROOT_DOMAIN}"
}

# Get full Vault URL
# Usage: fullVaultUrl
fullVaultUrl() {
    echo "${VAULT}.${GOK_ROOT_DOMAIN}"
}

# Get full Default URL (subdomain)
# Usage: fullDefaultUrl
fullDefaultUrl() {
    echo "${DEFAULT_SUBDOMAIN}.${GOK_ROOT_DOMAIN}"
}

# List all namespaces with details
gns() {
    local format="${1:-table}"
    
    case "$format" in
        "json")
            kubectl get namespaces -o json
            ;;
        "yaml")
            kubectl get namespaces -o yaml
            ;;
        "wide")
            kubectl get namespaces -o wide
            ;;
        "table"|*)
            log_info "📂 Available Namespaces:"
            echo
            kubectl get namespaces -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp,LABELS:.metadata.labels" --sort-by='.metadata.name' 2>/dev/null || kubectl get namespaces
            ;;
    esac
}

# Enhanced resource getter with filtering
gget() {
    local resource_type="$1"
    local namespace="${DEBUG_NAMESPACE:-default}"
    local output_format="${2:-table}"
    
    if [[ -z "$resource_type" ]]; then
        log_info "📋 Quick resource access:"
        echo "  gget pods           - List pods"
        echo "  gget services       - List services"
        echo "  gget deployments    - List deployments"
        echo "  gget ingress        - List ingress"
        echo "  gget secrets        - List secrets"
        echo "  gget configmaps     - List configmaps"
        echo "  gget pvc            - List persistent volume claims"
        echo "  gget all            - List all resources"
        return
    fi
    
    local kubectl_cmd="kubectl get $resource_type -n $namespace"
    
    case "$output_format" in
        "json")
            $kubectl_cmd -o json
            ;;
        "yaml")
            $kubectl_cmd -o yaml
            ;;
        "wide")
            $kubectl_cmd -o wide
            ;;
        "table"|*)
            log_info "📊 $resource_type in namespace: $namespace"
            $kubectl_cmd
            ;;
    esac
}

# Enhanced pod management
gpods() {
    local action="${1:-list}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "list"|"")
            log_info "🔍 Pods in namespace: $namespace"
            kubectl get pods -n "$namespace" -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount,AGE:.metadata.creationTimestamp,NODE:.spec.nodeName" --sort-by='.metadata.name'
            ;;
        "failed")
            log_info "❌ Failed pods across all namespaces:"
            kubectl get pods --all-namespaces --field-selector=status.phase=Failed
            ;;
        "pending")
            log_info "⏳ Pending pods across all namespaces:"
            kubectl get pods --all-namespaces --field-selector=status.phase=Pending
            ;;
        "restart")
            log_info "🔄 Pods with high restart count (>3):"
            kubectl get pods --all-namespaces --no-headers | awk '$5 > 3 {print $0}'
            ;;
        "resources")
            log_info "💾 Pod resource usage:"
            kubectl top pods -n "$namespace" --sort-by=cpu 2>/dev/null || log_warning "Metrics server unavailable"
            ;;
        *)
            log_info "🔍 Pod management commands:"
            echo "  gpods list      - List all pods (default)"
            echo "  gpods failed    - Show failed pods"
            echo "  gpods pending   - Show pending pods"
            echo "  gpods restart   - Show pods with high restart count"
            echo "  gpods resources - Show pod resource usage"
            ;;
    esac
}

# Certificate viewer and manager
gcert() {
    local action="${1:-list}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "list")
            log_info "🔒 TLS Certificates in namespace: $namespace"
            echo
            
            # List cert-manager certificates if available
            if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
                log_substep "Cert-Manager Certificates:"
                kubectl get certificates -n "$namespace" 2>/dev/null || echo "No cert-manager certificates found"
                echo
            fi
            
            # List TLS secrets
            log_substep "TLS Secrets:"
            kubectl get secrets -n "$namespace" --field-selector type=kubernetes.io/tls 2>/dev/null | head -10
            ;;
        "view")
            log_info "🔍 Certificate Details"
            
            # Get TLS secrets
            local tls_secrets=$(kubectl get secrets -n "$namespace" --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null | awk '{print $1}')
            
            if [[ -z "$tls_secrets" ]]; then
                log_error "No TLS certificates found in namespace $namespace"
                return 1
            fi
            
            log_info "Available TLS certificates:"
            local index=1
            while read -r secret_name; do
                echo "${index}>> $secret_name"
                index=$((index + 1))
            done <<< "$tls_secrets"
            
            echo
            read -p "Enter certificate index: " cert_index
            
            local selected_cert=$(echo "$tls_secrets" | sed -n "${cert_index}p")
            if [[ -z "$selected_cert" ]]; then
                log_error "Invalid certificate selection"
                return 1
            fi
            
            log_info "📜 Certificate details for: $selected_cert"
            kubectl get secret "$selected_cert" -n "$namespace" -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
            ;;
        "check")
            log_info "🏥 Certificate Health Check"
            
            # Check certificate expiration
            local tls_secrets=$(kubectl get secrets -n "$namespace" --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null | awk '{print $1}')
            
            if [[ -z "$tls_secrets" ]]; then
                log_error "No TLS certificates found"
                return 1
            fi
            
            echo "Certificate Expiration Report:"
            echo "================================================"
            
            while read -r secret_name; do
                local cert_data=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d 2>/dev/null)
                if [[ -n "$cert_data" ]]; then
                    local expiry=$(echo "$cert_data" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
                    local days_left=$(echo "$cert_data" | openssl x509 -noout -checkend $((30*24*3600)) 2>/dev/null && echo "30+" || echo "<30")
                    
                    printf "%-25s %s (expires in %s days)\n" "$secret_name" "$expiry" "$days_left"
                fi
            done <<< "$tls_secrets"
            ;;
        *)
            log_info "🔒 Certificate management commands:"
            echo "  gcert list  - List certificates and TLS secrets"
            echo "  gcert view  - View certificate details"
            echo "  gcert check - Check certificate expiration"
            ;;
    esac
}

# Enhanced configuration management
gconfig() {
    local action="${1:-list}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "list")
            log_info "⚙️  Configuration in namespace: $namespace"
            echo
            
            log_substep "ConfigMaps:"
            kubectl get configmaps -n "$namespace" --no-headers 2>/dev/null | head -10 || echo "No configmaps found"
            echo
            
            log_substep "Secrets:"
            kubectl get secrets -n "$namespace" --no-headers 2>/dev/null | head -10 || echo "No secrets found"
            ;;
        "edit")
            local resource_type="$2"
            local resource_name="$3"
            
            if [[ -z "$resource_type" ]]; then
                echo "Usage: gconfig edit <configmap|secret> <name>"
                return 1
            fi
            
            if [[ -z "$resource_name" ]]; then
                # Show available resources
                local resources=$(kubectl get "$resource_type" -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}')
                if [[ -z "$resources" ]]; then
                    log_error "No $resource_type found in namespace $namespace"
                    return 1
                fi
                
                log_info "Available $resource_type:"
                local index=1
                while read -r name; do
                    echo "${index}>> $name"
                    index=$((index + 1))
                done <<< "$resources"
                
                read -p "Enter resource index: " selection
                resource_name=$(echo "$resources" | sed -n "${selection}p")
                
                if [[ -z "$resource_name" ]]; then
                    log_error "Invalid selection"
                    return 1
                fi
            fi
            
            log_info "📝 Editing $resource_type/$resource_name"
            kubectl edit "$resource_type" "$resource_name" -n "$namespace"
            ;;
        *)
            log_info "⚙️  Configuration management commands:"
            echo "  gconfig list            - List configmaps and secrets"
            echo "  gconfig edit <type>     - Edit configmap or secret"
            ;;
    esac
}

# Advanced service operations
gservice() {
    local action="${1:-list}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "list")
            log_info "🌐 Services in namespace: $namespace"
            kubectl get services -n "$namespace" -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port,AGE:.metadata.creationTimestamp"
            ;;
        "endpoints")
            log_info "🔗 Service Endpoints in namespace: $namespace"
            kubectl get endpoints -n "$namespace"
            ;;
        "test")
            local service_name="$2"
            
            if [[ -z "$service_name" ]]; then
                log_info "🧪 Available services to test:"
                kubectl get services -n "$namespace" --no-headers | awk '{printf "%d>> %s (%s)\n", NR, $1, $3}'
                
                read -p "Enter service name: " service_name
                
                if [[ -z "$service_name" ]]; then
                    log_error "Service name required"
                    return 1
                fi
            fi
            
            log_info "🧪 Testing connectivity to service: $service_name"
            
            # Get service details
            local service_port=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
            local service_ip=$(kubectl get service "$service_name" -n "$namespace" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
            
            if [[ -z "$service_port" || -z "$service_ip" ]]; then
                log_error "Service $service_name not found or has no ports"
                return 1
            fi
            
            log_info "Testing $service_name ($service_ip:$service_port)..."
            
            # Create test pod
            kubectl run service-test-$(date +%s) --image=busybox:1.28 --rm -it --restart=Never -- /bin/sh -c "
                echo 'Testing service connectivity...'
                nc -zv $service_ip $service_port && echo '✅ Service is reachable' || echo '❌ Service is not reachable'
                echo 'Testing DNS resolution...'
                nslookup $service_name.$namespace.svc.cluster.local && echo '✅ DNS resolution OK' || echo '❌ DNS resolution failed'
            "
            ;;
        *)
            log_info "🌐 Service management commands:"
            echo "  gservice list      - List services"
            echo "  gservice endpoints - List service endpoints"
            echo "  gservice test      - Test service connectivity"
            ;;
    esac
}

# Enhanced ingress management
gingress() {
    local action="${1:-list}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$action" in
        "list")
            log_info "🚪 Ingress Resources in namespace: $namespace"
            kubectl get ingress -n "$namespace" -o custom-columns="NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[0].ip,PORTS:.spec.tls[*].secretName,AGE:.metadata.creationTimestamp"
            ;;
        "test")
            local ingress_name="$2"
            
            if [[ -z "$ingress_name" ]]; then
                local ingresses=$(kubectl get ingress -n "$namespace" --no-headers 2>/dev/null | awk '{print $1}')
                
                if [[ -z "$ingresses" ]]; then
                    log_error "No ingress resources found"
                    return 1
                fi
                
                log_info "Available ingress resources:"
                local index=1
                while read -r name; do
                    echo "${index}>> $name"
                    index=$((index + 1))
                done <<< "$ingresses"
                
                read -p "Enter ingress index: " selection
                ingress_name=$(echo "$ingresses" | sed -n "${selection}p")
            fi
            
            log_info "🧪 Testing ingress: $ingress_name"
            
            # Get ingress details
            local hosts=$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
            local tls_enabled=$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.spec.tls}' 2>/dev/null)
            
            if [[ -z "$hosts" ]]; then
                log_error "No hosts found for ingress $ingress_name"
                return 1
            fi
            
            for host in $hosts; do
                local protocol="http"
                [[ -n "$tls_enabled" ]] && protocol="https"
                
                log_info "Testing $protocol://$host"
                
                # Test with curl
                local test_result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$protocol://$host" 2>/dev/null || echo "000")
                
                case "$test_result" in
                    "200"|"301"|"302")
                        echo "✅ $host - HTTP $test_result (OK)"
                        ;;
                    "000")
                        echo "❌ $host - Connection failed"
                        ;;
                    *)
                        echo "⚠️  $host - HTTP $test_result"
                        ;;
                esac
            done
            ;;
        *)
            log_info "🚪 Ingress management commands:"
            echo "  gingress list - List ingress resources"
            echo "  gingress test - Test ingress connectivity"
            ;;
    esac
}

# Storage management utilities
# Create local storage class and persistent volume
createLocalStorageClassAndPV() {
  local storageClassName=$1
  local pvName=$2
  local volumePath=$3

  # Create storage class
  cat << EOF | execute_with_suppression kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ${storageClassName}
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

  if [[ $? -eq 0 ]]; then
    log_success "Storage class created (${storageClassName})"
  else
    log_error "Failed to create storage class"
    return 1
  fi

  if execute_with_suppression mkdir -p "${volumePath}" && execute_with_suppression chmod 777 "${volumePath}"; then
    log_success "Local storage directory prepared (${volumePath})"
  else
    log_error "Failed to prepare local storage directory"
    return 1
  fi

  # Create persistent volume
  cat << EOF | execute_with_suppression kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${pvName}
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ${storageClassName}
  local:
    path: ${volumePath}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - master.cloud.com
EOF

  if [[ $? -eq 0 ]]; then
    log_success "Persistent volume created (${pvName}, 10Gi)"
  else
    log_error "Failed to create persistent volume"
    return 1
  fi
}

# Performance monitoring and analysis
gperf() {
    local component="${1:-summary}"
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    case "$component" in
        "summary")
            log_info "📊 Performance Summary"
            echo
            
            log_substep "Node Resources:"
            kubectl top nodes 2>/dev/null || log_warning "Metrics server not available"
            echo
            
            log_substep "Top Resource-Consuming Pods:"
            kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || log_warning "Pod metrics not available"
            ;;
        "pods")
            log_info "📊 Pod Performance in namespace: $namespace"
            kubectl top pods -n "$namespace" --sort-by=cpu 2>/dev/null || log_warning "Metrics server not available"
            ;;
        "nodes")
            log_info "🖥️  Node Performance"
            kubectl top nodes --sort-by=cpu 2>/dev/null || log_warning "Metrics server not available"
            ;;
        "memory")
            log_info "💾 Memory Usage Analysis"
            kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -15 || log_warning "Memory metrics not available"
            ;;
        *)
            log_info "📊 Performance monitoring commands:"
            echo "  gperf summary - Complete performance overview"
            echo "  gperf pods    - Pod performance in current namespace"
            echo "  gperf nodes   - Node performance"
            echo "  gperf memory  - Memory usage analysis"
            ;;
    esac
}

# System status and health checks
gstatus() {
    local component="${1:-all}"
    
    case "$component" in
        "cluster")
            log_info "🏥 Cluster Status"
            kubectl cluster-info --request-timeout=10s 2>/dev/null || log_error "Cluster unreachable"
            ;;
        "nodes")
            log_info "🖥️  Node Status"
            kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[-1].type,ROLES:.metadata.labels.kubernetes\.io/arch,VERSION:.status.nodeInfo.kubeletVersion,AGE:.metadata.creationTimestamp"
            ;;
        "system-pods")
            log_info "🔧 System Pod Status"
            kubectl get pods -n kube-system --sort-by='.metadata.name'
            ;;
        "storage")
            log_info "💾 Storage Status"
            echo
            log_substep "Persistent Volumes:"
            kubectl get pv 2>/dev/null || echo "No persistent volumes"
            echo
            log_substep "Storage Classes:"
            kubectl get storageclass 2>/dev/null || echo "No storage classes"
            ;;
        "all"|*)
            gstatus cluster
            echo
            gstatus nodes
            echo
            gstatus system-pods
            echo
            gstatus storage
            ;;
    esac
}

# Quick kubectl aliases for common operations
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgi='kubectl get ingress'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias ke='kubectl edit'
alias kl='kubectl logs'
alias kx='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Wait for all pods in a namespace to be ready (simple version)
waitForServiceAvailable() {
    local namespace="${1:-default}"
    
    log_info "Waiting for all pods to be ready in namespace '$namespace'..."
    
    if kubectl --timeout=120s wait --for=condition=Ready pods --all --namespace "$namespace" >/dev/null 2>&1; then
        log_success "All pods in namespace '$namespace' are ready"
        return 0
    else
        log_error "Service timed out waiting for pods to be ready in namespace '$namespace'"
        return 1
    fi
}

# Export utility functions
export -f gkctl gcurrent dataFromSecret fullKeycloakUrl fullRegistryUrl fullVaultUrl fullDefaultUrl gns gget gpods gcert gconfig
export -f gservice gingress gperf gstatus createLocalStorageClassAndPV
export -f waitForServiceAvailable

# Helper function to show all available utilities
gutils() {
    echo "🛠️  GOK Kubernetes Utilities"
    echo
    echo "Authentication & Context:"
    echo "  gkctl               - kubectl with OAuth (if configured)"
    echo "  gcurrent            - Show current context and namespace"
    echo "  gcd [namespace]     - Change namespace (from debug.sh)"
    echo
    echo "Resource Management:"
    echo "  gns [format]        - List namespaces"
    echo "  gget <resource>     - Get resources with enhanced output"
    echo "  gpods [action]      - Enhanced pod management"
    echo "  gservice [action]   - Service operations"
    echo "  gingress [action]   - Ingress management"
    echo
    echo "Configuration & Security:"
    echo "  gconfig [action]    - ConfigMap and Secret management"
    echo "  gcert [action]      - Certificate management"
    echo "  gdecode             - Secret decoder (from debug.sh)"
    echo
    echo "Monitoring & Performance:"
    echo "  gperf [component]   - Performance monitoring"
    echo "  gstatus [component] - System status checks"
    echo "  gresources [type]   - Resource usage (from debug.sh)"
    echo
    echo "Debugging (from debug.sh):"
    echo "  gbash               - Pod shell access"
    echo "  glogs               - Enhanced log viewing"
    echo "  gtail               - Log tailing"
    echo "  gwatch              - Watch resources"
    echo "  gtroubleshoot       - Troubleshooting tools"
    echo
    echo "Network & Connectivity:"
    echo "  gforward            - Port forwarding (from debug.sh)"
    echo "  gnetwork            - Network debugging (from debug.sh)"
    echo
    echo "Quick Aliases:"
    echo "  k, kgp, kgs, kgd, kgi, kgn, kd, ke, kl, kx, kaf, kdf"
    echo
    echo "For detailed help on any command, run: <command> --help or <command> help"
}

# Auto-export utility overview function
export -f gutils

# Clean up local filesystem storage for a service
emptyLocalFsStorage() {
  local service=$1
  local pvName=$2
  local scName=$3
  local volumePath=$4
  local namespace=$5

  log_info "Cleaning up persistent storage for $service"

  # Clean up PVCs in namespace if specified
  if [[ -n $namespace ]]; then
    log_info "Removing persistent volume claims in namespace: $namespace"
    local pvc_count=$(kubectl get pvc -n $namespace --no-headers 2>/dev/null | wc -l)
    if [[ $pvc_count -gt 0 ]]; then
      if kubectl_with_summary delete "pvc" --all -n $namespace; then
        log_success "Persistent volume claims removed from $namespace namespace"
      else
        log_warning "Some PVCs may not have been removed from $namespace namespace"
      fi
    else
      log_info "No persistent volume claims found in $namespace namespace"
    fi
  fi

  # Clean up persistent volume
  log_info "Removing persistent volume: $pvName"
  if kubectl get pv $pvName >/dev/null 2>&1; then
    if kubectl_with_summary delete "pv" $pvName; then
      log_success "Persistent volume '$pvName' removed"
    else
      log_warning "Persistent volume '$pvName' removal had issues"
    fi
  else
    log_info "Persistent volume '$pvName' not found (may already be removed)"
  fi

  # Clean up storage class
  log_info "Removing storage class: $scName"
  if kubectl get sc $scName >/dev/null 2>&1; then
    if kubectl_with_summary delete "sc" $scName; then
      log_success "Storage class '$scName' removed"
    else
      log_warning "Storage class '$scName' removal had issues"
    fi
  else
    log_info "Storage class '$scName' not found (may already be removed)"
  fi

  # Clean up local filesystem path
  if [[ -n "$volumePath" && -d "$volumePath" ]]; then
    log_info "Cleaning up local storage path: $volumePath"
    if execute_with_suppression rm -rf "$volumePath"; then
      log_success "Local storage path '$volumePath' cleaned up"
    else
      log_warning "Could not fully clean up local storage path '$volumePath'"
    fi
  else
    log_info "Local storage path '$volumePath' not found or already cleaned"
  fi

  log_success "$service persistent storage cleanup completed"
}

patchOauth2Secure() {
  NAME=$1
  NS=$2
  RD=$3
  kubectl patch ing "$NAME" --patch "$(
    cat <<EOF
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-signin: https://$(defaultSubdomain).$(rootDomain)/oauth2/start?rd=${RD}
    nginx.ingress.kubernetes.io/auth-url: https://$(defaultSubdomain).$(rootDomain)/oauth2/auth
    nginx.ingress.kubernetes.io/auth-response-headers: Authorization
EOF
  )" -n "$NS"
}

# Show utilities on load if interactive
if [[ $- == *i* ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    gutils
fi