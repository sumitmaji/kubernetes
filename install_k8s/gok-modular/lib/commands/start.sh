#!/bin/bash
# lib/commands/start.sh
# Start command for GOK-New modular system
# Allows starting system services and components

startCmd() {
    local component="$1"

    # Handle help flags
    if [[ "$component" == "--help" || "$component" == "-h" || "$component" == "help" ]]; then
        echo
        echo "🚀 GOK-New Start Command Help"
        echo "─────────────────────────────"
        echo
        echo "Purpose: Start system services and components"
        echo
        echo "Usage: gok-new start <component>"
        echo
        echo "Available Components:"
        echo "  kubernetes    - Start complete Kubernetes cluster (kubelet + haproxy)"
        echo "  kubelet       - Start kubelet service"
        echo "  proxy         - Start HAProxy load balancer"
        echo "  ha            - Start HAProxy load balancer (alias for proxy)"
        echo "  docker        - Start Docker service"
        echo "  containerd    - Start containerd service"
        echo
        echo "Examples:"
        echo "  gok-new start kubernetes    # Start full Kubernetes cluster"
        echo "  gok-new start kubelet       # Start only kubelet service"
        echo "  gok-new start docker        # Start Docker service"
        echo "  gok-new start --help        # Show this help message"
        echo
        return 0
    fi

    # Check if component is provided
    if [ -z "$component" ]; then
        log_error "No component specified for start command"
        echo
        echo "Usage: gok-new start <component>"
        echo
        echo "Available components:"
        echo "  kubernetes    - Start Kubernetes cluster (kubelet + haproxy)"
        echo "  kubelet       - Start kubelet service"
        echo "  proxy         - Start HAProxy load balancer"
        echo "  ha            - Start HAProxy load balancer (alias for proxy)"
        echo "  docker        - Start Docker service"
        echo "  containerd    - Start containerd service"
        echo
        return 1
    fi

    log_component_start "$component" "Starting service"

    case "$component" in
        "kubernetes")
            log_step "1" "Disabling swap"
            if disableSwap; then
                log_success "Swap disabled"
            else
                log_warning "Failed to disable swap"
            fi

            log_step "2" "Starting HAProxy"
            if startHa; then
                log_success "HAProxy started successfully"
            else
                log_error "Failed to start HAProxy"
                return 1
            fi

            log_step "3" "Starting kubelet"
            if startKubelet; then
                log_success "Kubelet started successfully"
            else
                log_error "Failed to start kubelet"
                return 1
            fi

            log_component_success "$component" "Kubernetes cluster services started"
            ;;

        "proxy"|"ha")
            log_step "1" "Starting HAProxy"
            if startHa; then
                log_component_success "$component" "HAProxy started successfully"
            else
                log_error "Failed to start HAProxy"
                return 1
            fi
            ;;

        "kubelet")
            log_step "1" "Starting kubelet service"
            if startKubelet; then
                log_component_success "$component" "Kubelet started successfully"
            else
                log_error "Failed to start kubelet"
                return 1
            fi
            ;;

        "docker")
            log_step "1" "Starting Docker service"
            if execute_with_suppression systemctl start docker; then
                if execute_with_suppression systemctl enable docker; then
                    log_component_success "$component" "Docker service started and enabled"
                else
                    log_component_success "$component" "Docker service started (enable failed)"
                fi
            else
                log_error "Failed to start Docker service"
                return 1
            fi
            ;;

        "containerd")
            log_step "1" "Starting containerd service"
            if execute_with_suppression systemctl start containerd; then
                if execute_with_suppression systemctl enable containerd; then
                    log_component_success "$component" "Containerd service started and enabled"
                else
                    log_component_success "$component" "Containerd service started (enable failed)"
                fi
            else
                log_error "Failed to start containerd service"
                return 1
            fi
            ;;

        *)
            log_error "Unknown component: $component"
            echo
            echo "Available components:"
            echo "  kubernetes    - Start Kubernetes cluster (kubelet + haproxy)"
            echo "  kubelet       - Start kubelet service"
            echo "  proxy         - Start HAProxy load balancer"
            echo "  ha            - Start HAProxy load balancer (alias for proxy)"
            echo "  docker        - Start Docker service"
            echo "  containerd    - Start containerd service"
            echo
            return 1
            ;;
    esac
}

# Helper functions for starting services
disableSwap() {
    # Disable swap
    if swapoff -a 2>/dev/null; then
        # Comment out swap entries in /etc/fstab
        sed -i '/swap/ s/^/#/' /etc/fstab 2>/dev/null || true
        return 0
    fi
    return 1
}

startHa() {
    # Start HAProxy service
    if execute_with_suppression systemctl start haproxy; then
        if execute_with_suppression systemctl enable haproxy; then
            return 0
        fi
    fi
    return 1
}

startKubelet() {
    # Start kubelet service
    if execute_with_suppression systemctl start kubelet; then
        if execute_with_suppression systemctl enable kubelet; then
            return 0
        fi
    fi
    return 1
}