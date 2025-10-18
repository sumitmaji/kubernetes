#!/bin/bash

# RabbitMQ Reset Module
# This file contains reset/cleanup functions specific to RabbitMQ installation

# Reset RabbitMQ installation
rabbitmq_reset(){
  local start_time=$(date +%s)

  log_component_start "rabbitmq-reset" "Resetting RabbitMQ message broker system"

  log_step "1" "Checking RabbitMQ installation status"
  local cluster_exists=false
  local namespace_exists=false
  local operator_exists=false

  # Check if RabbitMQ cluster exists
  if kubectl get rabbitmqcluster rabbitmq -n rabbitmq >/dev/null 2>&1; then
    cluster_exists=true
    log_success "RabbitMQ cluster found"
  else
    log_info "RabbitMQ cluster not found (may already be deleted)"
  fi

  # Check if RabbitMQ namespace exists
  if kubectl get namespace rabbitmq >/dev/null 2>&1; then
    namespace_exists=true
    log_success "RabbitMQ namespace found"
  else
    log_info "RabbitMQ namespace not found (may already be deleted)"
  fi

  # Check if RabbitMQ operator exists
  if kubectl get deployment rabbitmq-cluster-operator -n rabbitmq-system >/dev/null 2>&1; then
    operator_exists=true
    log_success "RabbitMQ cluster operator found"
  else
    log_info "RabbitMQ cluster operator not found (may already be deleted)"
  fi

  # If nothing exists, inform user and exit
  if [[ "$cluster_exists" == false && "$namespace_exists" == false && "$operator_exists" == false ]]; then
    log_info "RabbitMQ appears to already be reset or was never installed"
    log_component_success "rabbitmq-reset" "RabbitMQ reset completed (nothing to reset)"
    # return 0
  fi

  log_step "2" "Removing RabbitMQ cluster"
  if [[ "$cluster_exists" == true ]]; then
    log_substep "Deleting RabbitMQ cluster resource"
    if execute_with_suppression kubectl delete rabbitmqcluster rabbitmq -n rabbitmq --ignore-not-found=true; then
      log_success "RabbitMQ cluster deletion initiated"

      # Wait for cluster to be removed
      log_substep "Waiting for RabbitMQ cluster to be fully removed..."
      local wait_count=0
      while kubectl get rabbitmqcluster rabbitmq -n rabbitmq >/dev/null 2>&1 && [[ $wait_count -lt 60 ]]; do
        printf "."
        sleep 2
        wait_count=$((wait_count + 1))
      done
      printf "\n"

      if [[ $wait_count -lt 60 ]]; then
        log_success "RabbitMQ cluster removed successfully"
      else
        log_warning "RabbitMQ cluster removal taking longer than expected"
      fi
    else
      log_error "Failed to delete RabbitMQ cluster"
      return 1
    fi
  else
    log_info "Skipping cluster deletion (cluster not found)"
  fi

  log_step "3" "Removing RabbitMQ cluster operator"
  if [[ "$operator_exists" == true ]]; then
    log_substep "Deleting RabbitMQ cluster operator"
    if execute_with_suppression kubectl delete -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --ignore-not-found=true; then
      log_success "RabbitMQ cluster operator deletion initiated"

      # Wait for operator to be removed
      log_substep "Waiting for RabbitMQ operator to be fully removed..."
      local wait_count=0
      while kubectl get deployment rabbitmq-cluster-operator -n rabbitmq-system >/dev/null 2>&1 && [[ $wait_count -lt 30 ]]; do
        printf "."
        sleep 2
        wait_count=$((wait_count + 1))
      done
      printf "\n"

      if [[ $wait_count -lt 30 ]]; then
        log_success "RabbitMQ cluster operator removed successfully"
      else
        log_warning "RabbitMQ operator removal taking longer than expected"
      fi
    else
      log_warning "RabbitMQ cluster operator deletion had issues but continuing"
    fi
  else
    log_info "Skipping operator deletion (operator not found)"
  fi

  log_step "4" "Cleaning up persistent volumes and storage"
  if [[ "$namespace_exists" == true ]]; then
    # Clean up local storage
    log_substep "Cleaning up local filesystem storage..."
    if emptyLocalFsStorage "RabbitMQ" "rabbitmq-pv" "rabbitmq-storage" "/data/volumes/rabbitmq" "rabbitmq"; then
      log_success "Local filesystem storage cleaned up"
    else
      log_warning "Local storage cleanup had issues but continuing"
    fi
  else
    log_info "Skipping storage cleanup (namespace not found)"
  fi

  log_step "5" "Removing RabbitMQ namespace and resources"
  if [[ "$namespace_exists" == true ]]; then
    log_substep "Deleting RabbitMQ namespace"
    if execute_with_suppression kubectl delete namespace rabbitmq --timeout=120s --ignore-not-found=true; then
      log_success "RabbitMQ namespace deleted successfully"
    else
      log_warning "RabbitMQ namespace deletion had issues but may still complete"

      # Try to force delete if needed
      log_substep "Attempting force cleanup..."
      if execute_with_suppression kubectl delete namespace rabbitmq --force --grace-period=0 --ignore-not-found=true 2>/dev/null; then
        log_success "RabbitMQ namespace force-deleted successfully"
      else
        log_warning "Force deletion also had issues - manual cleanup may be needed"
      fi
    fi
  else
    log_info "Skipping namespace deletion (namespace not found)"
  fi

  log_step "6" "Cleaning up RabbitMQ-related resources"

  # Clean up any remaining RabbitMQ-related ingress resources
  local ingress_cleaned=false
  if kubectl get ingress -A 2>/dev/null | grep -q "rabbitmq"; then
    log_substep "Removing RabbitMQ ingress resources..."
    if execute_with_suppression kubectl delete ingress -l app.kubernetes.io/name=rabbitmq --all-namespaces --ignore-not-found=true 2>/dev/null; then
      ingress_cleaned=true
      log_success "RabbitMQ ingress resources cleaned up"
    else
      log_warning "Some RabbitMQ ingress resources may remain"
    fi
  fi

  # Clean up any remaining RabbitMQ-related certificates
  local certs_cleaned=false
  if kubectl get certificates -A 2>/dev/null | grep -q "rabbitmq"; then
    log_substep "Removing RabbitMQ TLS certificates..."
    if execute_with_suppression kubectl delete certificates -l app.kubernetes.io/name=rabbitmq --all-namespaces --ignore-not-found=true 2>/dev/null; then
      certs_cleaned=true
      log_success "RabbitMQ certificates cleaned up"
    else
      log_warning "Some RabbitMQ certificates may remain"
    fi
  fi

  # Clean up RabbitMQ-related storage classes and persistent volumes
  local storage_cleaned=false
  if kubectl get storageclass rabbitmq-storage >/dev/null 2>&1; then
    log_substep "Removing RabbitMQ storage resources..."
    if execute_with_suppression kubectl delete storageclass rabbitmq-storage --ignore-not-found=true 2>/dev/null; then
      storage_cleaned=true
      log_success "RabbitMQ storage class cleaned up"
    fi
  fi

  if kubectl get pv rabbitmq-pv >/dev/null 2>&1; then
    if execute_with_suppression kubectl delete pv rabbitmq-pv --ignore-not-found=true 2>/dev/null; then
      storage_cleaned=true
      log_success "RabbitMQ persistent volume cleaned up"
    fi
  fi

  if [[ "$ingress_cleaned" == false && "$certs_cleaned" == false && "$storage_cleaned" == false ]]; then
    log_info "No additional RabbitMQ resources found to clean up"
  fi

  log_step "7" "Validating RabbitMQ reset completion"
  validate_rabbitmq_reset

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log_component_success "rabbitmq-reset" "RabbitMQ message broker system reset completed"
  log_success "RabbitMQ reset completed in ${duration}s"

  # Show reset summary
  show_rabbitmq_reset_summary
}

