#!/bin/bash

# OAuth2 Proxy Installation Module
# Provides authentication proxy with Keycloak OIDC integration

oauth2Inst() {
  local start_time=$(date +%s)

  log_component_start "oauth2-proxy-install" "Installing OAuth2 Proxy authentication system"

  log_step "1" "Updating system packages with smart caching"
  if ! updateSys; then
    log_error "Failed to update system packages"
    return 1
  fi

  log_step "2" "Installing dependencies with smart caching"
  if ! installDeps; then
    log_error "Failed to install OAuth2 Proxy dependencies"
    return 1
  fi

  log_step "3" "Preparing OAuth2 Proxy installation directory"
  local oauth2_dir="$MOUNT_PATH/kubernetes/install_k8s/oauth2-proxy"
  if [[ ! -d "$oauth2_dir" ]]; then
    log_error "OAuth2 Proxy installation directory not found: $oauth2_dir"
    return 1
  fi

  if execute_with_suppression pushd "$oauth2_dir"; then
    log_success "OAuth2 Proxy installation directory prepared"
  else
    log_error "Failed to access OAuth2 Proxy installation directory"
    return 1
  fi

  log_step "4" "Creating namespace and persistent storage"
  if createLocalStorageClassAndPV "oauth-storage" "oauth-pv" "/data/volumes/pv6"; then
    log_success "OAuth2 Proxy storage created"
  else
    log_warning "OAuth2 Proxy storage creation had issues but continuing"
  fi

  if kubectl get namespace oauth2 >/dev/null 2>&1 || kubectl create namespace oauth2 >/dev/null 2>&1; then
    log_success "OAuth2 Proxy namespace created or already exists"
  else
    log_error "Failed to create OAuth2 Proxy namespace"
    return 1
  fi

  log_step "5" "Collecting OAuth2 configuration from Keycloak"
  log_substep "Retrieving OAuth2 configuration parameters"

  local oauth2_client_id=$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_ID 2>/dev/null || echo "")
  local realm=$(dataFromSecret oauth-secrets kube-system OAUTH_REALM 2>/dev/null || echo "")
  local oauth2_host="$(fullKeycloakUrl 2>/dev/null || echo "")"
  local oidc_issuer_url=$(dataFromSecret oauth-secrets kube-system OIDC_ISSUE_URL 2>/dev/null || echo "")

  if [[ -z "$oauth2_client_id" || -z "$realm" || -z "$oauth2_host" || -z "$oidc_issuer_url" ]]; then
    log_error "Failed to retrieve OAuth2 configuration from Keycloak secrets"
    log_error "Please ensure Keycloak is installed and configured properly"
    popd || true
    return 1
  fi

  log_substep "Client ID: ${COLOR_CYAN}${oauth2_client_id}${COLOR_RESET}"
  log_substep "Realm: ${COLOR_CYAN}${realm}${COLOR_RESET}"
  log_substep "Keycloak Host: ${COLOR_CYAN}${oauth2_host}${COLOR_RESET}"
  log_substep "OIDC Issuer: ${COLOR_CYAN}${oidc_issuer_url}${COLOR_RESET}"

  log_success "OAuth2 configuration parameters collected"

  log_step "6" "Building and deploying OAuth2 Proxy services"

  # Add upstream OAuth2 proxy Helm repository
  log_substep "Adding upstream OAuth2 proxy Helm repository..."
  if execute_with_suppression helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests; then
    log_success "Upstream OAuth2 proxy Helm repository added"
  else
    log_warning "OAuth2 proxy repository may already exist"
  fi

  log_substep "Updating Helm repositories..."
  if execute_with_suppression helm repo update; then
    log_success "Helm repositories updated"
  else
    log_warning "Helm repository update had issues but continuing"
  fi

  # Enhanced OAuth2 build with progress tracking
  build_oauth2_with_progress "$oauth2_client_id" "$realm" "$oauth2_host" "$oidc_issuer_url"
  if [[ $? -ne 0 ]]; then
    log_error "OAuth2 Proxy installation failed"
    popd || true
    return 1
  fi

  log_step "7" "Configuring OAuth2 Proxy networking and access"
  log_substep "Creating OAuth2 Proxy ingress manually..."

  # Create the ingress resource manually since upstream chart ingress has bugs
  if execute_with_suppression kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth2-proxy
  namespace: oauth2
