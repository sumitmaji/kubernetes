#!/bin/bash

# GOK Monitoring Components Module - Prometheus, Grafana, Cadvisor, Metrics Server

# Install Prometheus monitoring system
prometheusInst() {
    log_component_start "Prometheus" "Installing Prometheus monitoring system"
    start_component "prometheus"
    
    local namespace="monitoring"
    
    # Create namespace
    ensure_namespace "$namespace"
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install Prometheus with custom values
    local values_file="${GOK_CONFIG_DIR}/prometheus-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

grafana:
  adminPassword: admin123
  persistence:
    enabled: true
    storageClassName: local-path
    size: 2Gi
  
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
EOF
    fi
    
    helm_install_with_summary "prometheus" "prometheus-community/kube-prometheus-stack" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Prometheus installed successfully"
        log_info "Grafana admin password: admin123"
        log_info "Access Grafana at: http://<node-ip>:30080"
        complete_component "prometheus"
    else
        log_error "Prometheus installation failed"
        fail_component "prometheus" "Helm installation failed"
        return 1
    fi
}

# Install Grafana dashboards
grafanaInst() {
    log_component_start "Grafana" "Installing Grafana with custom dashboards"
    start_component "grafana"
    
    local namespace="monitoring"
    
    # Check if Prometheus stack is already installed
    if helm list -n "$namespace" | grep -q "prometheus"; then
        log_info "Grafana is included in Prometheus stack installation"
        complete_component "grafana"
        return 0
    fi
    
    # Install standalone Grafana
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/grafana-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
adminUser: admin
adminPassword: admin123

persistence:
  enabled: true
  storageClassName: local-path
  size: 2Gi

service:
  type: NodePort
  nodePort: 30080

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server:80
      access: proxy
      isDefault: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default
EOF
    fi
    
    helm_install_with_summary "grafana" "grafana/grafana" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Grafana installed successfully"
        complete_component "grafana"
    else
        log_error "Grafana installation failed"
        fail_component "grafana" "Helm installation failed"
        return 1
    fi
}

# Install cAdvisor for container metrics
cadvisorInst() {
    log_component_start "cAdvisor" "Installing cAdvisor container advisor"
    start_component "cadvisor"
    
    local namespace="monitoring"
    ensure_namespace "$namespace"
    
    # Create cAdvisor DaemonSet
    local cadvisor_yaml="${GOK_CONFIG_DIR}/cadvisor.yaml"
    if [[ ! -f "$cadvisor_yaml" ]]; then
        cat > "$cadvisor_yaml" << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      serviceAccountName: cadvisor
      containers:
      - name: cadvisor
        image: gcr.io/cadvisor/cadvisor:v0.47.0
        resources:
          requests:
            memory: 200Mi
            cpu: 150m
          limits:
            memory: 2000Mi
            cpu: 300m
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
        - name: disk
          mountPath: /dev/disk
          readOnly: true
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        args:
          - --housekeeping_interval=10s
          - --max_housekeeping_interval=15s
          - --event_storage_event_limit=default=0
          - --event_storage_age_limit=default=0
          - --disable_metrics=percpu,sched,tcp,udp,disk,diskIO,accelerator,hugetlb,referenced_memory,cpu_topology,resctrl
          - --docker_only
      automountServiceAccountToken: false
      terminationGracePeriodSeconds: 30
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
      - name: disk
        hostPath:
          path: /dev/disk
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cadvisor
  namespace: monitoring
---
apiVersion: v1
kind: Service
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    app: cadvisor
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $cadvisor_yaml" "Applying cAdvisor configuration"
    
    if [[ $? -eq 0 ]]; then
        log_success "cAdvisor installed successfully"
        complete_component "cadvisor"
    else
        log_error "cAdvisor installation failed"
        fail_component "cadvisor" "Kubernetes deployment failed"
        return 1
    fi
}

# Install Metrics Server for resource metrics
metricServerInst() {
    log_component_start "Metrics Server" "Installing Kubernetes Metrics Server"
    start_component "metric-server"
    
    # Install Metrics Server
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/metrics-server-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
args:
  - --cert-dir=/tmp
  - --secure-port=4443
  - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
  - --kubelet-use-node-status-port
  - --metric-resolution=15s
  - --kubelet-insecure-tls

resources:
  requests:
    cpu: 100m
    memory: 200Mi
  limits:
    cpu: 1000m
    memory: 1000Mi

nodeSelector:
  kubernetes.io/os: linux
EOF
    fi
    
    helm_install_with_summary "metrics-server" "metrics-server/metrics-server" \
        "--namespace kube-system" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Metrics Server installed successfully"
        
        # Wait for metrics server to be ready
        log_info "Waiting for metrics server to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
        
        # Test metrics availability
        sleep 30
        if kubectl top nodes &>/dev/null; then
            log_success "Metrics Server is working correctly"
        else
            log_warning "Metrics Server installed but metrics not yet available (may need a few minutes)"
        fi
        
        complete_component "metric-server"
    else
        log_error "Metrics Server installation failed"
        fail_component "metric-server" "Helm installation failed"
        return 1
    fi
}

# Install full monitoring stack (Prometheus + Grafana + cAdvisor + Metrics Server)
monitoringInst() {
    log_component_start "Monitoring Stack" "Installing complete monitoring solution"
    start_component "monitoring"
    
    log_info "Installing complete monitoring stack..."
    
    # Install components in order
    metricServerInst || return 1
    prometheusInst || return 1 
    cadvisorInst || return 1
    
    log_success "Complete monitoring stack installed successfully"
    log_info "Components installed:"
    log_info "  - Prometheus: Metrics collection and alerting"
    log_info "  - Grafana: Visualization and dashboards" 
    log_info "  - cAdvisor: Container metrics"
    log_info "  - Metrics Server: Resource metrics API"
    
    complete_component "monitoring"
}

# Install Heapster (deprecated but kept for compatibility)
heapsterInst() {
    log_warning "Heapster is deprecated. Installing Metrics Server instead."
    metricServerInst
}