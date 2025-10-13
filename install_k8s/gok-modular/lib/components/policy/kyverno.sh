#!/bin/bash

# GOK Kyverno Policy Engine Component
# Provides Kubernetes policy-as-code enforcement and governance

# Kyverno policy engine installation
kyvernoInst(){
  log_component_start "kyverno" "Installing Kyverno policy engine for Kubernetes governance"

  log_step "1" "Adding Kyverno Helm repository"
  execute_with_suppression helm repo add kyverno https://kyverno.github.io/kyverno/
  execute_with_suppression helm repo update

  log_step "2" "Installing Kyverno via Helm"
  if helm_install_with_summary "kyverno" "kyverno" \
    kyverno --namespace kyverno kyverno/kyverno --create-namespace; then

    log_step "3" "Waiting for Kyverno services to be ready"
    waitForServiceAvailable kyverno
    log_success "Kyverno services are now operational"

    log_step "4" "Configuring cluster-admin permissions"
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kyverno:cloud-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kyverno-admission-controller
  namespace: kyverno
- kind: ServiceAccount
  name: kyverno-background-controller
  namespace: kyverno
EOF
    if [[ $? -eq 0 ]]; then
      log_success "Cluster-admin permissions configured for Kyverno"
    else
      log_warning "Cluster-admin permissions may already exist"
    fi

    log_step "5" "Creating secret synchronization policies"
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sync-secrets
spec:
  rules:
  - name: sync-image-pull-secret
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      apiVersion: v1
      kind: Secret
      name: regcred
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      clone:
        namespace: kube-system
        name: regcred
  - name: sync-oauth-secrets
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      apiVersion: v1
      kind: Secret
      name: oauth-secrets
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      clone:
        namespace: kube-system
        name: oauth-secrets
  - name: sync-opensearch-secrets
    match:
      any:
      - resources:
          kinds:
          - Namespace
    generate:
      apiVersion: v1
      kind: Secret
      name: opensearch-secrets
      namespace: "{{request.object.metadata.name}}"
      synchronize: true
      clone:
        namespace: kube-system
        name: opensearch-secrets
EOF
    if [[ $? -eq 0 ]]; then
      log_success "Secret synchronization policies created"
    else
      log_warning "Secret synchronization policies may already exist"
    fi

    log_component_success "kyverno" "Kyverno policy engine installed successfully"
  else
    log_error "Kyverno installation failed"
    return 1
  fi
}

# Export functions for use by other modules
export -f kyvernoInst