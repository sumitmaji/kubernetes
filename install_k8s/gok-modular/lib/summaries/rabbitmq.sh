#!/bin/bash

# RabbitMQ Summary Module
# This file contains summary functions specific to RabbitMQ installation status

# Show RabbitMQ installation summary
show_rabbitmq_summary() {
  log_info "=== RabbitMQ Installation Summary ==="

  # Check if RabbitMQ cluster is installed
  if kubectl get rabbitmqcluster rabbitmq -n rabbitmq >/dev/null 2>&1; then
    log_success "✓ RabbitMQ cluster found"

    # Get cluster status
    local cluster_status=$(kubectl get rabbitmqcluster rabbitmq -n rabbitmq -o jsonpath='{.status.conditions[?(@.type=="AllReplicasReady")].status}' 2>/dev/null)
    if [[ "$cluster_status" == "True" ]]; then
      log_success "✓ RabbitMQ cluster is ready"
    else
      log_warning "⚠ RabbitMQ cluster status: $cluster_status"
    fi

    # Get pod information
    local pod_count=$(kubectl get pods -l app.kubernetes.io/name=rabbitmq -n rabbitmq --no-headers 2>/dev/null | wc -l)
    local ready_count=$(kubectl get pods -l app.kubernetes.io/name=rabbitmq -n rabbitmq -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True")
    log_info "  Pods: $ready_count/$pod_count ready"

    # Get service info
    if kubectl get service rabbitmq -n rabbitmq >/dev/null 2>&1; then
      log_success "✓ RabbitMQ service found"
    fi

    # Get ingress info
    if kubectl get ingress rabbitmq-management -n rabbitmq >/dev/null 2>&1; then
      local ingress_hosts=$(kubectl get ingress rabbitmq-management -n rabbitmq -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
      log_success "✓ RabbitMQ management ingress configured"
      log_info "  Management URL: https://$ingress_hosts"
    fi

    # Get credentials info
    if kubectl get secret rabbitmq-default-user -n rabbitmq >/dev/null 2>&1; then
      log_success "✓ RabbitMQ default user credentials available"
      log_info "  Use 'kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath=\"{.data.username}\" | base64 --decode' to get username"
      log_info "  Use 'kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath=\"{.data.password}\" | base64 --decode' to get password"
    fi

    # Get persistent volume info
    local pv_count=$(kubectl get pvc -l app.kubernetes.io/name=rabbitmq -n rabbitmq --no-headers 2>/dev/null | wc -l)
    if [[ $pv_count -gt 0 ]]; then
      log_success "✓ RabbitMQ persistent storage configured ($pv_count PVCs)"
    fi

    log_info ""
    log_info "RabbitMQ cluster is configured with:"
    log_info "  - High availability clustering"
    log_info "  - Management UI access"
    log_info "  - Persistent message storage"
    log_info "  - Default user authentication"
    log_info "  - Ingress-based external access"

  else
    log_error "✗ RabbitMQ cluster not found"
    log_info "Run 'rabbitmqInst' to install RabbitMQ"
  fi

  log_info ""
}

export -f show_rabbitmq_summary