spec:
  ingressClassName: nginx
  rules:
  - host: $(defaultSubdomain).$(rootDomain)
    http:
      paths:
      - path: /oauth2
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy
            port:
              number: 80
EOF
  then
    log_success "OAuth2 Proxy ingress created successfully"
  else
    log_warning "OAuth2 Proxy ingress creation had issues but continuing"
  fi

  log_substep "Configuring TLS for OAuth2 Proxy ingress..."
  if execute_with_suppression kubectl patch ingress oauth2-proxy -n oauth2 --type=merge -p '{"spec":{"tls":[{"hosts":["'$(defaultSubdomain).$(rootDomain)'"],"secretName":"'$(defaultSubdomain)-$(sedRootDomain)-tls'"}]}}'; then
    log_success "OAuth2 Proxy TLS configured successfully"
  else
    log_warning "OAuth2 Proxy TLS configuration had issues but continuing"
  fi

  log_substep "Setting SSL and protocol annotations..."
  if execute_with_suppression kubectl annotate ingress oauth2-proxy -n oauth2 nginx.ingress.kubernetes.io/ssl-redirect='true' ingress.kubernetes.io/ssl-passthrough='true' nginx.ingress.kubernetes.io/backend-protocol='HTTP' kubernetes.io/ingress.allow-http='false' nginx.ingress.kubernetes.io/proxy-buffer-size='128k' nginx.ingress.kubernetes.io/proxy-buffers='4 256k' nginx.ingress.kubernetes.io/proxy-busy-buffers-size='256k'; then
    log_success "OAuth2 Proxy SSL annotations configured successfully"
  else
    log_warning "OAuth2 Proxy SSL annotations had issues but continuing"
  fi

  log_substep "Applying Let's Encrypt certificate configuration..."
  if execute_with_suppression gok patch ingress oauth2-proxy oauth2 letsencrypt $(defaultSubdomain); then
    log_success "OAuth2 Proxy Let's Encrypt configuration applied successfully"
  else
    log_warning "OAuth2 Proxy Let's Encrypt configuration had issues but installation may still work"
  fi

#   log_step "8" "Validating OAuth2 Proxy installation"
#   if validate_oauth2_installation; then
#     log_success "OAuth2 Proxy installation validation completed"
#   else
#     log_warning "OAuth2 Proxy validation had issues but installation may still work"
#   fi

  if execute_with_suppression popd; then
    log_success "OAuth2 Proxy installation directory cleanup completed"
  else
    log_warning "Directory cleanup had issues but installation completed"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  show_installation_summary "oauth2-proxy" "oauth2" "Authentication proxy with Keycloak integration"
  log_component_success "oauth2-proxy-install" "OAuth2 Proxy authentication system installed successfully"
  log_success "OAuth2 Proxy installation completed in ${duration}s"

  # Show OAuth2-specific next steps and recommend RabbitMQ
#   show_oauth2_next_steps
}