# Validate that RabbitMQ reset was successful
validate_rabbitmq_reset() {
  local validation_success=true

  # Check that RabbitMQ cluster is gone
  if kubectl get rabbitmqcluster rabbitmq -n rabbitmq >/dev/null 2>&1; then
    log_error "RabbitMQ cluster still exists"
    validation_success=false
  else
    log_success "RabbitMQ cluster successfully removed"
  fi

  # Check that namespace is gone
  if kubectl get namespace rabbitmq >/dev/null 2>&1; then
    log_error "RabbitMQ namespace still exists"
    validation_success=false
  else
    log_success "RabbitMQ namespace successfully removed"
  fi

  # Check that operator is gone
  if kubectl get deployment rabbitmq-cluster-operator -n rabbitmq-system >/dev/null 2>&1; then
    log_warning "RabbitMQ cluster operator still exists (may be used by other clusters)"
  else
    log_success "RabbitMQ cluster operator successfully removed"
  fi

  if [[ "$validation_success" == true ]]; then
    log_success "RabbitMQ reset validation completed successfully"
  else
    log_warning "RabbitMQ reset validation found some remaining resources"
  fi
}

# Show RabbitMQ reset summary
show_rabbitmq_reset_summary() {
  echo ""
  echo -e "${COLOR_BRIGHT_RED}${COLOR_BOLD}🗑️  RABBITMQ RESET SUMMARY${COLOR_RESET}"
  echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_GREEN}✅ RabbitMQ cluster removed${COLOR_RESET}"
  echo -e "${COLOR_GREEN}✅ RabbitMQ namespace deleted${COLOR_RESET}"
  echo -e "${COLOR_GREEN}✅ Persistent storage cleaned up${COLOR_RESET}"
  echo -e "${COLOR_GREEN}✅ Ingress resources removed${COLOR_RESET}"
  echo -e "${COLOR_GREEN}✅ TLS certificates cleaned up${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BRIGHT_YELLOW}💡 Next Steps:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}• Run 'gok status' to verify RabbitMQ is completely removed${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}• Run 'gok install rabbitmq' to reinstall if needed${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}• Check disk space: 'df -h /data/volumes'${COLOR_RESET}"
  echo ""
}

export -f rabbitmq_reset