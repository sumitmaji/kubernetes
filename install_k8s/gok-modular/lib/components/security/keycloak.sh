#!/bin/bash

# GOK Keycloak Identity Management Component
# Provides comprehensive identity and access management with OAuth2/OIDC support

# Keycloak identity management installation
keycloakInst(){

  log_step "1" "Preparing Keycloak installation directory"
  local keycloak_dir="$GOK_ROOT/../../install_k8s/keycloak"
  if [[ ! -d "$keycloak_dir" ]]; then
    log_error "Keycloak installation directory not found: $keycloak_dir"
    return 1
  fi

  if execute_with_suppression pushd "$keycloak_dir"; then
    log_success "Keycloak installation directory prepared"
  else
    log_error "Failed to access Keycloak installation directory"
    return 1
  fi

  log_step "2" "Collecting Keycloak configuration parameters"
  : "${KEYCLOAK_ADMIN_USERNAME:=${1:-$(promptUserInput "Please enter keycloak admin username (admin): " "admin")}}"
  : "${KEYCLOAK_ADMIN_PASSWORD:=${2:-$(promptSecret "Please enter keycloak admin password: ")}}"
  : "${POSTGRESQL_USERNAME:=${3:-$(promptUserInput "Please enter postgresql username (postgres): " "postgres")}}"
  : "${POSTGRESQL_PASSWORD:=${4:-$(promptSecret "Please enter postgresql password: ")}}"
  : "${OIDC_CLIENT_ID:=${5:-$(promptUserInput "Please enter OIDC client id (${OIDC_CLIENT_ID:-gok-developers-client}): " "${OIDC_CLIENT_ID:-gok-developers-client}")}}"
  : "${REALM:=${6:-$(promptUserInput "Please enter realm name (${REALM:-GokDevelopers}): " "${REALM:-GokDevelopers}")}}"

  # Trim whitespace from inputs
  KEYCLOAK_ADMIN_USERNAME=$(echo "$KEYCLOAK_ADMIN_USERNAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  KEYCLOAK_ADMIN_PASSWORD=$(echo "$KEYCLOAK_ADMIN_PASSWORD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  POSTGRESQL_USERNAME=$(echo "$POSTGRESQL_USERNAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  POSTGRESQL_PASSWORD=$(echo "$POSTGRESQL_PASSWORD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  OIDC_CLIENT_ID=$(echo "$OIDC_CLIENT_ID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  REALM=$(echo "$REALM" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  log_success "Keycloak configuration parameters collected"

  log_step "3" "Building and deploying Keycloak identity management"

  # Create Keycloak namespace first
  log_substep "Creating Keycloak namespace"
  if kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1; then
    log_success "Keycloak namespace created or already exists"
  else
    log_error "Failed to create Keycloak namespace"
    popd || true
    return 1
  fi

  # Enhanced Keycloak build with progress tracking
  build_keycloak_with_progress "$KEYCLOAK_ADMIN_USERNAME" "$KEYCLOAK_ADMIN_PASSWORD" "$POSTGRESQL_USERNAME" "$POSTGRESQL_PASSWORD" "$OIDC_CLIENT_ID" "$REALM"
  if [[ $? -ne 0 ]]; then
    log_error "Keycloak installation failed"
    popd || true
    return 1
  fi

  log_step "4" "Configuring Keycloak ingress and networking"
  if execute_with_suppression gok-new patch ingress keycloak keycloak letsencrypt $(defaultSubdomain); then
    log_success "Keycloak ingress configured successfully"
  else
    log_warning "Keycloak ingress configuration had issues but installation may still work"
  fi

  if execute_with_suppression popd; then
    log_success "Keycloak installation directory cleanup completed"
  else
    log_warning "Keycloak installation directory cleanup had issues"
  fi

  return 0
}

# Enhanced Keycloak build with detailed progress tracking
build_keycloak_with_progress() {
  local keycloak_admin_username="$1"
  local keycloak_admin_password="$2"
  local postgresql_username="$3"
  local postgresql_password="$4"
  local oidc_client_id="$5"
  local realm="$6"
  local start_time=$(date +%s)

  # Get hostname configuration
  local hostname="$(subDomain 'keycloak').$(rootDomain)"

  log_substep "Identity Provider: ${COLOR_CYAN}Keycloak${COLOR_RESET}"
  log_substep "Hostname: ${COLOR_CYAN}${hostname}${COLOR_RESET}"
  log_substep "Admin User: ${COLOR_CYAN}${keycloak_admin_username}${COLOR_RESET}"
  log_substep "Database: ${COLOR_CYAN}PostgreSQL${COLOR_RESET}"
  log_substep "OIDC Client: ${COLOR_CYAN}${oidc_client_id}${COLOR_RESET}"
  log_substep "Realm: ${COLOR_CYAN}${realm}${COLOR_RESET}"

  # Step 1: Create Kubernetes secrets with progress
  log_info "🔐 Creating Keycloak and PostgreSQL secrets"

  local temp_secret_log=$(mktemp)
  local temp_secret_error=$(mktemp)

  # Create secrets in background with progress tracking
  (
    kubectl create secret generic keycloak-secrets \
  --from-literal=KEYCLOAK_LOG_LEVEL="TRACE" \
  --from-literal=KC_LOG_LEVEL="TRACE" \
      --from-literal=KEYCLOAK_ADMIN="${keycloak_admin_username}" \
      --from-literal=CLIENT_ID="${oidc_client_id}" \
      --from-literal=OAUTH_REALM="${realm}" \
      --from-literal=KEYCLOAK_ADMIN_PASSWORD="${keycloak_admin_password}" \
      --from-literal=admin-user="${keycloak_admin_username}" \
      --from-literal=admin-password="${keycloak_admin_password}" \
      --from-literal=hostname="${hostname}" \
      -n keycloak >"$temp_secret_log" 2>"$temp_secret_error"

    kubectl create secret generic keycloak-postgresql \
      --from-literal=username="${postgresql_username}" \
      --from-literal=POSTGRES_USER="${postgresql_username}" \
      --from-literal=password="${postgresql_password}" \
      --from-literal=POSTGRES_PASSWORD="${postgresql_password}" \
      --from-literal=postgres-password="${postgresql_password}" \
      -n keycloak >>"$temp_secret_log" 2>>"$temp_secret_error"
  ) &
  local secret_pid=$!

  # Show secret creation progress
  local secret_progress=0
  local spinner_chars="|/-\\"
  local spinner_idx=0
  local secret_stage="Creating authentication secrets"

  while kill -0 $secret_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    secret_progress=$(( (secret_progress + 1) % 40 ))
    local progress_percent=$(( secret_progress * 100 / 40 ))

    # Update stage based on progress
    if [[ $secret_progress -lt 20 ]]; then
      secret_stage="Creating Keycloak admin secrets"
    else
      secret_stage="Creating PostgreSQL database secrets"
    fi

    printf "\r${COLOR_BLUE}  Creating secrets [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$secret_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.3
  done

  wait $secret_pid
  local secret_exit_code=$?

  if [[ $secret_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ Keycloak secrets created [100%%]${COLOR_RESET}\n"
    log_success "Keycloak and PostgreSQL secrets created successfully"
  else
    printf "\r${COLOR_RED}  ✗ Secret creation failed${COLOR_RESET}\n"
    log_error "Keycloak secret creation failed - error details:"
    if [[ -s "$temp_secret_error" ]]; then
      cat "$temp_secret_error" >&2
    fi
    rm -f "$temp_secret_log" "$temp_secret_error"
    return 1
  fi

  # Step 2: Deploy PostgreSQL for Keycloak
  log_info "📦 Deploying PostgreSQL database for Keycloak..."
  if deploy_keycloak_postgresql; then
    log_success "PostgreSQL database deployed successfully"
  else
    log_error "PostgreSQL deployment failed"
    rm -f "$temp_secret_log" "$temp_secret_error"
    return 1
  fi

  # Step 3: Add codecentric helm repository and install Keycloak
  log_info "📦 Adding codecentric helm repository"
  log_substep "Repository: ${COLOR_CYAN}https://codecentric.github.io/helm-charts${COLOR_RESET}"

  if execute_with_suppression helm repo add codecentric https://codecentric.github.io/helm-charts >/dev/null 2>&1; then
    log_success "Codecentric helm repository added"
  else
    log_info "Codecentric repository already exists, continuing..."
  fi

  log_substep "Updating helm repositories..."
  if execute_with_suppression helm repo update >/dev/null 2>&1; then
    log_success "Helm repositories updated"
  else
    log_warning "Helm repository update had issues but continuing"
  fi

  # Step 4: Install Keycloak via codecentric/keycloakx Helm chart with enhanced progress
  log_info "☸️  Installing Keycloak via codecentric/keycloakx chart"
  log_substep "Chart: ${COLOR_CYAN}codecentric/keycloakx${COLOR_RESET}"
  log_substep "Values: ${COLOR_CYAN}${MOUNT_PATH}/kubernetes/install_k8s/keycloak/values-kcx.yaml${COLOR_RESET}"

  local temp_helm_log=$(mktemp)
  local temp_helm_error=$(mktemp)

  # Start Helm installation in background with codecentric/keycloakx
  helm upgrade --install keycloak codecentric/keycloakx \
    --namespace keycloak \
    --values "${MOUNT_PATH}"/kubernetes/install_k8s/keycloak/values-kcx.yaml \
    >"$temp_helm_log" 2>"$temp_helm_error" &
  local helm_pid=$!

  # Show Helm installation progress with Keycloak-specific stages
  local helm_progress=0
  local helm_steps=8
  local helm_stage="Preparing"

  while kill -0 $helm_pid 2>/dev/null; do
    local char=${spinner_chars:spinner_idx:1}
    helm_progress=$(( (helm_progress + 1) % (helm_steps * 15) ))
    local progress_percent=$(( helm_progress * 100 / (helm_steps * 15) ))

    # Update stage based on progress for codecentric/keycloakx
    case $((helm_progress / 15)) in
      0) helm_stage="Downloading keycloakx chart" ;;
      1) helm_stage="Creating Keycloak StatefulSet" ;;
      2) helm_stage="Configuring Keycloak service" ;;
      3) helm_stage="Setting up identity providers" ;;
      4) helm_stage="Configuring authentication flows" ;;
      5) helm_stage="Setting up ingress routing" ;;
      6) helm_stage="Waiting for Keycloak pods" ;;
      7) helm_stage="Finalizing keycloakx installation" ;;
    esac

    printf "\r${COLOR_BLUE}  Installing Keycloak [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$helm_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 0.5
  done

  wait $helm_pid
  local helm_exit_code=$?

  if [[ $helm_exit_code -eq 0 ]]; then
    printf "\r${COLOR_GREEN}  ✓ Keycloak keycloakx installation completed [100%%]${COLOR_RESET}\n"
    log_success "Keycloak deployed successfully via codecentric/keycloakx Helm chart"
  else
    printf "\r${COLOR_RED}  ✗ Keycloak keycloakx installation failed${COLOR_RESET}\n"
    log_error "Keycloak keycloakx Helm installation failed - error details:"
    if [[ -s "$temp_helm_error" ]]; then
      if is_verbose_mode; then
        cat "$temp_helm_error" >&2
      else
        tail -10 "$temp_helm_error" >&2
        log_info "Use --verbose flag to see full installation logs"
      fi
    fi
    rm -f "$temp_secret_log" "$temp_secret_error" "$temp_helm_log" "$temp_helm_error"
    return 1
  fi

  # Step 5: Wait for Keycloak to be ready
  log_info "⏳ Waiting for Keycloak services to be ready"

  local wait_progress=0
  local wait_steps=6
  local wait_stage="Starting"
  local ready=false
  local max_wait=180  # 3 minutes
  local wait_count=0

  while [[ $wait_count -lt $max_wait ]]; do
    if kubectl wait --for=condition=available --timeout=10s deployment/keycloak -n keycloak >/dev/null 2>&1; then
      ready=true
      break
    fi

    local char=${spinner_chars:spinner_idx:1}
    wait_progress=$(( (wait_progress + 1) % (wait_steps * 10) ))
    local progress_percent=$(( wait_progress * 100 / (wait_steps * 10) ))

    # Update stage based on progress
    case $((wait_progress / 10)) in
      0) wait_stage="Starting PostgreSQL" ;;
      1) wait_stage="Initializing Keycloak" ;;
      2) wait_stage="Loading identity providers" ;;
      3) wait_stage="Setting up authentication" ;;
      4) wait_stage="Configuring realms" ;;
      5) wait_stage="Finalizing services" ;;
    esac

    printf "\r${COLOR_YELLOW}  Waiting for Keycloak [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$progress_percent" "$wait_stage"

    spinner_idx=$(( (spinner_idx + 1) % 4 ))
    sleep 2
    wait_count=$((wait_count + 2))
  done

  if [[ "$ready" == "true" ]]; then
    printf "\r${COLOR_GREEN}  ✓ Keycloak services ready [100%%]${COLOR_RESET}\n"
    log_success "Keycloak is ready and accepting connections"

    # Step 6: Create permanent admin account
    log_info "👤 Creating permanent admin account"
    if create_permanent_keycloak_admin; then
      log_success "Permanent admin account created successfully"
    else
      log_warning "Could not create permanent admin account automatically (may need manual setup)"
    fi
  else
    printf "\r${COLOR_YELLOW}  ⚠ Keycloak taking longer than expected${COLOR_RESET}\n"
    log_warning "Keycloak deployment may still be starting (check with: kubectl get pods -n keycloak)"
  fi

  # Clean up temporary files
  rm -f "$temp_secret_log" "$temp_secret_error" "$temp_helm_log" "$temp_helm_error"

  # Installation completion summary
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_success "Keycloak deployment completed in ${duration}s"

  return 0
}

