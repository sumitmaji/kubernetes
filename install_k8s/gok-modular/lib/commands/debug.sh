#!/bin/bash

# GOK Debug Command Module - Main debugging command dispatcher

# Main debug command handler
debugCmd() {
    local subcommand="$1"
    
    if [[ -z "$subcommand" || "$subcommand" == "help" || "$subcommand" == "--help" ]]; then
        show_debug_help
        return 0
    fi
    
    # Initialize debugging session
    debug_init 2>/dev/null || true
    
    # Parse verbose flags
    shift  # Remove subcommand
    local verbose_flag=""
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_flag="--verbose"
                export GOK_VERBOSE="true"
                ;;
        esac
    done
    
    case "$subcommand" in
        # Session Management
        "init"|"setup")
            debug_init
            ;;
        "context"|"ctx")
            gcurrent
            ;;
        "namespace"|"ns")
            if [[ -n "$1" ]]; then
                gcd "$1"
            else
                gns
            fi
            ;;
        
        # Pod Operations
        "shell"|"bash"|"exec")
            gbash "$@"
            ;;
        "logs"|"log")
            glogs "$@"
            ;;
        "tail")
            gtail "$@"
            ;;
        "describe"|"desc")
            gdesc "$@"
            ;;
        
        # Resource Monitoring
        "watch")
            gwatch "$@"
            ;;
        "resources"|"top")
            gresources "$@"
            ;;
        "pods"|"pod")
            gpods "$@"
            ;;
        "services"|"svc")
            gservice "$@"
            ;;
        
        # Network & Connectivity
        "forward"|"port-forward"|"pf")
            gforward "$@"
            ;;
        "network"|"net")
            gnetwork "$@"
            ;;
        "ingress"|"ing")
            gingress "$@"
            ;;
        
        # Security & Configuration
        "decode"|"secret")
            gdecode "$@"
            ;;
        "cert"|"certificate")
            gcert "$@"
            ;;
        "config"|"cfg")
            gconfig "$@"
            ;;
        
        # Cluster Analysis
        "cluster")
            gcluster "$@"
            ;;
        "status"|"health")
            gstatus "$@"
            ;;
        "troubleshoot"|"fix")
            gtroubleshoot "$@"
            ;;
        "performance"|"perf")
            gperf "$@"
            ;;
        
        # Quick Actions
        "dashboard"|"dash")
            debug_dashboard
            ;;
        "summary"|"overview")
            debug_summary
            ;;
        "events")
            kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
            ;;
        
        # Utility Commands
        "utils"|"utilities")
            gutils
            ;;
        "aliases")
            show_debug_aliases
            ;;
        
        *)
            log_error "Unknown debug command: $subcommand"
            echo "Run 'gok debug help' to see available commands"
            return 1
            ;;
    esac
}

