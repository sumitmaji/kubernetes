#!/bin/bash

# GOK Login Reset Functions
# This module handles the removal and cleanup of GOK Login components

gokLoginReset() {
  local start_time=$(date +%s)

  log_component_start "gok-login-reset" "Resetting GOK Login authentication service"

  log_step "1" "Checking GOK Login installation status"
  local gok_login_exists=false
  local namespace_exists=false

  # Check if GOK Login helm release exists
  if helm list -n gok-login 2>/dev/null | grep -q "gok-login"; then
    gok_login_exists=true
    log_success "GOK Login helm release found"
  else
    log_info "GOK Login helm release not found (may already be uninstalled)"
  fi

  # Check if GOK Login namespace exists
  if kubectl get namespace gok-login >/dev/null 2>&1; then
    namespace_exists=true
    log_success "GOK Login namespace found"
  else
    log_info "GOK Login namespace not found (may already be deleted)"
  fi

  # If nothing exists, inform user and exit
  if [[ "$gok_login_exists" == false && "$namespace_exists" == false ]]; then
    log_info "GOK Login appears to already be reset or was never installed"
    show_gok_login_reset_summary "already-reset"
    return 0
  fi

  log_step "2" "Uninstalling GOK Login helm release"
  if [[ "$gok_login_exists" == true ]]; then
    if execute_with_suppression helm uninstall gok-login -n gok-login; then
      log_success "GOK Login helm release uninstalled successfully"
    else
      log_error "Failed to uninstall GOK Login helm release"
      return 1
    fi
  else
    log_info "Skipping helm uninstall (release not found)"
  fi

  log_step "3" "Removing GOK Login namespace and resources"
  if [[ "$namespace_exists" == true ]]; then
    log_substep "Waiting for GOK Login pods to terminate..."
    local wait_count=0
    while kubectl get pods -n gok-login 2>/dev/null | grep -q "gok-login" && [[ $wait_count -lt 30 ]]; do
      printf "."
      sleep 2
      wait_count=$((wait_count + 1))
    done
    printf "\n"

    if [[ $wait_count -lt 30 ]]; then
      log_success "GOK Login pods terminated successfully"
    else
      log_warning "GOK Login pods taking longer than expected to terminate"
    fi

    if execute_with_suppression kubectl delete ns gok-login --timeout=120s; then
      log_success "GOK Login namespace removed successfully"
    else
      log_warning "GOK Login namespace removal had issues"
    fi
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log_component_success "gok-login-reset" "GOK Login reset completed successfully"
  show_gok_login_reset_summary "success" "$duration"
}

# Export the function to make it available
export -f gokLoginReset