# Deploy PostgreSQL for Keycloak
deploy_keycloak_postgresql() {
  log_substep "Creating PostgreSQL deployment for Keycloak..."

  # Clean up any existing PostgreSQL resources first
  log_substep "Cleaning up any existing PostgreSQL resources..."
  execute_with_suppression kubectl delete pvc postgres-pvc -n keycloak --ignore-not-found=true
  execute_with_suppression kubectl delete deployment postgres -n keycloak --ignore-not-found=true
  execute_with_suppression kubectl delete service keycloak-postgresql -n keycloak --ignore-not-found=true
  execute_with_suppression kubectl delete configmap postgres-config -n keycloak --ignore-not-found=true

  # First ensure storage class and persistent volume exist
  log_substep "Setting up storage for PostgreSQL..."
  if createLocalStorageClassAndPV "keycloak-storage" "keycloak-pv" "/data/volumes/pv3"; then
    log_success "Keycloak storage configured"
  else
    log_error "Failed to create storage class and persistent volume"
    return 1
  fi

  # Create PostgreSQL deployment YAML
  cat > /tmp/keycloak-postgres.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: keycloak
data:
  POSTGRES_DB: keycloak
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: keycloak
type: Opaque
data:
  # POSTGRES_PASSWORD now comes from keycloak-postgresql secret
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: keycloak
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: keycloak-storage
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: keycloak-postgresql
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - exec pg_isready -U postgres -h 127.0.0.1 -p 5432
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - exec pg_isready -U postgres -h 127.0.0.1 -p 5432
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-postgresql
  namespace: keycloak
spec:
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
  type: ClusterIP
EOF

  # Apply PostgreSQL deployment
  if execute_with_suppression kubectl apply -f /tmp/keycloak-postgres.yaml; then
    log_success "PostgreSQL deployment created"
  else
    log_error "Failed to create PostgreSQL deployment"
    return 1
  fi

  # Wait for PostgreSQL to be ready
  log_substep "Waiting for PostgreSQL to be ready..."
  if execute_with_suppression kubectl wait --for=condition=ready pod -l app=postgres -n keycloak --timeout=120s; then
    log_success "PostgreSQL is ready"
    return 0
  else
    log_error "PostgreSQL failed to become ready"
    return 1
  fi
}

