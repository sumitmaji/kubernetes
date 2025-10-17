#!/bin/bash

# Vault Validation Module
# This file contains validation functions specific to Vault installation

# Validate Vault installation
validate_vault_installation() {
  local timeout="${1:-300}"
  local validation_passed=true

  log_info "Validating Vault installation with enhanced diagnostics..."
  local validation_passed=true

  log_step "1" "Checking Vault namespace"
  if kubectl get namespace vault >/dev/null 2>&1; then
    log_success "Vault namespace found"
  else
    log_error "Vault namespace not found"
    return 1
  fi

  log_step "2" "Checking Vault pods"
  if kubectl get pods -l app.kubernetes.io/name=vault -n vault >/dev/null 2>&1; then
    local pod_count=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault --no-headers 2>/dev/null | wc -l)
    local ready_count=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True")

    log_info "Found $pod_count Vault pod(s), $ready_count ready"

    if [[ $ready_count -eq $pod_count && $pod_count -gt 0 ]]; then
      log_success "All Vault pods are ready"
    else
      log_error "Not all Vault pods are ready ($ready_count/$pod_count)"
      validation_passed=false
    fi
  else
    log_error "No Vault pods found"
    validation_passed=false
  fi

  log_step "3" "Checking Vault service"
  if kubectl get service vault -n vault >/dev/null 2>&1; then
    log_success "Vault service found"

    # Check service endpoints
    local endpoints=$(kubectl get endpoints vault -n vault -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [[ -n "$endpoints" ]]; then
      log_success "Vault service has endpoints"
    else
      log_warning "Vault service has no endpoints"
    fi
  else
    log_error "Vault service not found"
    validation_passed=false
  fi

  log_step "4" "Checking Vault ingress"
  if kubectl get ingress vault -n vault >/dev/null 2>&1; then
    log_success "Vault ingress found"

    # Check ingress hosts
    local ingress_hosts=$(kubectl get ingress vault -n vault -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
    if [[ -n "$ingress_hosts" ]]; then
      log_success "Vault ingress configured for: $ingress_hosts"
    fi
  else
    log_warning "Vault ingress not found"
  fi

  log_step "5" "Checking Vault status"
  if kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
    local vault_pod=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}')

    # Check if Vault is initialized
    local init_status=$(kubectl exec -n vault $vault_pod -- vault status -format=json 2>/dev/null | jq -r '.initialized // "unknown"' 2>/dev/null)
    if [[ "$init_status" == "true" ]]; then
      log_success "Vault is initialized"
    else
      log_warning "Vault initialization status: $init_status"
      validation_passed=false
    fi

    # Check if Vault is unsealed
    local seal_status=$(kubectl exec -n vault $vault_pod -- vault status -format=json 2>/dev/null | jq -r '.sealed // "unknown"' 2>/dev/null)
    if [[ "$seal_status" == "false" ]]; then
      log_success "Vault is unsealed and ready"
    elif [[ "$seal_status" == "true" ]]; then
      log_warning "Vault is sealed - requires manual unsealing"
      validation_passed=false
    else
      log_warning "Could not determine Vault seal status"
    fi
  else
    log_error "Could not find Vault pod to check status"
    validation_passed=false
  fi

  log_step "6" "Checking Vault secrets engines"
  if kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
    local vault_pod=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}')

    # Check KV secrets engine
    local kv_enabled=$(kubectl exec -n vault $vault_pod -- vault secrets list -format=json 2>/dev/null | jq -r '.secret // "not found"' 2>/dev/null)
    if [[ "$kv_enabled" != "not found" && "$kv_enabled" != "null" ]]; then
      log_success "KV secrets engine is enabled"
    else
      log_warning "KV secrets engine not found"
    fi
  fi

  log_step "7" "Checking Vault authentication methods"
  if kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
    local vault_pod=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}')

    # Check Kubernetes auth method
    local k8s_auth=$(kubectl exec -n vault $vault_pod -- vault auth list -format=json 2>/dev/null | jq -r '.kubernetes // "not found"' 2>/dev/null)
    if [[ "$k8s_auth" != "not found" && "$k8s_auth" != "null" ]]; then
      log_success "Kubernetes authentication method is enabled"
    else
      log_warning "Kubernetes authentication method not found"
    fi
  fi

  log_step "8" "Checking Vault persistent storage"
  local pv_count=$(kubectl get pvc -l app.kubernetes.io/name=vault -n vault --no-headers 2>/dev/null | wc -l)
  if [[ $pv_count -gt 0 ]]; then
    log_success "Vault persistent storage configured ($pv_count PVCs)"
  else
    log_warning "No Vault persistent storage found"
  fi

  log_step "9" "Checking CSI Secrets Store driver"
  if kubectl get pods -l app=csi-secrets-store -n kube-system >/dev/null 2>&1; then
    local csi_count=$(kubectl get pods -l app=csi-secrets-store -n kube-system --no-headers 2>/dev/null | wc -l)
    local csi_ready=$(kubectl get pods -l app=csi-secrets-store -n kube-system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True")

    if [[ $csi_ready -eq $csi_count && $csi_count -gt 0 ]]; then
      log_success "CSI Secrets Store driver is ready ($csi_ready/$csi_count pods)"
    else
      log_warning "CSI Secrets Store driver not fully ready ($csi_ready/$csi_count pods)"
    fi
  else
    log_warning "CSI Secrets Store driver not found"
  fi

  return $([[ "$validation_passed" == "true" ]] && echo 0 || echo 1)
}

export -f validate_vault_installation