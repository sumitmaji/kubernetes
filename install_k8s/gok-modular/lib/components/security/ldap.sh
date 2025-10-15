#!/bin/bash

# GOK LDAP Directory Service Component
# Provides comprehensive LDAP directory service with Kerberos integration

# LDAP directory service installation
ldapInst(){
  local start_time=$(date +%s)

  log_component_start "ldap" "Installing LDAP directory service and authentication"

  log_step "1" "Preparing LDAP installation directory"
  local ldap_dir="$GOK_ROOT/../../install_k8s/ldap"
  if [[ ! -d "$ldap_dir" ]]; then
    log_error "LDAP installation directory not found: $ldap_dir"
    return 1
  fi

  if execute_with_suppression pushd "$ldap_dir"; then
    log_success "LDAP installation directory prepared"
  else
    log_error "Failed to access LDAP installation directory"
    return 1
  fi

  log_step "2" "Collecting LDAP configuration parameters"
  : "${LDAP_PASSWORD:=${1:-$(promptSecret "Please enter LDAP password for admin: ")} }"
  : "${KERBEROS_PASSWORD:=${1:-$(promptSecret "Please enter Kerberos password: ")} }"
  : "${KERBEROS_KDC_PASSWORD:=${1:-$(promptSecret "Please enter Kerberos kdc password: ")} }"
  : "${KERBEROS_ADM_PASSWORD:=${1:-$(promptSecret "Please enter Kerberos adm password: ")} }"

  log_success "LDAP configuration parameters collected"

  log_step "3" "Building and deploying LDAP directory service"

  # Enhanced LDAP build with progress tracking
  build_ldap_with_progress "$LDAP_PASSWORD" "$KERBEROS_PASSWORD" "$KERBEROS_KDC_PASSWORD" "$KERBEROS_ADM_PASSWORD"
  if [[ $? -ne 0 ]]; then
    log_error "LDAP installation failed"
    popd || true
    return 1
  fi

  log_step "4" "Configuring LDAP ingress and networking"
  if execute_with_suppression gok-new patch ingress ldap ldap letsencrypt $(defaultSubdomain); then
    log_success "LDAP ingress configured successfully"
  else
    log_warning "LDAP ingress configuration had issues but installation may still work"
  fi

  log_step "5" "Validating LDAP installation"
  if validate_ldap_installation; then
    log_success "LDAP installation validation completed"
  else
    log_warning "LDAP validation had issues but installation may still work"
  fi

  if execute_with_suppression popd; then
    log_success "LDAP installation directory cleanup completed"
  else
    log_warning "Directory cleanup had issues but installation completed"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  show_ldap_installation_summary
  log_component_success "ldap" "LDAP directory service installed successfully"
  log_success "LDAP installation completed in ${duration}s"

  # Show LDAP-specific next steps and recommend Keycloak
  show_ldap_next_steps
}

# Deploy LDAP using Helm with correct registry URL
deploy_ldap_with_correct_registry() {
  local ldap_password="$1"
  local kerberos_password="$2"
  local kerberos_kdc_password="$3"
  local kerberos_adm_password="$4"
  local registry_url="$5"
  if [[ -z "$registry_url" ]]; then
    registry_url="registry.gokcloud.com"
  fi

  # Set HELM_NAME based on existing LDAP_APPLICATION_SLOT
  local HELM_NAME
  if [[ -n "$LDAP_APPLICATION_SLOT" && "$LDAP_APPLICATION_SLOT" != "default" ]]; then
    HELM_NAME="ldap-$LDAP_APPLICATION_SLOT"
  else
    HELM_NAME="ldap"
  fi

  local REPO_NAME="ldap"

  echo "Deploying LDAP with registry URL: $registry_url"  # Deploy using Helm with correct registry URL
  helm upgrade --install "$HELM_NAME" ./chart \
    --namespace ldap \
    --create-namespace \
    --set image.repository="$registry_url/$REPO_NAME" \
    --set image.tag="latest" \
    --set ldap.password="$ldap_password" \
    --set kerberos.password="$kerberos_password" \
    --set kerberos.kdcPassword="$kerberos_kdc_password" \
    --set kerberos.admpassword="$kerberos_adm_password"
}