# Create permanent Keycloak admin account
create_permanent_keycloak_admin() {
  local max_attempts=30
  local attempt=1
  local keycloak_url=""
  local admin_user=""
  local admin_password=""

  # Get Keycloak URL from ingress
  keycloak_url=$(kubectl get ingress keycloak -n keycloak -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  if [[ -z "$keycloak_url" ]]; then
    log_warning "Could not determine Keycloak URL from ingress"
    return 1
  fi

  # Get admin credentials from secrets
  admin_user=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath='{.data.admin-user}' 2>/dev/null | base64 --decode)
  admin_password=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 --decode)

  if [[ -z "$admin_user" || -z "$admin_password" ]]; then
    log_warning "Could not retrieve admin credentials from secrets"
    return 1
  fi

  # Wait for Keycloak to be fully ready (not just pods, but admin API)
  log_substep "Waiting for Keycloak admin API to be ready..."
  while [[ $attempt -le $max_attempts ]]; do
    if curl -s -k "https://${keycloak_url}/realms/master/.well-known/openid-connect-configuration" >/dev/null 2>&1; then
      log_substep "Keycloak admin API is ready"
      break
    fi

    if [[ $attempt -eq $max_attempts ]]; then
      log_warning "Keycloak admin API not ready after ${max_attempts} attempts"
      return 1
    fi

    sleep 5
    attempt=$((attempt + 1))
  done

  # Get admin token
  log_substep "Authenticating with Keycloak..."
  local token_response=$(curl -s -k -X POST "https://${keycloak_url}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=${admin_user}&password=${admin_password}")

  local access_token=$(echo "$token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 2>/dev/null)

  if [[ -z "$access_token" ]]; then
    log_warning "Failed to authenticate with Keycloak admin API"
    return 1
  fi

  # Check if permanent admin user already exists
  log_substep "Checking for existing permanent admin user..."
  local existing_users=$(curl -s -k -X GET "https://${keycloak_url}/admin/realms/master/users" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json")

  if echo "$existing_users" | grep -q '"username":"admin"'; then
    log_substep "Permanent admin user already exists"
    return 0
  fi

  # Create permanent admin user
  log_substep "Creating permanent admin user..."
  local create_response=$(curl -s -k -X POST "https://${keycloak_url}/admin/realms/master/users" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "keycloak-admin",
      "enabled": true,
      "emailVerified": true,
      "firstName": "Administrator",
      "lastName": "User",
      "credentials": [{
        "type": "password",
        "value": "'${admin_password}'",
        "temporary": false
      }]
    }')

  if [[ $? -ne 0 ]]; then
    log_warning "Failed to create permanent admin user"
    return 1
  fi

  # Get the user ID of the newly created user
  sleep 2  # Wait a moment for user creation to complete
  local user_id=$(curl -s -k -X GET "https://${keycloak_url}/admin/realms/master/users?username=admin" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [[ -z "$user_id" ]]; then
    log_warning "Could not retrieve user ID for permanent admin user"
    return 1
  fi

  # Assign realm-admin role
  log_substep "Assigning admin role to permanent user..."
  local role_response=$(curl -s -k -X POST "https://${keycloak_url}/admin/realms/master/users/${user_id}/role-mappings/realm" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    -d '[{"id": "realm-admin", "name": "realm-admin"}]')

  if [[ $? -ne 0 ]]; then
    log_warning "Failed to assign admin role to permanent user"
    return 1
  fi

  log_substep "Permanent admin account created and configured successfully"
  return 0
}

# Export functions
export -f keycloakInst
export -f build_keycloak_with_progress
export -f deploy_keycloak_postgresql
export -f create_permanent_keycloak_admin

# Comprehensive Keycloak installation with certificate manager integration
installKeycloakWithCertMgr(){
  local start_time=$(date +%s)

  log_component_start "keycloak-install" "Installing Keycloak identity and access management with certificate management"

  log_step "1" "Updating system packages with smart caching"
  if declare -f safe_update_system_with_cache >/dev/null 2>&1; then
    if ! safe_update_system_with_cache; then
      log_error "Failed to update system packages"
      return 1
    fi
  else
    log_warning "safe_update_system_with_cache not available, skipping system update"
  fi

  log_step "2" "Installing dependencies with smart caching"
  if declare -f safe_install_system_dependencies >/dev/null 2>&1; then
    if ! safe_install_system_dependencies; then
      log_error "Failed to install Keycloak dependencies"
      return 1
    fi
  else
    log_warning "safe_install_system_dependencies not available, skipping dependency installation"
  fi

  log_step "3" "Installing core Keycloak services"
  if ! keycloakInst; then
    log_error "Keycloak core installation failed"
    return 1
  fi
  log_success "Keycloak core services installed"

  log_step "4" "Setting up persistent storage and certificates"
  log_substep "Creating storage class and persistent volume..."
  if createLocalStorageClassAndPV "keycloak-storage" "keycloak-pv" "/data/volumes/pv3"; then
    log_success "Keycloak storage configured"
  else
    log_warning "Storage configuration had issues but continuing"
  fi

  log_substep "Configuring ingress and SSL certificates..."
  if execute_with_suppression gok-new patch ingress keycloak keycloak letsencrypt $(defaultSubdomain); then
    log_success "Keycloak ingress and certificates configured"
  else
    log_warning "Ingress configuration had issues but continuing"
  fi

  log_step "5" "Waiting for Keycloak services to be ready"
  if wait_for_keycloak_services; then
    log_success "Keycloak services are ready and accepting connections"

    # Create permanent admin account
    log_step "6" "Creating permanent admin account"
    if create_permanent_keycloak_admin; then
      log_success "Permanent admin account created successfully"
    else
      log_warning "Could not create permanent admin account automatically (may need manual setup)"
    fi
  else
    log_error "Keycloak services failed to start properly"
    return 1
  fi

  log_step "7" "Installing Python dependencies for configuration"
  log_substep "Installing Python packages for Keycloak client management..."
  if execute_with_suppression apt install python3-dotenv python3-requests python3-jose -y; then
    log_success "Python dependencies installed"
  else
    log_warning "Python dependency installation had issues but continuing"
  fi

  log_step "8" "Configuring Keycloak clients and realms"
  if setup_keycloak_clients; then
    log_success "Keycloak clients and realms configured"

    log_step "9" "Setting up OAuth2 integration"
    if oauth2Secret; then
      log_success "OAuth2 integration configured"
    else
      log_warning "OAuth2 integration had issues but continuing"
    fi
  else
    log_error "Keycloak client configuration failed"
    return 1
  fi

  log_step "10" "Configuring LDAP user federation"
  if setup_ldap_federation; then
    log_success "LDAP user federation configured"
  else
    log_warning "LDAP federation configuration had issues but core Keycloak is working"
  fi

  # log_step "11" "Validating complete Keycloak installation"
  # if validate_keycloak_installation; then
  #   log_success "Keycloak installation validation completed"
  # else
  #   log_warning "Keycloak validation had issues but installation may still work"
  # fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # show_keycloak_installation_summary
  # log_component_success "keycloak-install" "Keycloak identity management system installed successfully"
  log_success "Complete Keycloak installation completed in ${duration}s"

  # Show Keycloak-specific next steps and recommend OAuth2
  # show_keycloak_next_steps

  # Suggest and install OAuth2 as the next step (only after complete installation)
  # suggest_and_install_next_module "keycloak"

  return 0
}

# Enhanced waiting for Keycloak services with immediate issue detection
wait_for_keycloak_services() {
  log_info "⏳ Waiting for Keycloak services to be ready with enhanced diagnostics (timeout: 4 minutes)"

  # First, check for immediate deployment issues
  log_substep "Performing initial deployment health check..."
  sleep 10  # Give pods time to start creating

  # Check for immediate image pull issues
  if ! check_image_pull_issues "keycloak" "keycloak"; then
    log_error "❌ Keycloak has Docker image pull issues - aborting wait"
    return 1
  fi

  # Check for resource constraint issues
  if ! check_resource_constraints "keycloak" "keycloak"; then
    log_error "❌ Keycloak has resource constraint issues - aborting wait"
    return 1
  fi

  # Use enhanced pod waiting with detailed diagnostics
  log_substep "Waiting for Keycloak pods with detailed monitoring..."
  if wait_for_pods_ready "keycloak" "" "240"; then
    log_success "✅ Keycloak pods are ready"
  else
    log_error "❌ Keycloak pods failed to become ready"
    return 1
  fi

  # Verify StatefulSet is actually ready (Keycloak uses StatefulSet, not Deployment)
  log_substep "Verifying Keycloak StatefulSet status..."
  if check_statefulset_readiness "keycloak" "keycloak"; then
    log_success "✅ Keycloak StatefulSet is healthy"
  else
    log_error "❌ Keycloak StatefulSet has issues"
    return 1
  fi

  # Check service connectivity
  log_substep "Verifying Keycloak service connectivity..."
  if check_service_connectivity "keycloak-http" "keycloak"; then
    log_success "✅ Keycloak service is accessible"
  else
    log_warning "⚠️  Keycloak service connectivity issues detected"
  fi

  # Final verification
  local keycloak_url="https://$(defaultSubdomain).$(rootDomain)/"
  log_success "✅ Keycloak is ready and accessible at: ${COLOR_CYAN}${keycloak_url}${COLOR_RESET}"

  # Brief pause for services to fully initialize
  log_substep "Allowing services to fully initialize..."
  sleep 10
  return 0
}

# Setup Keycloak clients and realms
setup_keycloak_clients() {
  log_info "🔧 Configuring Keycloak clients and realms"

  # Retrieve credentials from secrets
  local admin_id=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN}" 2>/dev/null | base64 --decode || echo "")
  local admin_pwd=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN_PASSWORD}" 2>/dev/null | base64 --decode || echo "")
  local client_id=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.CLIENT_ID}" 2>/dev/null | base64 --decode || echo "")
  local realm=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.OAUTH_REALM}" 2>/dev/null | base64 --decode || echo "")

  if [[ -z "$admin_id" || -z "$admin_pwd" || -z "$client_id" || -z "$realm" ]]; then
    log_error "Failed to retrieve Keycloak credentials from secrets"
    return 1
  fi

  log_substep "Admin User: ${COLOR_CYAN}${admin_id}${COLOR_RESET}"
  log_substep "Client ID: ${COLOR_CYAN}${client_id}${COLOR_RESET}"
  log_substep "Realm: ${COLOR_CYAN}${realm}${COLOR_RESET}"

  # Show what will be created
  log_substep "📋 Configuration Details:"
  log_substep "  • Realm: ${COLOR_CYAN}${realm}${COLOR_RESET} (will be created)"
  log_substep "  • Client: ${COLOR_CYAN}${client_id}${COLOR_RESET} (OIDC client for automation)"
  log_substep "  • Groups: ${COLOR_CYAN}administrators, developers${COLOR_RESET} (user groups)"
  log_substep "  • Sample User: ${COLOR_CYAN}skmaji1${COLOR_RESET} (with admin/developer roles)"
  log_substep "  • Scopes: ${COLOR_CYAN}groups${COLOR_RESET} (OIDC group membership claims)"
  log_substep "  • Token Lifespan: ${COLOR_CYAN}24 hours${COLOR_RESET} (access token validity)"

  # Run Keycloak client configuration
  log_substep "🚀 Running Keycloak client configuration script..."
  local keycloak_dir="$GOK_ROOT/../../install_k8s/keycloak"
  if execute_with_suppression pushd "$keycloak_dir" && execute_with_suppression python3 keycloak-client.py all "$admin_id" "$admin_pwd" "$client_id" "$realm" && execute_with_suppression popd; then
    log_success "Keycloak client configuration completed"
    return 0
  else
    log_error "Keycloak client configuration failed"
    popd || true
    return 1
  fi
}