# Show debug command help
show_debug_help() {
    echo "gok debug - Comprehensive Kubernetes debugging and troubleshooting toolkit"
    echo
    echo "Usage: gok debug <command> [options]"
    echo
    echo "Session Management:"
    echo "  init, setup              Initialize debugging session"
    echo "  context, ctx             Show current context and namespace"
    echo "  namespace, ns [name]     Change namespace or list namespaces"
    echo
    echo "Pod Operations:"
    echo "  shell, bash, exec        Open interactive shell in pod"
    echo "  logs, log [pod] [container]  View container logs with options"
    echo "  tail [--all]            Tail logs (single pod or all pods)"
    echo "  describe, desc [type]   Describe Kubernetes resources"
    echo
    echo "Resource Monitoring:"
    echo "  watch [resource]        Watch resource changes in real-time"
    echo "  resources, top [type]   Show resource usage (CPU/Memory)"
    echo "  pods, pod [action]      Enhanced pod management and analysis"
    echo "  services, svc [action]  Service operations and testing"
    echo
    echo "Network & Connectivity:"
    echo "  forward, pf [svc]       Port forward to services"
    echo "  network, net [action]   Network debugging (DNS, connectivity)"
    echo "  ingress, ing [action]   Ingress management and testing"
    echo
    echo "Security & Configuration:"
    echo "  decode, secret          Decode secrets with interactive interface"
    echo "  cert, certificate       Certificate management and analysis"
    echo "  config, cfg [action]    ConfigMap and Secret management"
    echo
    echo "Cluster Analysis:"
    echo "  cluster [action]        Cluster information and health"
    echo "  status, health [component]  System status and health checks"
    echo "  troubleshoot, fix [component]  Identify and troubleshoot issues"
    echo "  performance, perf [component]  Performance monitoring and analysis"
    echo
    echo "Quick Actions:"
    echo "  dashboard, dash         Open debugging dashboard (web interface)"
    echo "  summary, overview       Show complete cluster overview"
    echo "  events                  Show recent cluster events"
    echo
    echo "Utilities:"
    echo "  utils, utilities        Show all available utility functions"
    echo "  aliases                 Show kubectl aliases and shortcuts"
    echo
    echo "Global Options:"
    echo "  --verbose, -v           Enable verbose output for debugging"
    echo
    echo "Environment Variables:"
    echo "  DEBUG_NAMESPACE         Current debugging namespace (auto-set)"
    echo "  DEBUG_CONTEXT           Current kubectl context (auto-set)"
    echo "  GOK_VERBOSE=true        Enable verbose mode globally"
    echo
    echo "Examples:"
    echo "  gok debug init          # Initialize debugging session"
    echo "  gok debug ns kube-system  # Switch to kube-system namespace"
    echo "  gok debug shell         # Open shell in pod (with selection)"
    echo "  gok debug logs          # View logs (with selection interface)"
    echo "  gok debug tail --all    # Tail all pods in current namespace"
    echo "  gok debug watch events  # Watch cluster events"
    echo "  gok debug troubleshoot  # Run complete troubleshooting"
    echo "  gok debug network dns   # Test DNS resolution"
    echo "  gok debug summary       # Show complete cluster overview"
    echo
    echo "Quick Start:"
    echo "  1. gok debug init       # Start debugging session"
    echo "  2. gok debug summary    # Get cluster overview"
    echo "  3. gok debug pods       # Check pod status"
    echo "  4. gok debug troubleshoot # Find issues"
}

# Show kubectl aliases and shortcuts
show_debug_aliases() {
    echo "🔗 Kubectl Aliases and Shortcuts"
    echo
    echo "Basic Operations:"
    echo "  k          = kubectl"
    echo "  kgp        = kubectl get pods"
    echo "  kgs        = kubectl get services"
    echo "  kgd        = kubectl get deployments"
    echo "  kgi        = kubectl get ingress"
    echo "  kgn        = kubectl get nodes"
    echo
    echo "Resource Operations:"
    echo "  kd         = kubectl describe"
    echo "  ke         = kubectl edit"
    echo "  kl         = kubectl logs"
    echo "  kx         = kubectl exec -it"
    echo
    echo "File Operations:"
    echo "  kaf        = kubectl apply -f"
    echo "  kdf        = kubectl delete -f"
    echo
    echo "GOK Debug Functions:"
    echo "  gcd        = Change/select namespace"
    echo "  gbash      = Pod shell access"
    echo "  glogs      = Enhanced log viewer"
    echo "  gtail      = Log tailing"
    echo "  gwatch     = Watch resources"
    echo "  gdesc      = Enhanced describe"
    echo "  gdecode    = Secret decoder"
    echo "  gforward   = Port forwarding"
    echo
    echo "To use aliases in your shell:"
    echo "  source /path/to/gok-modular/lib/utils/kubectl_helpers.sh"
}