# Enhanced OAuth2 Proxy build with detailed progress tracking
build_oauth2_with_progress() {
  local oauth2_client_id="$1"
  local realm="$2"
  local oauth2_host="$3"
  local oidc_issuer_url="$4"
  local start_time=$(date +%s)

  log_substep "Authentication Provider: ${COLOR_CYAN}OAuth2 + OIDC${COLOR_RESET}"
  log_substep "Keycloak Integration: ${COLOR_CYAN}${oauth2_host}${COLOR_RESET}"
  log_substep "Client ID: ${COLOR_CYAN}${oauth2_client_id}${COLOR_RESET}"
  log_substep "Realm: ${COLOR_CYAN}${realm}${COLOR_RESET}"
  log_substep "OIDC Issuer: ${COLOR_CYAN}${oidc_issuer_url}${COLOR_RESET}"

  # Step 1: Create OAuth2 configuration with progress
  log_info "🔧 Creating OAuth2 Proxy configuration"

  local temp_config_log=$(mktemp)
  local temp_config_error=$(mktemp)

  # Create configuration in background with progress tracking
  (
    kubectl create configmap oauth2-proxy-config \
      --from-literal=clientID="${oauth2_client_id}" \
      --from-literal=oidcIssuerUrl="${oidc_issuer_url}" \
      --from-literal=redirectUrl=oauth2/callback \
      -n oauth2 >"$temp_config_log" 2>"$temp_config_error"

    kubectl create configmap oauth2-ca-cert \
      --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt \
      -n oauth2 >>"$temp_config_log" 2>>"$temp_config_error"
  ) &
  local config_pid=$!

  # Show configuration creation progress
  local config_progress=0
  local spinner_chars="|/-\\"
  local spinner_idx=0
  local config_stage="Creating OAuth2 configuration"

  while kill -0 $config_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    config_progress=$(( (config_progress + 1) % 40 ))
    local progress_percent=$(( config_progress * 100 / 40 ))

    # Update stage based on progress
    if [[ $config_progress -lt 20 ]]; then
      config_stage="Creating OAuth2 proxy config"
    else
      config_stage="Setting up CA certificates"
    fi

    printf "\r${COLOR_BLUE}  Creating configuration [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$config_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.3
  done

  wait $config_pid
  local config_exit_code=$?

  if [[ $config_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ OAuth2 configuration created [100%%]${COLOR_RESET}\n"
    log_success "OAuth2 Proxy configuration created successfully"
  else
    printf "\r${COLOR_RED}  ✗ Configuration creation failed${COLOR_RESET}\n"
    log_error "OAuth2 configuration creation failed - error details:"
    if [[ -s "$temp_config_error" ]]; then
      cat "$temp_config_error" >&2
    fi
    rm -f "$temp_config_log" "$temp_config_error"
    return 1
  fi

  # Step 2: Install OAuth2 Proxy via upstream Helm chart (default)
  log_info "☸️  Installing OAuth2 Proxy via upstream Helm chart"
  log_substep "Chart: ${COLOR_CYAN}oauth2-proxy/oauth2-proxy${COLOR_RESET}"
  log_substep "Values: ${COLOR_CYAN}${MOUNT_PATH}/kubernetes/install_k8s/oauth2-proxy/values.yaml${COLOR_RESET}"

  local temp_helm_log=$(mktemp)
  local temp_helm_error=$(mktemp)

  # Start Helm installation in background with upstream oauth2-proxy chart
  helm upgrade --install oauth2-proxy oauth2-proxy/oauth2-proxy \
    --namespace oauth2 \
    --values "${MOUNT_PATH}"/kubernetes/install_k8s/oauth2-proxy/values.yaml \
    --set-string image.tag="v7.12.0" \
    --set-string config.clientID="${oauth2_client_id}" \
    --set-string config.clientSecret="$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_SECRET)" \
    --set-string config.cookieSecret=bXljb29raWVzdW1pdDEyMzQ1Njc4OTAx \
    --set-string config.oidcIssuerUrl="${oidc_issuer_url}" \
    --set-string config.loginHost="${oauth2_host}" \
    --set-string config.realm="${realm}" \
    --set ingress.enabled=false \
    --set 'extraArgs[0]=--provider=oidc' \
    --set "extraArgs[1]=--keycloak-group=administrators" \
    --set "extraArgs[2]=--keycloak-group=developers" \
    --set "extraArgs[3]=--allowed-group=administrators" \
    --set "extraArgs[4]=--allowed-group=developers" \
    --set "extraArgs[5]=--scope=openid email profile groups sub offline_access" \
    --set "extraArgs[6]=--ssl-insecure-skip-verify=false" \
    --set "extraArgs[7]=--set-authorization-header=true" \
    --set "extraArgs[8]=--whitelist-domain=.gokcloud.com" \
    --set "extraArgs[9]=--oidc-groups-claim=groups" \
    --set "extraArgs[10]=--user-id-claim=sub" \
    --set "extraArgs[11]=--cookie-domain=.gokcloud.com" \
    --set "extraArgs[12]=--cookie-secure=true" \
    --set "extraArgs[13]=--pass-access-token=true" \
    --set "extraArgs[14]=--pass-authorization-header=true" \
    --set "extraArgs[15]=--standard-logging=true" \
    --set "extraArgs[16]=--auth-logging=true" \
    --set "extraArgs[17]=--request-logging=true" \
    --set "extraArgs[18]=--cookie-refresh=1h" \
    --set "extraArgs[19]=--cookie-expire=8h" \
    --set "extraArgs[20]=--set-xauthrequest=true" \
    --set "extraArgs[21]=--skip-jwt-bearer-tokens=true" \
    --set "extraArgs[22]=--email-domain=*" \
    --set "extraArgs[23]=--oidc-issuer-url=https://${oauth2_host}/realms/${realm}" \
    --set "extraArgs[24]=--oidc-jwks-url=https://${oauth2_host}/realms/${realm}/protocol/openid-connect/certs" \
    --set "extraArgs[25]=--reverse-proxy=true" \
    --set "extraArgs[26]=--login-url=https://${oauth2_host}/realms/${realm}/protocol/openid-connect/auth" \
    --set "extraArgs[27]=--redeem-url=https://${oauth2_host}/realms/${realm}/protocol/openid-connect/token" \
    --set "extraArgs[28]=--profile-url=https://${oauth2_host}/realms/${realm}/protocol/openid-connect/userinfo" \
    --set "extraArgs[29]=--validate-url=https://${oauth2_host}/realms/${realm}/protocol/openid-connect/userinfo" \
    --set "extraArgs[30]=--show-debug-on-error=true" \
    --set "extraArgs[31]=--silence-ping-logging=false" \
    --set "extraArgs[32]=--upstream=http://httpbin.org" \
    --set "extraArgs[33]=--skip-provider-button=false"
    >"$temp_helm_log" 2>"$temp_helm_error" &
  local helm_pid=$!

  # Show Helm installation progress with OAuth2-specific stages
  local helm_progress=0
  local helm_steps=8
  local helm_stage="Preparing"

  while kill -0 $helm_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    helm_progress=$(( (helm_progress + 1) % (helm_steps * 15) ))
    local progress_percent=$(( helm_progress * 100 / (helm_steps * 15) ))

    # Update stage based on progress
    case $((helm_progress / 15)) in
      0) helm_stage="Downloading OAuth2 chart" ;;
      1) helm_stage="Installing OAuth2 proxy" ;;
      2) helm_stage="Configuring authentication" ;;
      3) helm_stage="Setting up OIDC integration" ;;
      4) helm_stage="Configuring Keycloak provider" ;;
      5) helm_stage="Setting up cookie management" ;;
      6) helm_stage="Configuring ingress routing" ;;
      7) helm_stage="Finalizing installation" ;;
    esac

    printf "\r${COLOR_BLUE}  Installing OAuth2 Proxy [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$helm_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.5
  done

  wait $helm_pid
  local helm_exit_code=$?

  if [[ $helm_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ OAuth2 Proxy installation completed [100%%]${COLOR_RESET}\n"
    log_success "OAuth2 Proxy deployed successfully via Helm"
  else
    printf "\r${COLOR_RED}  ✗ OAuth2 Proxy installation failed${COLOR_RESET}\n"
    log_error "OAuth2 Proxy Helm installation failed - error details:"
    if [[ -s "$temp_helm_error" ]]; then
      if is_verbose_mode; then
        cat "$temp_helm_error" >&2
      else
        tail -10 "$temp_helm_error" >&2
        log_info "Use --verbose flag to see full installation logs"
      fi
    fi
    rm -f "$temp_helm_log" "$temp_helm_error"
    return 1
  fi

  rm -f "$temp_config_log" "$temp_config_error" "$temp_helm_log" "$temp_helm_error"
}

export -f oauth2Inst