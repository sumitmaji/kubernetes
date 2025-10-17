#!/bin/bash

# RabbitMQ Reset Module
# This file contains reset/cleanup functions specific to RabbitMQ installation

# Reset RabbitMQ installation
rabbitmq_reset() {
  log_info "Resetting RabbitMQ installation..."

  # Confirm before proceeding
  if ! confirm_action "This will remove RabbitMQ cluster and all its data. Continue?"; then
    log_info "RabbitMQ reset cancelled"
    return 0
  fi

  log_step "1" "Removing RabbitMQ namespace and all resources"
  kubectl delete namespace rabbitmq --ignore-not-found=true --timeout=300s

  log_step "2" "Removing RabbitMQ system namespace (cluster operator)"
  kubectl delete namespace rabbitmq-system --ignore-not-found=true --timeout=300s

  # Wait for namespace deletions
  log_info "Waiting for namespace deletions to complete..."
  local timeout=120
  local count=0
  while (kubectl get namespace rabbitmq >/dev/null 2>&1 || kubectl get namespace rabbitmq-system >/dev/null 2>&1) && [ $count -lt $timeout ]; do
    sleep 5
    count=$((count + 5))
    log_info "Still waiting... (${count}s/${timeout}s)"
  done

  if kubectl get namespace rabbitmq >/dev/null 2>&1; then
    log_warning "RabbitMQ namespace still exists. Manual cleanup may be required."
  else
    log_success "RabbitMQ namespace deleted successfully"
  fi

  if kubectl get namespace rabbitmq-system >/dev/null 2>&1; then
    log_warning "RabbitMQ system namespace still exists. Manual cleanup may be required."
  else
    log_success "RabbitMQ system namespace deleted successfully"
  fi

  log_step "3" "Cleaning up persistent volumes (WARNING: This will delete all RabbitMQ data)"
  # Find and delete PVCs that might remain
  local pvcs=$(kubectl get pvc --all-namespaces -l app.kubernetes.io/name=rabbitmq -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [[ -n "$pvcs" ]]; then
    log_warning "Found persistent volume claims that may contain RabbitMQ data:"
    echo "$pvcs" | tr ' ' '\n' | while read pvc; do
      log_info "  - $pvc"
    done

    if confirm_action "Delete these persistent volume claims? This will permanently remove all RabbitMQ data."; then
      kubectl delete pvc -l app.kubernetes.io/name=rabbitmq --all-namespaces --ignore-not-found=true
      log_info "Persistent volume claims deleted"
    else
      log_warning "Persistent volume claims not deleted. Manual cleanup required if reinstalling."
    fi
  fi

  log_step "4" "Cleaning up any remaining RabbitMQ CRDs"
  kubectl delete crd rabbitmqclusters.rabbitmq.com --ignore-not-found=true

  log_success "RabbitMQ reset completed"
  log_info "You can reinstall RabbitMQ by running 'rabbitmqInst'"
  log_warning "Note: If you deleted persistent volumes, all RabbitMQ data was permanently removed"
}

export -f rabbitmq_reset