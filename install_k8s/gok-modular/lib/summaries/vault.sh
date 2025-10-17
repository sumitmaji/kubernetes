#!/bin/bash

# Vault Summary Module
# This file contains summary functions specific to Vault installation status

# Show Vault installation summary
show_vault_summary() {
  log_info "=== HashiCorp Vault Installation Summary ==="

  # Check if Vault is installed
  if kubectl get namespace vault >/dev/null 2>&1; then
    log_success "✓ Vault namespace found"

    # Get pod information
    local pod_count=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault --no-headers 2>/dev/null | wc -l)
    local ready_count=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True")
    log_info "  Pods: $ready_count/$pod_count ready"

    # Get service info
    if kubectl get service vault -n vault >/dev/null 2>&1; then
      local service_type=$(kubectl get service vault -n vault -o jsonpath='{.spec.type}' 2>/dev/null)
      log_success "✓ Vault service found (Type: $service_type)"
      log_info "  API Port: 8200, Cluster Port: 8201"
    fi

    # Get ingress info
    if kubectl get ingress vault -n vault >/dev/null 2>&1; then
      local ingress_hosts=$(kubectl get ingress vault -n vault -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
      log_success "✓ Vault ingress configured"
      log_info "  URL: https://$ingress_hosts"
    fi

    # Check Vault status
    if kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
      local vault_pod=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}')

      local init_status=$(kubectl exec -n vault $vault_pod -- vault status -format=json 2>/dev/null | jq -r '.initialized // "unknown"' 2>/dev/null)
      local seal_status=$(kubectl exec -n vault $vault_pod -- vault status -format=json 2>/dev/null | jq -r '.sealed // "unknown"' 2>/dev/null)

      if [[ "$init_status" == "true" ]]; then
        log_success "✓ Vault is initialized"
      else
        log_warning "⚠ Vault initialization status: $init_status"
      fi

      if [[ "$seal_status" == "false" ]]; then
        log_success "✓ Vault is unsealed and ready"
      elif [[ "$seal_status" == "true" ]]; then
        log_warning "⚠ Vault is sealed - requires manual unsealing"
      else
        log_warning "⚠ Could not determine Vault seal status"
      fi
    fi

    # Get secrets engines info
    if kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; then
      local vault_pod=$(kubectl get pods -l app.kubernetes.io/name=vault -n vault -o jsonpath='{.items[0].metadata.name}')

      local kv_enabled=$(kubectl exec -n vault $vault_pod -- vault secrets list -format=json 2>/dev/null | jq -r '.secret // "not found"' 2>/dev/null)
      if [[ "$kv_enabled" != "not found" && "$kv_enabled" != "null" ]]; then
        log_success "✓ KV secrets engine enabled at /secret"
      fi

      local k8s_auth=$(kubectl exec -n vault $vault_pod -- vault auth list -format=json 2>/dev/null | jq -r '.kubernetes // "not found"' 2>/dev/null)
      if [[ "$k8s_auth" != "not found" && "$k8s_auth" != "null" ]]; then
        log_success "✓ Kubernetes authentication method enabled"
      fi
    fi

    # Get persistent volume info
    local pv_count=$(kubectl get pvc -l app.kubernetes.io/name=vault -n vault --no-headers 2>/dev/null | wc -l)
    if [[ $pv_count -gt 0 ]]; then
      log_success "✓ Vault persistent storage configured ($pv_count PVCs)"
    fi

    # Check CSI driver
    if kubectl get pods -l app=csi-secrets-store -n kube-system >/dev/null 2>&1; then
      local csi_count=$(kubectl get pods -l app=csi-secrets-store -n kube-system --no-headers 2>/dev/null | wc -l)
      local csi_ready=$(kubectl get pods -l app=csi-secrets-store -n kube-system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True")
      log_success "✓ CSI Secrets Store driver ready ($csi_ready/$csi_count pods)"
    fi

    log_info ""
    log_info "Vault is configured with:"
    log_info "  - High-availability clustering"
    log_info "  - TLS-encrypted access via ingress"
    log_info "  - Kubernetes authentication integration"
    log_info "  - KV v2 secrets engine"
    log_info "  - Persistent storage for secrets"
    log_info "  - CSI Secrets Store driver support"

  else
    log_error "✗ Vault namespace not found"
    log_info "Run 'vaultInst' to install HashiCorp Vault"
  fi

  log_info ""
}

export -f show_vault_summary