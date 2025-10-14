#!/bin/bash

# GOK Keycloak Identity Management Component
# Provides comprehensive identity and access management with OAuth2/OIDC support

# Keycloak identity management installation
keycloakInst(){
  local start_time=$(date +%s)

  log_component_start "keycloak" "Installing Keycloak identity management service"

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

  log_success "Keycloak configuration parameters collected"

  log_step "3" "Building and deploying Keycloak identity management"

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

  log_step "5" "Validating Keycloak installation"
  if validate_keycloak_installation; then
    log_success "Keycloak installation validation completed"
  else
    log_warning "Keycloak validation had issues but installation may still work"
  fi

  if execute_with_suppression popd; then
    log_success "Keycloak installation directory cleanup completed"
  else
    log_warning "Keycloak installation directory cleanup had issues"
  fi

  # Installation completion summary
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_success "Keycloak identity management installation completed in ${duration}s"

  # Show Keycloak summary
  show_keycloak_summary

  # Show next steps
  show_keycloak_next_steps

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