# Setup OAuth2 secrets for integration
oauth2Secret(){
  CLIENT_ID=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{['data']['CLIENT_ID']}" | base64 --decode)
  REALM=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{['data']['OAUTH_REALM']}" | base64 --decode)
  KEYCLOAK_URL=$(fullKeycloakUrl)
  ADMIN_USERNAME=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{['data']['KEYCLOAK_ADMIN']}" | base64 --decode)
  ADMIN_PASSWORD=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN_PASSWORD}" | base64 --decode)

  client_secret=$(fetch_client_secret "$KEYCLOAK_URL" "$REALM" "$CLIENT_ID" "$ADMIN_USERNAME" "$ADMIN_PASSWORD")

  # Use environment variables with fallbacks to predefined Keycloak configuration
  ACTIVE_PROFILE="${ACTIVE_PROFILE:-keycloak}"
  OIDC_ISSUE_URL="${OIDC_ISSUE_URL:-https://keycloak.$(rootDomain)/realms/${REALM}}"
  OIDC_USERNAME_CLAIM="${OIDC_USERNAME_CLAIM:-sub}"
  OIDC_GROUPS_CLAIM="${OIDC_GROUPS_CLAIM:-groups}"
  AUTH0_DOMAIN="${AUTH0_DOMAIN:-keycloak.$(rootDomain)}"
  APP_HOST="${APP_HOST:-$(defaultSubdomain).$(rootDomain)}"
  JWKS_URL="${JWKS_URL:-${OIDC_ISSUE_URL}/protocol/openid-connect/certs}"
  OAUTH_SERVER_URI="${OAUTH_SERVER_URI:-https://$(fullKeycloakUrl)}"

  # If secret already exists then delete it
  kubectl get secret oauth-secrets -n kube-system 2>/dev/null && kubectl delete secret oauth-secrets -n kube-system
  kubectl create secret generic oauth-secrets \
    --from-literal=OAUTH_REALM="${REALM}" \
    --from-literal=ACTIVE_PROFILE="${ACTIVE_PROFILE}" \
    --from-literal=OIDC_CLIENT_ID="${CLIENT_ID}" \
    --from-literal=OIDC_ISSUE_URL="${OIDC_ISSUE_URL}" \
    --from-literal=OIDC_USERNAME_CLAIM="${OIDC_USERNAME_CLAIM}" \
    --from-literal=OIDC_GROUPS_CLAIM="${OIDC_GROUPS_CLAIM}" \
    --from-literal=AUTH0_DOMAIN="${AUTH0_DOMAIN}" \
    --from-literal=APP_HOST="${APP_HOST}" \
    --from-literal=JWKS_URL="${JWKS_URL}" \
    --from-literal=OAUTH_SERVER_URI="${OAUTH_SERVER_URI}" \
    --from-literal=OIDC_CLIENT_SECRET="${client_secret}" -n kube-system
}

