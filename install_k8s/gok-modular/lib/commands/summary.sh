#!/bin/bash

# GOK Summary Command Module - Display component installation summaries

# Main summary command handler
summaryCmd() {
    local component="$1"
    local namespace="${2:-default}"

    if [[ -z "$component" || "$component" == "help" || "$component" == "--help" ]]; then
        show_summary_help
        return 0
    fi

    # Load summaries module if not already loaded
    if ! declare -f show_component_summary >/dev/null 2>&1; then
        if [[ -f "${GOK_LIB_DIR}/utils/summaries.sh" ]]; then
            source "${GOK_LIB_DIR}/utils/summaries.sh"
        else
            log_error "Summaries module not found"
            return 1
        fi
    fi

    # Call the component summary function
    if declare -f show_component_summary >/dev/null 2>&1; then
        show_component_summary "$component" "$namespace"
    else
        log_error "Component summary function not available"
        return 1
    fi
}

# Show help for summary command
show_summary_help() {
    echo "Usage: gok summary <component> [namespace]"
    echo
    echo "Display installation summary for a specific component"
    echo
    echo "Available components:"
    echo "  docker           Docker installation summary"
    echo "  kubernetes       Kubernetes cluster summary"
    echo "  haproxy          HAProxy load balancer summary"
    echo "  helm             Helm package manager summary"
    echo "  calico           Calico networking summary"
    echo "  ingress          Ingress controller summary"
    echo "  cert-manager     Certificate manager summary"
    echo "  keycloak         Keycloak identity provider summary"
    echo "  jupyter          Jupyter notebook summary"
    echo "  argocd           ArgoCD GitOps summary"
    echo
    echo "Examples:"
    echo "  gok summary kubernetes           Show Kubernetes summary"
    echo "  gok summary cert-manager         Show cert-manager summary"
    echo "  gok summary ingress kube-system  Show ingress summary in kube-system namespace"
}