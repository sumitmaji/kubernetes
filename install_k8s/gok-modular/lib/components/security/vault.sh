#!/bin/bash

# Vault Installation Module
# This file contains the Vault secrets management installation function

# Install HashiCorp Vault
vaultInst() {
  local start_time=$(date +%s)

  log_component_start "vault-install" "Installing HashiCorp Vault secrets management system"

  log_step "1" "Installing CSI Secrets Store driver"
  log_substep "Adding CSI Secrets Store Helm repository"
  if execute_with_suppression helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts; then
    log_success "CSI Secrets Store Helm repository added"
  else
    log_info "CSI Secrets Store repository may already exist"
  fi

  log_substep "Updating Helm repositories"
  if execute_with_suppression helm repo update; then
    log_success "Helm repositories updated"
  else
    log_warning "Helm repository update had issues but continuing"
  fi

  log_substep "Installing CSI Secrets Store driver"
  if execute_with_suppression helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system; then
    log_success "CSI Secrets Store driver installed successfully"
  else
    log_error "Failed to install CSI Secrets Store driver"
    return 1
  fi

  log_step "2" "Creating Vault namespace and storage"
  log_substep "Creating namespace: vault"
  if kubectl create namespace vault >/dev/null 2>&1; then
    log_success "Vault namespace created"
  else
    log_info "Vault namespace already exists"
  fi

  # Create local storage class and persistent volume
  STORAGE_CLASS_NAME="vault-storage"
  PV_NAME="vault-pv"
  VOLUME_PATH="/data/volumes/vault"

  log_substep "Creating persistent storage (10Gi local volume)"
  if createLocalStorageClassAndPV "$STORAGE_CLASS_NAME" "$PV_NAME" "$VOLUME_PATH"; then
    log_success "Vault persistent storage created"
    log_info "📁 Storage: 10Gi at /data/volumes/vault"
  else
    log_warning "Vault storage creation had issues but continuing"
  fi

  log_step "3" "Installing Vault via Helm"
  log_substep "Adding HashiCorp Helm repository"
  if execute_with_suppression helm repo add hashicorp https://helm.releases.hashicorp.com; then
    log_success "HashiCorp Helm repository added"
  else
    log_info "HashiCorp repository may already exist"
  fi

  log_substep "Updating Helm repositories"
  if execute_with_suppression helm repo update; then
    log_success "Helm repositories updated"
  else
    log_warning "Helm repository update had issues but continuing"
  fi

  log_substep "Installing Vault using Helm"
  if execute_with_suppression helm install vault hashicorp/vault --namespace vault --values $MOUNT_PATH/kubernetes/install_k8s/vault/values.yaml; then
    log_success "Vault Helm chart installed successfully"
  else
    log_error "Failed to install Vault via Helm"
    return 1
  fi

  log_step "4" "Configuring Vault ingress and TLS"
  log_substep "Patching Vault ingress for domain routing"
  if execute_with_suppression kubectl patch ingress vault -n vault --type=merge -p '{"spec":{"rules":[{"host":"vault.'$(rootDomain)'","http":{"paths":[{"path":"/","pathType":"Prefix","backend":{"service":{"name":"vault","port":{"number":8200}}}}]}}]}}'; then
    log_success "Vault ingress routing configured"
  else
    log_warning "Vault ingress routing had issues but continuing"
  fi

  log_substep "Applying Let's Encrypt certificate to Vault ingress"
  if execute_with_suppression gok patch ingress vault vault letsencrypt vault; then
    log_success "Vault TLS certificate configured"
  else
    log_error "Failed to configure Vault TLS certificate"
    return 1
  fi

  log_step "5" "Initializing Vault cluster"
  log_substep "Starting Vault initialization and unseal process"
  log_info "🔐 Initializing Vault cluster - this may take a few minutes"

  # Build and deploy Vault unsealer
  build_vault_with_progress
  if [[ $? -ne 0 ]]; then
    log_error "Vault unsealer build failed"
    return 1
  fi

  # Continue with Vault initialization
  log_substep "Applying Vault unsealer Kubernetes role"
  if execute_with_suppression kubectl apply -f $MOUNT_PATH/kubernetes/install_k8s/vault/vault-k8s-seal-role.yaml; then
    log_success "Vault unsealer Kubernetes role applied"
  else
    log_warning "Vault unsealer role application had issues but continuing"
  fi

  log_substep "Waiting for Kyverno to propagate registry credentials to Vault namespace"
  local wait_start=$(date +%s)
  local timeout=60
  local found_secret=false
  
  # Wait for Kyverno to copy the secret automatically
  while [[ $(($(date +%s) - wait_start)) -lt $timeout ]]; do
    if kubectl get secret regcred -n vault >/dev/null 2>&1; then
      found_secret=true
      break
    fi
    sleep 3
  done
  
  if [[ "$found_secret" == "true" ]]; then
    log_success "Registry credentials automatically propagated by Kyverno"
  else
    log_info "Kyverno auto-propagation timed out, attempting manual copy"
    if execute_with_suppression copySecret regcred kube-system vault; then
      log_success "Registry credentials manually copied to Vault namespace"
    else
      log_warning "Registry credentials not available - continuing without private registry access"
    fi
  fi


  log_substep "Patching Vault service account with image pull secrets"
  if execute_with_suppression kubectl patch serviceaccount vault -p '{"imagePullSecrets": [{"name": "regcred"}]}' -n vault; then
    log_success "Vault service account patched with image pull secrets"
  else
    log_warning "Service account patching had issues but continuing"
  fi

  log_substep "Creating Vault keys directory"
  if execute_with_suppression mkdir -p $MOUNT_PATH/vault-keys; then
    log_success "Vault keys directory created"
  else
    log_warning "Vault keys directory creation had issues but continuing"
  fi

  log_substep "Applying Vault initialization job"
  if execute_with_suppression kubectl apply -f $MOUNT_PATH/kubernetes/install_k8s/vault/vault-init-unseal-job.yaml; then
    log_success "Vault initialization job applied"
  else
    log_error "Failed to apply Vault initialization job"
    return 1
  fi

  log_substep "Waiting for Vault initialization to complete"
  if kubectl wait --for=condition=complete job.batch/vault-init-unseal -n vault --timeout=300s >/dev/null 2>&1; then
    local status=$(kubectl get job vault-init-unseal -n vault -o jsonpath='{.status.succeeded}' 2>/dev/null)
    if [[ "$status" -eq 1 ]]; then
      log_success "Vault initialization and unseal completed successfully"
      if execute_with_suppression kubectl delete -f $MOUNT_PATH/kubernetes/install_k8s/vault/vault-init-unseal-job.yaml; then
        log_success "Vault initialization job cleaned up"
      fi
    else
      log_error "Vault initialization job did not complete successfully"
      return 1
    fi
  else
    log_error "Vault initialization timed out"
    return 1
  fi

  log_substep "Installing Vault unseal systemd service"
  if execute_with_suppression pushd $MOUNT_PATH/kubernetes/install_k8s/vault; then
    if execute_with_suppression chmod +x *.sh && ./install-vault-unseal-service.sh; then
      log_success "Vault unseal systemd service installed"
    else
      log_warning "Vault unseal service installation had issues but continuing"
    fi
    execute_with_suppression popd
  else
    log_warning "Could not access Vault directory for service installation"
  fi

  log_substep "Waiting for Vault services to be ready"
  if wait_for_pods_ready "vault" "300" "Vault"; then
    log_success "All Vault services are now ready"
  else
    log_error "Vault services failed to become ready within timeout"
    return 1
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_success "Vault unsealer setup completed in ${duration}s"

  log_step "6" "Configuring Vault authentication and policies"
  log_substep "Creating Kubernetes authentication method"
  if execute_with_suppression kubectl create clusterrolebinding vault-auth-delegator --clusterrole=system:auth-delegator --serviceaccount=vault:vault; then
    log_success "Vault auth delegator role binding created"
  else
    log_warning "Vault auth delegator creation had issues but continuing"
  fi

  log_substep "Authenticating with Vault"
  if vaultLogin; then
    log_success "Vault authentication completed"
  else
    log_error "Vault authentication failed"
    return 1
  fi

  log_substep "Enabling Kubernetes auth method"
  if execute_with_suppression kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes; then
    log_success "Kubernetes auth method enabled"
  else
    log_error "Failed to enable Kubernetes auth method"
    return 1
  fi

  log_substep "Configuring Kubernetes auth with cluster details"
  local token=$(kubectl exec -it vault-0 -n vault -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
  if [[ -n "$token" ]]; then
    if execute_with_suppression kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config token_reviewer_jwt="$token" kubernetes_host="https://11.0.0.1:6643" kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt; then
      log_success "Kubernetes auth configured with cluster details"
    else
      log_warning "Kubernetes auth configuration had issues but continuing"
    fi
  else
    log_warning "Could not retrieve service account token for Kubernetes auth"
  fi

  log_substep "Enabling KV secrets engine"
  if execute_with_suppression kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv; then
    log_success "KV secrets engine enabled at /secret"
  else
    log_warning "KV secrets engine enablement had issues but continuing"
  fi

  log_step "7" "Creating GOK Vault secrets"
  log_substep "Setting up GOK-specific secrets in Vault"
  if execute_with_suppression pushd $MOUNT_PATH/kubernetes/install_k8s/vault; then
    if ./create_gok_vault_secrets.sh; then
      log_success "GOK Vault secrets created successfully"
    else
      log_warning "GOK Vault secrets creation had issues but continuing"
    fi
    execute_with_suppression popd
  else
    log_warning "Could not access Vault secrets directory"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

#   show_installation_summary "vault" "vault" "HashiCorp Vault secrets management"
  log_component_success "vault-install" "HashiCorp Vault installed successfully"
  log_success "Vault installation completed in ${duration}s"

  # Show Vault access information
  log_info "🔐 Vault Access Information:"
  log_info "  🌐 URL: https://$(fullVaultUrl)"
  log_info "  🔑 Authentication: Kubernetes service account token"
  log_info "  📚 Secrets Engine: KV v2 at /secret"
  log_info "  🔧 Next Steps: Configure additional auth methods and policies as needed"
}

# Enhanced Vault unsealer build with detailed progress tracking
build_vault_with_progress() {
  local start_time=$(date +%s)

  # Source configuration to get image details
  if [[ ! -f "$MOUNT_PATH/kubernetes/install_k8s/vault/configuration" ]]; then
    log_error "Vault configuration file not found"
    return 1
  fi
    
  # Store GOK modular registry URL before sourcing old config  
  local gok_registry_url
  if [[ -n "$REGISTRY" && -n "$GOK_ROOT_DOMAIN" ]]; then
    gok_registry_url="${REGISTRY}.${GOK_ROOT_DOMAIN}"
  else
    gok_registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
  fi

  source "$MOUNT_PATH/kubernetes/install_k8s/vault/configuration"
  source "$MOUNT_PATH/kubernetes/install_k8s/util" 2>/dev/null || true

  # Get registry and image information
  local registry_url="${gok_registry_url}"
  local image_name="${IMAGE_NAME:-sumit/vault-with-tools}"
  local repo_name="${REPO_NAME:-vault-with-tools}"
  local full_image_url="${registry_url}/${repo_name}"

  log_substep "Registry: ${COLOR_CYAN}${registry_url}${COLOR_RESET}"
  log_substep "Image: ${COLOR_CYAN}${image_name}${COLOR_RESET}"
  log_substep "Target: ${COLOR_CYAN}${full_image_url}${COLOR_RESET}"

  # Step 1: Docker Build with Progress
  log_info "🐳 Building Vault unsealer Docker image: ${COLOR_BOLD}${image_name}${COLOR_RESET}"

  local temp_build_log=$(mktemp)
  local temp_build_error=$(mktemp)

  # Start Docker build in background
  docker build -t "$image_name" "$MOUNT_PATH/kubernetes/install_k8s/vault" >"$temp_build_log" 2>"$temp_build_error" &
  local build_pid=$!

  # Show build progress with Vault-specific stages
  local build_progress=0
  local build_steps=8
  local spinner_chars="|/-\\"
  local spinner_idx=0
  local build_stage="Initializing"

  while kill -0 $build_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    build_progress=$(( (build_progress + 1) % (build_steps * 8) ))
    local progress_percent=$(( build_progress * 100 / (build_steps * 8) ))

    # Update stage based on progress
    case $((build_progress / 8)) in
      0) build_stage="Preparing base image" ;;
      1) build_stage="Installing system packages" ;;
      2) build_stage="Installing Vault client" ;;
      3) build_stage="Installing utilities" ;;
      4) build_stage="Setting up scripts" ;;
      5) build_stage="Configuring permissions" ;;
      6) build_stage="Cleaning up packages" ;;
      7) build_stage="Finalizing Vault image" ;;
    esac

    printf "\r${COLOR_BLUE}  Building Vault unsealer [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$build_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.4
  done

  wait $build_pid
  local build_exit_code=$?

  if [[ $build_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ Vault unsealer build completed [100%%]${COLOR_RESET}\n"
    log_success "Vault unsealer Docker image built successfully: ${image_name}"

    # Show warnings if present but don't fail
    if is_verbose_mode && [[ -s "$temp_build_log" ]]; then
      if grep -q "warning" "$temp_build_log"; then
        log_info "Build warnings (non-critical):"
        grep -i "warning" "$temp_build_log" | head -5 | while read line; do
          log_warning "  $line"
        done
      fi
    fi
  else
    printf "\r${COLOR_RED}  ✗ Vault unsealer build failed${COLOR_RESET}\n"
    log_error "Vault unsealer Docker build failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 2: Docker Tag
  log_info "🏷️  Tagging Vault unsealer image for registry: ${COLOR_BOLD}${full_image_url}${COLOR_RESET}"
  if docker tag "$image_name" "$full_image_url" >/dev/null 2>&1; then
    log_success "Vault unsealer image tagged successfully"
  else
    log_error "Failed to tag Vault unsealer Docker image"
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 3: Docker Push with Progress
  log_info "📤 Pushing Vault unsealer image to registry: ${COLOR_BOLD}${registry_url}${COLOR_RESET}"
  log_substep "Target repository: ${COLOR_CYAN}${repo_name}${COLOR_RESET}"

  # Start Docker push in background
  docker push "$full_image_url" >"$temp_build_log" 2>"$temp_build_error" &
  local push_pid=$!

  # Show push progress with Vault-specific stages
  local push_progress=0
  local push_steps=6
  local push_stage="Preparing"

  while kill -0 $push_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    push_progress=$(( (push_progress + 1) % (push_steps * 12) ))
    local progress_percent=$(( push_progress * 100 / (push_steps * 12) ))

    # Update stage based on progress
    case $((push_progress / 12)) in
      0) push_stage="Authenticating with registry" ;;
      1) push_stage="Preparing image layers" ;;
      2) push_stage="Uploading image layers" ;;
      3) push_stage="Pushing configuration" ;;
      4) push_stage="Finalizing upload" ;;
      5) push_stage="Image push complete" ;;
    esac

    printf "\r${COLOR_BLUE}  Pushing Vault unsealer [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$push_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.3
  done

  wait $push_pid
  local push_exit_code=$?

  if [[ $push_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ Vault unsealer push completed [100%%]${COLOR_RESET}\n"
    log_success "Vault unsealer image pushed successfully to registry"
  else
    printf "\r${COLOR_RED}  ✗ Vault unsealer push failed${COLOR_RESET}\n"
    log_error "Vault unsealer image push failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  rm -f "$temp_build_log" "$temp_build_error"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log_success "Vault unsealer build and push completed in ${duration}s"

}

# Vault login helper function
vaultLogin(){
  ROOT_TOKEN=$(kubectl get secret vault-init-keys -n vault -o json | jq -r '.data["vault-init.json"]' | base64 -d | jq -r '.root_token')
  kubectl exec -it vault-0 -n vault -- vault login ${ROOT_TOKEN}
}

# Export functions for use across the project
export -f vaultInst
export -f build_vault_with_progress
export -f vaultLogin