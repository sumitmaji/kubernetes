#!/bin/bash

# GOK Login Component Installation
# This module handles the installation of GOK Login authentication service
gokLoginInst() {
  local start_time=$(date +%s)

  log_component_start "gok-login-install" "Installing GOK Login authentication service"


  log_step "3" "Building and deploying GOK Login service"
  log_substep "Preparing GOK Login installation directory"
  
  if execute_with_suppression pushd ${MOUNT_PATH}/kubernetes/install_k8s/gok-login; then
    log_success "GOK Login installation directory prepared"
  else
    log_error "Failed to access GOK Login installation directory"
    return 1
  fi

  # Enhanced GOK Login build with progress tracking
  build_gok_login_with_progress
  if [[ $? -ne 0 ]]; then
    log_error "GOK Login installation failed"
    execute_with_suppression popd
    return 1
  fi

  log_step "4" "Creating GOK Login namespace and configuration"
  log_substep "Creating namespace: gok-login"
  if kubectl create namespace gok-login >/dev/null 2>&1; then
    log_success "GOK Login namespace created"
  else
    log_info "GOK Login namespace already exists"
  fi

  log_substep "Creating CA certificate configuration"
  if execute_with_suppression kubectl create configmap ca-cert --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt -n gok-login; then
    log_success "CA certificate configuration created"
  else
    log_warning "CA certificate configuration had issues but continuing"
  fi

  log_step "5" "Installing GOK Login via Helm"
  log_substep "Deploying GOK Login authentication service"
  local client_secret=$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_SECRET 2>/dev/null)
  
  if [[ -n "$client_secret" ]]; then
    log_substep "OIDC Client Secret: ${COLOR_CYAN}[configured from oauth-secrets]${COLOR_RESET}"
  else
    log_warning "OIDC client secret not found - authentication may not work properly"
  fi

  if execute_with_suppression helm install gok-login ${MOUNT_PATH}/kubernetes/install_k8s/gok-login/chart -n gok-login --set oidc.clientSecret="$client_secret"; then
    log_success "GOK Login Helm chart installed successfully"
  else
    log_error "Failed to install GOK Login via Helm"
    execute_with_suppression popd
    return 1
  fi

  log_step "6" "Configuring GOK Login ingress and TLS"
  log_substep "Applying Let's Encrypt certificate to GOK Login ingress"
  if execute_with_suppression gok patch ingress gok-login-gok-login gok-login letsencrypt gok-login; then
    log_success "GOK Login TLS certificate configured"
  else
    log_warning "GOK Login TLS configuration had issues but continuing"
  fi

  log_step "7" "Waiting for GOK Login service to be ready"
  if wait_for_pods_ready "gok-login" "120" "GOK Login"; then
    log_success "GOK Login service is now ready"
  else
    log_error "GOK Login service failed to become ready within timeout"
    execute_with_suppression popd
    return 1
  fi

  if execute_with_suppression popd; then
    log_success "GOK Login installation directory cleanup completed"
  else
    log_warning "Directory cleanup had issues but installation completed"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # show_installation_summary "gok-login" "gok-login" "GOK Login authentication service"
  log_component_success "gok-login-install" "GOK Login authentication service installed successfully"
  log_success "GOK Login installation completed in ${duration}s"

  # Show GOK Login specific next steps and usage instructions
  show_gok_login_next_steps "$duration"
}

# Enhanced GOK Login build with detailed progress tracking
build_gok_login_with_progress() {
  local start_time=$(date +%s)

  # Get registry information
  local registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
  local image_name="gok-login"
  local full_image_url="${registry_url}/${image_name}"

  log_substep "Registry: ${COLOR_CYAN}${registry_url}${COLOR_RESET}"
  log_substep "Image: ${COLOR_CYAN}${image_name}${COLOR_RESET}"
  log_substep "Target: ${COLOR_CYAN}${full_image_url}${COLOR_RESET}"

  log_substep "Making build scripts executable"
  if execute_with_suppression chmod +x build.sh tag_push.sh; then
    log_success "Build scripts made executable"
  else
    log_error "Failed to make build scripts executable"
    return 1
  fi

  # Step 1: Docker Build with Progress
  log_info "🐳 Building GOK Login Docker image: ${COLOR_BOLD}${image_name}${COLOR_RESET}"

  local temp_build_log=$(mktemp)
  local temp_build_error=$(mktemp)

  # Start Docker build in background
  ./build.sh >"$temp_build_log" 2>"$temp_build_error" &
  local build_pid=$!

  # Show build progress with GOK Login-specific stages
  local build_progress=0
  local build_steps=6
  local spinner_chars="|/-\\"
  local spinner_idx=0
  local build_stage="Initializing"

  while kill -0 $build_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    build_progress=$(( (build_progress + 1) % (build_steps * 8) ))
    local progress_percent=$(( build_progress * 100 / (build_steps * 8) ))

    # Update stage based on progress
    case $((build_progress / 8)) in
      0) build_stage="Preparing Python base image" ;;
      1) build_stage="Installing Python dependencies" ;;
      2) build_stage="Copying application files" ;;
      3) build_stage="Setting up Flask environment" ;;
      4) build_stage="Configuring OIDC integration" ;;
      5) build_stage="Finalizing GOK Login image" ;;
    esac

    printf "\r${COLOR_BLUE}  Building GOK Login image [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$build_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.4
  done

  wait $build_pid
  local build_exit_code=$?

  if [[ $build_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ GOK Login build completed [100%%]${COLOR_RESET}\n"
    log_success "GOK Login Docker image built successfully: ${image_name}"
  else
    printf "\r${COLOR_RED}  ✗ GOK Login build failed${COLOR_RESET}\n"
    log_error "GOK Login Docker build failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  # Step 2: Docker Push with Progress
  log_info "📤 Pushing GOK Login image to registry: ${COLOR_BOLD}${registry_url}${COLOR_RESET}"
  log_substep "Target repository: ${COLOR_CYAN}${image_name}${COLOR_RESET}"

  # Start Docker push in background
  ./tag_push.sh >"$temp_build_log" 2>"$temp_build_error" &
  local push_pid=$!

  # Show push progress with GOK Login-specific stages
  local push_progress=0
  local push_steps=4
  local push_stage="Preparing"

  while kill -0 $push_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    push_progress=$(( (push_progress + 1) % (push_steps * 12) ))
    local progress_percent=$(( push_progress * 100 / (push_steps * 12) ))

    # Update stage based on progress
    case $((push_progress / 12)) in
      0) push_stage="Preparing GOK Login layers" ;;
      1) push_stage="Uploading Python environment" ;;
      2) push_stage="Uploading application code" ;;
      3) push_stage="Finalizing push" ;;
    esac

    printf "\r${COLOR_MAGENTA}  Pushing GOK Login to registry [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$push_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.4
  done

  wait $push_pid
  local push_exit_code=$?

  if [[ $push_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ GOK Login push completed [100%%] - Image available at ${COLOR_BOLD}${full_image_url}${COLOR_RESET}\n"
    log_success "GOK Login image pushed successfully to registry"
  else
    printf "\r${COLOR_RED}  ✗ GOK Login push failed${COLOR_RESET}\n"
    log_error "GOK Login push failed - error details:"
    if [[ -s "$temp_build_error" ]]; then
      cat "$temp_build_error" >&2
    fi
    rm -f "$temp_build_log" "$temp_build_error"
    return 1
  fi

  rm -f "$temp_build_log" "$temp_build_error"

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_success "GOK Login build and push completed in ${duration}s"
}

# Export the function to make it available
export -f gokLoginInst