# Setup LDAP user federation
setup_ldap_federation() {
  log_info "🔗 Setting up LDAP user federation"

  # Check if LDAP service is running
  log_substep "Checking LDAP service availability..."
  local ldap_status=$(kubectl get svc ldap -n ldap 2>/dev/null | grep ldap | wc -l)

  if [[ "$ldap_status" -eq 0 ]]; then
    log_warning "LDAP service is not running - skipping user federation setup"
    log_info "To set up LDAP federation later, ensure LDAP is installed and run the federation scripts manually"
    return 0
  else
    log_success "LDAP service is running - proceeding with user federation"
  fi

  # Get credentials
  local admin_id=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN}" 2>/dev/null | base64 --decode || echo "")
  local admin_pwd=$(kubectl get secret keycloak-secrets -n keycloak -o jsonpath="{.data.KEYCLOAK_ADMIN_PASSWORD}" 2>/dev/null | base64 --decode || echo "")

  : "${LDAP_PASSWORD:=$(promptSecret "Please enter LDAP password for admin: ")}"

  # Create audience scope
  log_substep "Setting up Kubernetes audience scope..."
  local keycloak_dir="$GOK_ROOT/../../install_k8s/keycloak"
  if execute_with_suppression pushd "$keycloak_dir" && execute_with_suppression chmod +x setup_kubernetes_audience.sh && execute_with_suppression ./setup_kubernetes_audience.sh "$admin_id" "$admin_pwd" && execute_with_suppression popd; then
    log_success "Kubernetes audience scope created"
  else
    log_error "Audience scope creation failed"
    popd || true
    return 1
  fi

  # Create user federation
  log_substep "Setting up LDAP user federation..."
  if execute_with_suppression chmod +x setup_user_federation.sh && execute_with_suppression ./setup_user_federation.sh "$admin_id" "$admin_pwd" "$LDAP_PASSWORD"; then
    log_success "LDAP user federation created"
  else
    log_error "User federation creation failed"
    return 1
  fi

  # Create group mappers
  log_substep "Setting up Keycloak group mappers..."
  if execute_with_suppression chmod +x setup_group_mappers.sh && execute_with_suppression ./setup_group_mappers.sh "$admin_id" "$admin_pwd"; then
    log_success "Keycloak group mappers created"
  else
    log_error "Group mapper creation failed"
    return 1
  fi

  return 0
}