# Enhanced LDAP build with detailed progress tracking
build_ldap_with_progress() {
  local ldap_password="$1"
  local kerberos_password="$2"
  local kerberos_kdc_password="$3"
  local kerberos_adm_password="$4"
  local start_time=$(date +%s)

  # Store GOK modular registry URL before sourcing old config  
  local gok_registry_url
  if [[ -n "$REGISTRY" && -n "$GOK_ROOT_DOMAIN" ]]; then
    gok_registry_url="${REGISTRY}.${GOK_ROOT_DOMAIN}"
  else
    gok_registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
  fi
  
  # Source configuration to get image details but preserve registry URL
  if [[ -f "configuration" ]]; then
    source configuration
  fi
  
  source "$WORKING_DIR/util" 2>/dev/null || true

  # Get registry and image information (use GOK modular registry)
  local registry_url="$gok_registry_url"
  local image_name="${IMAGE_NAME:-sumit/ldap}"
  local repo_name="${REPO_NAME:-ldap}"
  local full_image_url="${registry_url}/${repo_name}"

  log_substep "Registry: ${COLOR_CYAN}${registry_url}${COLOR_RESET}"
  log_substep "Image: ${COLOR_CYAN}${image_name}${COLOR_RESET}"
  log_substep "Target: ${COLOR_CYAN}${full_image_url}${COLOR_RESET}"

  # Get domain configuration
  source config/config 2>/dev/null || true
  local domain_name="${DOMAIN_NAME:-default.svc.cloud.uat}"
  local ldap_hostname="${LDAP_HOSTNAME:-ldap.${domain_name}}"
  local base_dn="${DC:-dc=default,dc=svc,dc=cloud,dc=uat}"

  log_substep "LDAP Domain: ${COLOR_CYAN}${domain_name}${COLOR_RESET}"
  log_substep "LDAP Hostname: ${COLOR_CYAN}${ldap_hostname}${COLOR_RESET}"
  log_substep "Base DN: ${COLOR_CYAN}${base_dn}${COLOR_RESET}"

  # Step 1: Docker Build with Progress
  log_info "🐳 Building LDAP Docker image: ${COLOR_BOLD}${image_name}${COLOR_RESET}"

  local temp_build_log=$(mktemp)
  local temp_build_error=$(mktemp)

  # Start Docker build in background with enhanced arguments (use GOK registry)
  docker build \
    --build-arg LDAP_DOMAIN="$domain_name" \
    --build-arg REGISTRY="$gok_registry_url" \
    --build-arg LDAP_HOSTNAME="$ldap_hostname" \
    --build-arg BASE_DN="$base_dn" \
    --build-arg LDAP_PASSWORD="$ldap_password" \
    -t "$image_name" . >"$temp_build_log" 2>"$temp_build_error" &
  local build_pid=$!

  # Show build progress with LDAP-specific stages
  local build_progress=0
  local build_steps=12
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
      1) build_stage="Installing LDAP packages" ;;
      2) build_stage="Configuring OpenLDAP" ;;
      3) build_stage="Setting up phpLDAPadmin" ;;
      4) build_stage="Installing Kerberos" ;;
      5) build_stage="Configuring authentication" ;;
      6) build_stage="Setting up SSL certificates" ;;
      7) build_stage="Installing utilities" ;;
      8) build_stage="Configuring permissions" ;;
      9) build_stage="Installing NTP services" ;;
      10) build_stage="Cleaning up packages" ;;
      11) build_stage="Finalizing LDAP image" ;;
    esac

    printf "\r${COLOR_BLUE}  Building LDAP image [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$build_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.4
  done

  wait $build_pid
  local build_exit_code=$?

  if [[ $build_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ LDAP Docker build completed [100%%]${COLOR_RESET}\n"
    log_success "LDAP Docker image built successfully: ${image_name}"

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
    printf "\r${COLOR_RED}  ✗ LDAP Docker build failed${COLOR_RESET}\n"
    log_error "LDAP Docker build failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 2: Docker Tag
  log_info "🏷️  Tagging LDAP image for registry: ${COLOR_BOLD}${full_image_url}${COLOR_RESET}"
  if docker tag "$image_name" "$full_image_url" >/dev/null 2>&1; then
    log_success "LDAP image tagged successfully"
  else
    log_error "Failed to tag LDAP Docker image"
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 3: Docker Push with Progress
  log_info "📤 Pushing LDAP image to registry: ${COLOR_BOLD}${registry_url}${COLOR_RESET}"
  log_substep "Target repository: ${COLOR_CYAN}${repo_name}${COLOR_RESET}"

  # Start Docker push in background
  docker push "$full_image_url" >"$temp_build_log" 2>"$temp_build_error" &
  local push_pid=$!

  # Show push progress with LDAP-specific stages
  local push_progress=0
  local push_steps=8
  local push_stage="Preparing"

  while kill -0 $push_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    push_progress=$(( (push_progress + 1) % (push_steps * 12) ))
    local progress_percent=$(( push_progress * 100 / (push_steps * 12) ))

    # Update stage based on progress
    case $((push_progress / 12)) in
      0) push_stage="Preparing LDAP layers" ;;
      1) push_stage="Uploading base system" ;;
      2) push_stage="Uploading LDAP packages" ;;
      3) push_stage="Uploading configurations" ;;
      4) push_stage="Uploading certificates" ;;
      5) push_stage="Uploading utilities" ;;
      6) push_stage="Uploading final layers" ;;
      7) push_stage="Finalizing push" ;;
    esac

    printf "\r${COLOR_MAGENTA}  Pushing LDAP to registry [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$push_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.4
  done

  wait $push_pid
  local push_exit_code=$?

  if [[ $push_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ LDAP push completed [100%%] - Image available at ${COLOR_BOLD}${full_image_url}${COLOR_RESET}\n"
    log_success "LDAP image pushed successfully to registry"
  else
    printf "\r${COLOR_RED}  ✗ LDAP push failed${COLOR_RESET}\n"
    log_error "LDAP Docker push failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 4: Deploy to Kubernetes
  log_info "☸️  Deploying LDAP to Kubernetes cluster"

  # Execute the deployment with correct registry URL
  local temp_deploy_log=$(mktemp)
  local temp_deploy_error=$(mktemp)

  # Deploy LDAP using Helm with correct registry URL
  deploy_ldap_with_correct_registry "$ldap_password" "$kerberos_password" "$kerberos_kdc_password" "$kerberos_adm_password" "$gok_registry_url" >"$temp_deploy_log" 2>"$temp_deploy_error" &
  local deploy_pid=$!

  # Show deployment progress
  local deploy_progress=0
  local deploy_steps=6
  local deploy_stage="Preparing"

  while kill -0 $deploy_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    deploy_progress=$(( (deploy_progress + 1) % (deploy_steps * 10) ))
    local progress_percent=$(( deploy_progress * 100 / (deploy_steps * 10) ))

    # Update stage based on progress
    case $((deploy_progress / 10)) in
      0) deploy_stage="Creating namespace" ;;
      1) deploy_stage="Deploying LDAP service" ;;
      2) deploy_stage="Setting up ingress" ;;
      3) deploy_stage="Configuring certificates" ;;
      4) deploy_stage="Waiting for pods" ;;
      5) deploy_stage="Verifying services" ;;
    esac

    printf "\r${COLOR_BLUE}  Deploying LDAP service [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$deploy_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.5
  done

  wait $deploy_pid
  local deploy_exit_code=$?

  if [[ $deploy_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ LDAP deployment completed [100%%]${COLOR_RESET}\n"
    log_success "LDAP service deployed successfully to Kubernetes"

    # Step 5: Enhanced diagnostic verification after deployment
    log_info "🔍 Performing enhanced deployment verification"

    # Give the deployment a moment to start creating pods
    log_substep "Allowing deployment to initialize..."
    sleep 15

    # Check for immediate image pull issues
    log_substep "Checking for Docker image pull issues..."
    if ! check_image_pull_issues "ldap" "ldap"; then
      log_error "❌ LDAP has Docker image pull issues"
      rm -f "$temp_build_log" "$temp_build_error" "$temp_deploy_log" "$temp_deploy_error"
      return 1
    fi

    # Check for resource constraint issues
    log_substep "Checking for resource constraints..."
    if ! check_resource_constraints "ldap" "ldap"; then
      log_error "❌ LDAP has resource constraint issues"
      rm -f "$temp_build_log" "$temp_build_error" "$temp_deploy_log" "$temp_deploy_error"
      return 1
    fi

    # Use enhanced pod waiting with detailed diagnostics and proper timeout
    log_substep "Waiting for LDAP pods with enhanced monitoring..."
    if wait_for_pods_ready "ldap" "" "300"; then
      log_success "✅ LDAP pods are ready and healthy"
      
      # Additional check: Wait for deployment to be fully ready with timeout
      log_substep "Waiting for LDAP deployment to be fully ready (timeout: 30s)..."
      local deploy_timeout=30
      local deploy_start_time=$(date +%s)
      local deploy_ready=false
      
      while [[ $(($(date +%s) - deploy_start_time)) -lt $deploy_timeout ]]; do
        if check_deployment_readiness "ldap" "ldap" >/dev/null 2>&1; then
          deploy_ready=true
          break
        fi
        log_substep "Deployment not ready yet, waiting... ($(($(date +%s) - deploy_start_time))/${deploy_timeout}s)"
        sleep 5
      done
      
      if [[ "$deploy_ready" == "true" ]]; then
        log_success "✅ LDAP deployment is fully ready and available"
      else
        log_warning "⚠️ LDAP deployment readiness check timed out after ${deploy_timeout}s, but pods are running"
      fi
    else
      log_error "❌ LDAP pods failed to become ready within 300 seconds"
      rm -f "$temp_build_log" "$temp_build_error" "$temp_deploy_log" "$temp_deploy_error"
      return 1
    fi

  else
    printf "\r${COLOR_RED}  ✗ LDAP deployment failed${COLOR_RESET}\n"
    log_error "LDAP deployment failed - error details:"
    if [[ -s "$temp_deploy_error" ]]; then
      if is_verbose_mode; then
        cat "$temp_deploy_error" >&2
      else
        tail -10 "$temp_deploy_error" >&2
        log_info "Use --verbose flag to see full deployment logs"
      fi
    fi
    rm -f "$temp_build_log" "$temp_build_error" "$temp_deploy_log" "$temp_deploy_error"
    return 1
  fi

  # Clean up temporary files
  rm -f "$temp_build_log" "$temp_build_error" "$temp_deploy_log" "$temp_deploy_error"

  # Build completion summary
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_success "LDAP build and deployment completed in ${duration}s"

  # Show LDAP image and deployment summary
  # show_ldap_summary

  return 0
}

# Export functions for use by other modules
export -f ldapInst
export -f deploy_ldap_with_correct_registry
export -f build_ldap_with_progress