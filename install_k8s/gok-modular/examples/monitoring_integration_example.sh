#!/bin/bash
# =============================================================================
# Example Component Integration - Monitoring Stack
# =============================================================================
# This example demonstrates how to integrate all modular utility systems
# into a component installation script

# Source the bootstrap to load all utilities
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core/bootstrap.sh"

# Initialize GOK system
bootstrap_gok

# =============================================================================
# MONITORING STACK INSTALLATION WITH FULL UTILITY INTEGRATION
# =============================================================================

install_monitoring_stack() {
    local component="monitoring"
    local namespace="monitoring"
    local description="Prometheus and Grafana monitoring stack"
    local version="v1.0"
    
    log_header "Monitoring Stack Installation" "Installing comprehensive monitoring solution"
    
    # =========================================================================
    # 1. COMPONENT TRACKING - Start installation tracking
    # =========================================================================
    start_component "$component" "$description" "$version" "$namespace"
    
    # =========================================================================
    # 2. REPOSITORY FIX - Ensure Helm repositories are working
    # =========================================================================
    log_step "1" "Checking Helm repositories"
    
    if ! helm repo list | grep -q prometheus-community; then
        log_info "Adding Prometheus Helm repository"
        if ! helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; then
            log_warning "Repository add failed, attempting to fix repositories"
            if fix_helm_repository_errors; then
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || {
                    fail_component "$component" "Failed to add Prometheus repository after fixes"
                    return 1
                }
            else
                fail_component "$component" "Repository fix failed"
                return 1
            fi
        fi
    fi
    
    # Update repositories
    execute_with_suppression "helm repo update" "Updating Helm repositories"
    
    # =========================================================================
    # 3. EXECUTION SYSTEM - Install using execution utilities
    # =========================================================================
    log_step "2" "Creating namespace and installing components"
    
    # Create namespace
    execute_with_suppression "kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -" "Creating monitoring namespace"
    
    # Install Prometheus using Helm wrapper
    if ! helm_install_with_summary "prometheus" "prometheus-community/kube-prometheus-stack" "$namespace" ""; then
        fail_component "$component" "Prometheus installation failed"
        return 1
    fi
    
    # =========================================================================
    # 4. VALIDATION SYSTEM - Validate installation success
    # =========================================================================
    log_step "3" "Validating monitoring stack installation"
    
    # Wait for pods to be ready
    log_info "Waiting for monitoring pods to become ready..."
    if ! wait_for_pods_ready "prometheus" 600 "$namespace"; then
        fail_component "$component" "Monitoring pods failed to become ready"
        return 1
    fi
    
    # Comprehensive component validation
    if ! validate_component_installation "$component" 600; then
        fail_component "$component" "Component validation failed"
        return 1
    fi
    
    # =========================================================================
    # 5. VERIFICATION SYSTEM - Enhanced deployment verification
    # =========================================================================
    log_step "4" "Performing deployment verification"
    
    if ! verify_component_deployment "$component" "$namespace"; then
        log_warning "Deployment verification found issues"
        # Note: verification issues are non-fatal but should be addressed
    else
        log_success "Deployment verification passed"
    fi
    
    # =========================================================================
    # 6. TRACKING COMPLETION - Mark installation as complete
    # =========================================================================
    complete_component "$component" "Installation completed successfully" "All monitoring services are running and healthy"
    
    # =========================================================================
    # 7. GUIDANCE SYSTEM - Provide post-installation guidance
    # =========================================================================
    log_step "5" "Providing post-installation guidance"
    
    # Show component-specific guidance
    show_component_guidance "$component"
    
    # Suggest next steps
    suggest_and_install_next_module "$component" false
    
    log_success "Monitoring stack installation completed successfully!"
    return 0
}

# =============================================================================
# INTERACTIVE INSTALLATION EXAMPLE
# =============================================================================

install_monitoring_interactive() {
    log_header "Interactive Monitoring Installation" "Guided monitoring setup"
    
    # Check prerequisites first
    if ! check_prerequisites; then
        log_error "Prerequisites not met for monitoring installation"
        return 1
    fi
    
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📊 MONITORING STACK SETUP${COLOR_RESET}"
    echo -e "${COLOR_CYAN}This will install Prometheus and Grafana for cluster monitoring.${COLOR_RESET}"
    echo
    
    # Interactive component choice
    if guided_component_choice "monitoring" "Comprehensive monitoring with Prometheus and Grafana - Recommended for production"; then
        install_monitoring_stack
    else
        log_info "Monitoring installation skipped by user"
    fi
}

# =============================================================================
# VALIDATION AND TROUBLESHOOTING EXAMPLE
# =============================================================================

troubleshoot_monitoring() {
    local component="monitoring"
    local namespace="monitoring"
    
    log_header "Monitoring Troubleshooting" "Diagnosing monitoring stack issues"
    
    # Comprehensive validation
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔍 RUNNING VALIDATION CHECKS${COLOR_RESET}"
    if validate_component_installation "$component" 300; then
        log_success "Validation checks passed"
    else
        log_warning "Validation issues found"
    fi
    
    echo
    
    # Enhanced verification with issue detection
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}🔍 RUNNING DEPLOYMENT VERIFICATION${COLOR_RESET}"
    verify_component_deployment "$component" "$namespace"
    
    echo
    
    # Show current status
    echo -e "${COLOR_BRIGHT_CYAN}${COLOR_BOLD}📊 COMPONENT STATUS${COLOR_RESET}"
    show_installation_summary
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

main() {
    case "${1:-install}" in
        "install")
            install_monitoring_stack
            ;;
        "interactive")
            install_monitoring_interactive
            ;;
        "troubleshoot"|"diagnose")
            troubleshoot_monitoring
            ;;
        "validate")
            validate_component_installation "monitoring" 300
            ;;
        "verify")
            verify_component_deployment "monitoring" "monitoring"
            ;;
        "status")
            show_installation_summary
            ;;
        "guidance")
            show_component_guidance "monitoring"
            ;;
        *)
            echo "Usage: $0 [install|interactive|troubleshoot|validate|verify|status|guidance]"
            echo
            echo "Commands:"
            echo "  install      - Install monitoring stack"
            echo "  interactive  - Interactive installation with guidance"
            echo "  troubleshoot - Diagnose and troubleshoot issues"
            echo "  validate     - Validate installation"
            echo "  verify       - Verify deployment health"
            echo "  status       - Show component status"
            echo "  guidance     - Show post-installation guidance"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi