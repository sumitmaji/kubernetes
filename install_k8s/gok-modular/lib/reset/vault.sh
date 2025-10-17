#!/bin/bash

# Vault Reset Module
# This file contains reset/cleanup functions specific to Vault installation

# Reset Vault installation
vault_reset() {
  log_info "Resetting HashiCorp Vault installation..."

  # Confirm before proceeding
  if ! confirm_action "This will remove Vault and all its secrets. Continue?"; then
    log_info "Vault reset cancelled"
    return 0
  fi

  log_step "1" "Checking Vault installation status"
  local vault_exists=false
  local namespace_exists=false

  # Check if Vault helm release exists
  if helm list -n vault 2>/dev/null | grep -q "vault"; then
    vault_exists=true
    log_success "Vault helm release found"
  else
    log_info "Vault helm release not found (may already be uninstalled)"
  fi

  # Check if Vault namespace exists
  if kubectl get namespace vault >/dev/null 2>&1; then
    namespace_exists=true
    log_success "Vault namespace found"
  else
    log_info "Vault namespace not found (may already be deleted)"
  fi

  # If nothing exists, inform user and exit
  if [[ "$vault_exists" == false && "$namespace_exists" == false ]]; then
    log_info "Vault appears to already be reset or was never installed"
    return 0
  fi

  log_step "2" "Uninstalling Vault helm release"
  if [[ "$vault_exists" == true ]]; then
    if execute_with_suppression helm uninstall vault -n vault; then
      log_success "Vault helm release uninstalled successfully"
    else
      log_error "Failed to uninstall Vault helm release"
      return 1
    fi
  else
    log_info "Skipping helm uninstall (release not found)"
  fi

  log_step "3" "Cleaning up Vault persistent storage"
  if [[ "$namespace_exists" == true ]]; then
    log_substep "Removing persistent volume claims"
    if execute_with_suppression kubectl delete pvc --all -n vault --timeout=60s; then
      log_success "Vault PVCs removed successfully"
    else
      log_warning "Some PVCs may not have been removed"
    fi
  fi

  log_substep "Cleaning up persistent storage resources"
  if emptyLocalFsStorage "Vault" "vault-pv" "vault-storage" "/data/volumes/vault" >/dev/null 2>&1; then
    log_success "Vault persistent storage cleaned up"
  else
    log_warning "Some storage resources may not have been cleaned up"
  fi

  log_step "4" "Removing Vault namespace and related resources"
  if [[ "$namespace_exists" == true ]]; then
    if execute_with_suppression kubectl delete ns vault --timeout=120s; then
      log_success "Vault namespace removed successfully"
    else
      log_warning "Vault namespace removal had issues"
    fi
  fi

  log_step "5" "Cleaning up CSI Secrets Store driver"
  if execute_with_suppression csiDriverUnInstall; then
    log_success "CSI Secrets Store driver removed"
  else
    log_warning "CSI driver cleanup had issues"
  fi

  log_step "6" "Removing RBAC and system services"
  log_substep "Removing cluster role bindings"
  if execute_with_suppression kubectl delete clusterrolebinding vault-auth-delegator --timeout=30s; then
    log_success "Vault auth delegator role binding removed"
  else
    log_warning "Auth delegator role binding may not exist"
  fi

  log_substep "Stopping and removing Vault unseal service"
  if systemctl is-active --quiet vault-unseal.service 2>/dev/null; then
    execute_with_suppression systemctl stop vault-unseal.service
    log_success "Vault unseal service stopped"
  fi

  if systemctl is-enabled --quiet vault-unseal.service 2>/dev/null; then
    execute_with_suppression systemctl disable vault-unseal.service
    log_success "Vault unseal service disabled"
  fi

  if [[ -f "/etc/systemd/system/vault-unseal.service" ]]; then
    execute_with_suppression rm -f /etc/systemd/system/vault-unseal.service
    execute_with_suppression systemctl daemon-reload
    log_success "Vault unseal service files removed"
  fi

  log_success "Vault reset completed"
  log_info "You can reinstall Vault by running 'vaultInst'"
  log_warning "Note: All Vault secrets and configuration have been permanently removed"
}

export -f vault_reset