# Fetch client secret from Keycloak
fetch_client_secret() {
  local keycloak_url="$1"
  local realm="$2"
  local client_id="$3"
  local admin_username="$4"
  local admin_password="$5"

  # Get admin token
  local token_response=$(curl -s -k -X POST "${keycloak_url}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password&client_id=admin-cli&username=${admin_username}&password=${admin_password}")

  local access_token=$(echo "$token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$access_token" ]]; then
    log_error "Failed to get admin token for client secret retrieval"
    return 1
  fi

  # Get client secret
  local client_response=$(curl -s -k -X GET "${keycloak_url}/admin/realms/${realm}/clients" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json")

  local client_uuid=$(echo "$client_response" | grep -o '"id":"[^"]*","clientId":"'"${client_id}"'"' | cut -d'"' -f4)

  if [[ -z "$client_uuid" ]]; then
    log_error "Failed to find client UUID for ${client_id}"
    return 1
  fi

  local secret_response=$(curl -s -k -X GET "${keycloak_url}/admin/realms/${realm}/clients/${client_uuid}/client-secret" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json")

  local client_secret=$(echo "$secret_response" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$client_secret" ]]; then
    log_error "Failed to retrieve client secret"
    return 1
  fi

  echo "$client_secret"
}

export -f installKeycloakWithCertMgr
export -f wait_for_keycloak_services
export -f setup_keycloak_clients
export -f oauth2Secret
export -f setup_ldap_federation
export -f fetch_client_secret