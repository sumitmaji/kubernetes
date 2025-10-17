#!/bin/bash

# RabbitMQ Installation Module
# Provides RabbitMQ message broker with cluster operator

rabbitmqInst() {
  local start_time=$(date +%s)

  log_component_start "rabbitmq-install" "Installing RabbitMQ message broker with cluster operator"

  log_step "1" "Creating RabbitMQ namespace and storage"
  log_substep "Creating namespace: rabbitmq"

  if kubectl create namespace rabbitmq >/dev/null 2>&1; then
    log_success "RabbitMQ namespace created"
  else
    log_info "RabbitMQ namespace already exists"
  fi

  log_substep "Creating persistent storage (10Gi local volume)"
  if createLocalStorageClassAndPV "rabbitmq-storage" "rabbitmq-pv" "/data/volumes/rabbitmq"; then
    log_success "RabbitMQ persistent storage created"
    log_info "📁 Storage: 10Gi at /data/volumes/rabbitmq"
  else
    log_warning "RabbitMQ storage creation had issues but continuing"
  fi

  log_step "2" "Installing RabbitMQ Cluster Operator"
  log_substep "Applying RabbitMQ cluster operator manifests"

  if execute_with_suppression kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"; then
    log_success "RabbitMQ cluster operator manifests applied"
  else
    log_error "Failed to apply RabbitMQ cluster operator"
    return 1
  fi

  log_substep "Waiting for cluster operator to be ready"
  if kubectl wait --for=condition=available deployment/rabbitmq-cluster-operator --timeout=300s -n rabbitmq-system >/dev/null 2>&1; then
    log_success "RabbitMQ cluster operator is ready"
  else
    log_error "RabbitMQ cluster operator failed to become ready"
    return 1
  fi

  log_step "3" "Creating RabbitMQ cluster"
  log_substep "Deploying RabbitMQ cluster with 1 replica"
  log_info "🐰 Cluster: rabbitmq (1 replica, 3.12-management)"
  log_info "💾 Resources: 256m-1 CPU, 1Gi-2Gi RAM"
  log_info "🔧 Config: Management UI enabled, admin user tags"

  # Create RabbitMQ cluster with progress tracking
  log_substep "Creating RabbitMQ cluster manifest"
  local rabbitmq_manifest=$(mktemp)

  cat > "$rabbitmq_manifest" <<EOF
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rabbitmq
  namespace: rabbitmq
spec:
  replicas: 1
  image: rabbitmq:3.12-management
  resources:
    requests:
      cpu: 256m
      memory: 1Gi
    limits:
      cpu: 1
      memory: 2Gi
  rabbitmq:
    additionalConfig: |
      log.console.level = info
      channel_max = 1700
      default_user_tags.administrator = true
      management.tcp.port = 15672
  persistence:
    storageClassName: rabbitmq-storage
    storage: 10Gi
  service:
    type: ClusterIP
  override:
    statefulSet:
      spec:
        template:
          spec:
            containers:
            - name: rabbitmq
              ports:
              - containerPort: 5672
                name: amqp
              - containerPort: 15672
                name: management
EOF

  if execute_with_suppression kubectl apply -f "$rabbitmq_manifest"; then
    log_success "RabbitMQ cluster configuration applied"
    rm -f "$rabbitmq_manifest"
  else
    log_error "Failed to apply RabbitMQ cluster configuration"
    rm -f "$rabbitmq_manifest"
    return 1
  fi

  log_step "6" "Configuring RabbitMQ networking"
  log_substep "Creating management UI ingress"
  log_info "🌐 Ingress: rabbitmq.$(rootDomain) → Management UI"

  local ingress_manifest=$(mktemp)

  cat > "$ingress_manifest" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rabbitmq-management
  namespace: rabbitmq
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: rabbitmq.$(rootDomain)
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rabbitmq
            port:
              number: 15672
EOF

  if execute_with_suppression kubectl apply -f "$ingress_manifest"; then
    log_success "RabbitMQ management ingress created"
    rm -f "$ingress_manifest"
  else
    log_warning "RabbitMQ management ingress creation had issues"
    rm -f "$ingress_manifest"
  fi

  log_step "4" "Waiting for RabbitMQ cluster to be ready"
  log_substep "Waiting for RabbitMQ cluster to reach AllReplicasReady state"

  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local spinner_idx=0
  local wait_start=$(date +%s)

  while true; do
    local char=${spinner_chars:spinner_idx:1}
    local elapsed=$(( $(date +%s) - wait_start ))

    if kubectl get rabbitmqcluster rabbitmq -n rabbitmq -o jsonpath='{.status.conditions[?(@.type=="AllReplicasReady")].status}' 2>/dev/null | grep -q "True"; then
      echo -ne "\r${COLOR_GREEN}✅${COLOR_RESET} RabbitMQ cluster ready (${elapsed}s)"
      echo ""
      break
    fi

    echo -ne "\r${char} Waiting for RabbitMQ cluster... (${elapsed}s)"
    sleep 2
    spinner_idx=$(( (spinner_idx + 1) % ${#spinner_chars} ))
  done

  log_substep "Waiting for RabbitMQ pods to be ready"
  if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq -n rabbitmq --timeout=300s >/dev/null 2>&1; then
    log_success "RabbitMQ pods are ready"
  else
    log_warning "RabbitMQ pods readiness check timed out but continuing"
  fi

  log_step "5" "Configuring TLS and certificates"
  log_substep "Applying Let's Encrypt certificate to RabbitMQ ingress"

  if execute_with_suppression gok patch ingress rabbitmq-management rabbitmq letsencrypt rabbitmq; then
    log_success "RabbitMQ TLS certificate configured"
  else
    log_warning "RabbitMQ TLS configuration had issues but continuing"
  fi

  log_step "9" "Retrieving RabbitMQ credentials"
  log_substep "Extracting default user credentials from secret"

  local rabbitmq_username=""
  local rabbitmq_password=""

  # Wait a moment for the secret to be created
  sleep 3

  if rabbitmq_username=$(kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode 2>/dev/null); then
    log_success "RabbitMQ username retrieved"
  else
    log_warning "Could not retrieve RabbitMQ username"
    rabbitmq_username="default_user_????"
  fi

  if rabbitmq_password=$(kubectl get secret rabbitmq-default-user -n rabbitmq -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null); then
    log_success "RabbitMQ password retrieved"
  else
    log_warning "Could not retrieve RabbitMQ password"
    rabbitmq_password="????"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # show_installation_summary "rabbitmq" "rabbitmq" "RabbitMQ message broker with management UI"

  log_component_success "rabbitmq-install" "RabbitMQ message broker installed successfully"

  # Show RabbitMQ access information
  echo ""
  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🐰 RABBITMQ ACCESS INFORMATION${COLOR_RESET}"
  echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🌐 Management UI:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}URL:${COLOR_RESET}      https://rabbitmq.$(rootDomain)"
  echo -e "  ${COLOR_CYAN}Username:${COLOR_RESET} ${rabbitmq_username}"
  echo -e "  ${COLOR_CYAN}Password:${COLOR_RESET} ${rabbitmq_password}"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🔌 Service Endpoints:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}AMQP:${COLOR_RESET}     rabbitmq.rabbitmq.svc.cluster.local:5672"
  echo -e "  ${COLOR_CYAN}Management:${COLOR_RESET} rabbitmq.rabbitmq.svc.cluster.local:15672"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}📊 Cluster Information:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}Namespace:${COLOR_RESET}    rabbitmq"
  echo -e "  ${COLOR_CYAN}Cluster:${COLOR_RESET}      rabbitmq (1 replica)"
  echo -e "  ${COLOR_CYAN}Image:${COLOR_RESET}        rabbitmq:3.12-management"
  echo -e "  ${COLOR_CYAN}Storage:${COLOR_RESET}      10Gi persistent volume"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🔧 Connection Examples:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Python (pika)${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}import pika${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}connection = pika.BlockingConnection(pika.ConnectionParameters('${rabbitmq_username}', '${rabbitmq_password}', 'rabbitmq.rabbitmq.svc.cluster.local', 5672))${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_DIM}# CLI Tools${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}kubectl port-forward -n rabbitmq svc/rabbitmq 5672:5672${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}kubectl port-forward -n rabbitmq svc/rabbitmq 15672:15672${COLOR_RESET}"
  echo ""

  log_success "RabbitMQ installation completed in ${duration}s"

  # Suggest next component installation
  # show_rabbitmq_next_steps
}

export -f rabbitmqInst