# Debugging dashboard (text-based)
debug_dashboard() {
    local namespace="${DEBUG_NAMESPACE:-default}"
    
    clear
    echo "🐛 GOK Kubernetes Debugging Dashboard"
    echo "========================================"
    echo
    
    # Cluster info
    log_info "🏥 Cluster Health"
    local cluster_status=$(kubectl cluster-info --request-timeout=5s 2>/dev/null | head -1 || echo "❌ Cluster unreachable")
    echo "  $cluster_status"
    echo
    
    # Current context
    log_info "📍 Current Context"
    echo "  Context: $(kubectl config current-context 2>/dev/null || echo '<none>')"
    echo "  Namespace: $namespace"
    echo
    
    # Node status
    log_info "🖥️  Nodes"
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    echo "  Total: $node_count | Ready: $ready_nodes"
    echo
    
    # Pod summary
    log_info "🔍 Pods in $namespace"
    local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
    local running_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local failed_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c -E "(Failed|Error|CrashLoopBackOff)" || echo "0")
    echo "  Total: $total_pods | Running: $running_pods | Failed: $failed_pods"
    echo
    
    # Recent events
    log_info "📰 Recent Events (Last 5)"
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp' 2>/dev/null | tail -5 | sed 's/^/  /'
    echo
    
    # Interactive menu
    echo "🎮 Quick Actions:"
    echo "  1. Pod shell access       6. Network debugging"
    echo "  2. View logs             7. Troubleshoot issues"  
    echo "  3. Watch resources       8. Performance monitoring"
    echo "  4. Describe resources    9. Change namespace"
    echo "  5. Port forward          0. Exit dashboard"
    echo
    
    read -p "Select action [1-9,0]: " action
    
    case "$action" in
        1) gbash ;;
        2) glogs ;;
        3) gwatch ;;
        4) gdesc ;;
        5) gforward ;;
        6) gnetwork ;;
        7) gtroubleshoot ;;
        8) gperf ;;
        9) gcd ;;
        0) return 0 ;;
        *) log_error "Invalid selection" ;;
    esac
    
    echo
    read -p "Press Enter to refresh dashboard..." 
    debug_dashboard
}

# Complete cluster summary
debug_summary() {
    log_header "Kubernetes Cluster Debug Summary"
    
    # Cluster info
    log_step "1" "Cluster Information"
    kubectl cluster-info --request-timeout=10s 2>/dev/null || log_error "Cluster unreachable"
    echo
    
    # Nodes
    log_step "2" "Node Status"
    kubectl get nodes -o wide 2>/dev/null || log_error "Cannot get nodes"
    echo
    
    # Namespaces
    log_step "3" "Namespaces"
    kubectl get namespaces 2>/dev/null || log_error "Cannot get namespaces"
    echo
    
    # System pods
    log_step "4" "System Pods (kube-system)"
    kubectl get pods -n kube-system --no-headers 2>/dev/null | head -10 || log_error "Cannot get system pods"
    echo
    
    # Current namespace pods
    local namespace="${DEBUG_NAMESPACE:-default}"
    log_step "5" "Pods in namespace: $namespace"
    kubectl get pods -n "$namespace" 2>/dev/null || log_error "Cannot get pods in $namespace"
    echo
    
    # Services
    log_step "6" "Services in namespace: $namespace"
    kubectl get services -n "$namespace" 2>/dev/null || log_info "No services in $namespace"
    echo
    
    # Recent events
    log_step "7" "Recent Events (Last 10)"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || log_info "No recent events"
    echo
    
    # Resource usage (if metrics available)
    log_step "8" "Resource Usage"
    kubectl top nodes 2>/dev/null || log_info "Metrics server not available"
    echo
    
    # Quick health check
    log_step "9" "Health Check"
    local issues=0
    
    # Check for failed pods
    local failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    if [[ $failed_pods -gt 0 ]]; then
        echo "  ⚠️  $failed_pods failed pods found"
        issues=$((issues + 1))
    fi
    
    # Check for pending pods
    local pending_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    if [[ $pending_pods -gt 0 ]]; then
        echo "  ⚠️  $pending_pods pending pods found"
        issues=$((issues + 1))
    fi
    
    # Check node readiness
    local not_ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "Ready" | wc -l)
    if [[ $not_ready_nodes -gt 0 ]]; then
        echo "  ⚠️  $not_ready_nodes nodes not ready"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo "  ✅ No obvious issues detected"
    else
        echo "  ⚠️  $issues potential issues found - run 'gok debug troubleshoot' for details"
    fi
    
    echo
    log_success "Summary complete! Use 'gok debug help' for detailed debugging commands."
}

# Export debug command
export -f debugCmd show_debug_help show_debug_aliases debug_dashboard debug_summary

# Auto-initialize debugging if in interactive mode
if [[ $- == *i* ]] && [[ -z "$DEBUG_NAMESPACE" ]]; then
    debug_init 2>/dev/null || true
fi