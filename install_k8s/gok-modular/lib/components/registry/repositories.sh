#!/bin/bash

# GOK Registry Components Module - Container Registry, Helm Chart Registry

# Install Docker Registry for container images
registryInst() {
    log_component_start "Registry" "Installing container image registry"
    start_component "registry"
    
    local namespace="registry"
    ensure_namespace "$namespace"
    
    # Add Twuni Helm repository for Docker Registry
    log_info "Adding Twuni Helm repository"
    execute_with_suppression helm repo add twuni https://helm.twun.io
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/registry-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
image:
  repository: registry
  tag: 2.8.1

service:
  type: NodePort
  nodePort: 30120
  port: 5000

ingress:
  enabled: true
  className: ""
  hosts:
    - registry.local
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"

persistence:
  enabled: true
  size: 50Gi
  storageClass: local-path
  accessModes:
    - ReadWriteOnce

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

configData:
  version: 0.1
  log:
    fields:
      service: registry
  storage:
    cache:
      blobdescriptor: inmemory
    filesystem:
      rootdirectory: /var/lib/registry
  http:
    addr: :5000
    headers:
      X-Content-Type-Options: [nosniff]
  health:
    storagedriver:
      enabled: true
      interval: 10s
      threshold: 3

secrets:
  htpasswd: ""  # Add if you want authentication

updateStrategy:
  type: RollingUpdate
EOF
    fi
    
    helm_install_with_summary "registry" "twuni/docker-registry" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        # Create registry authentication secret if needed
        local auth_yaml="${GOK_CONFIG_DIR}/registry-auth.yaml"
        if [[ ! -f "$auth_yaml" ]]; then
            cat > "$auth_yaml" << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: registry-auth
  namespace: registry
type: Opaque
data:
  htpasswd: YWRtaW46JDJ5JDEwJE5IL2I5VEUuTjZ5TkVHRHVGQlJSQXVJOGhoNzRsOW9WRGgvMUlkYmtqd2VCM2lzc2lETzZP  # admin:admin123
---
# Registry UI for web interface
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry-ui
  template:
    metadata:
      labels:
        app: registry-ui
    spec:
      containers:
      - name: registry-ui
        image: joxit/docker-registry-ui:latest
        ports:
        - containerPort: 80
        env:
        - name: REGISTRY_TITLE
          value: "GOK Container Registry"
        - name: REGISTRY_URL
          value: "http://registry.registry.svc.cluster.local:5000"
        - name: DELETE_IMAGES
          value: "true"
        - name: SHOW_CONTENT_DIGEST
          value: "true"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: registry-ui
  namespace: registry
spec:
  selector:
    app: registry-ui
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30121
  type: NodePort
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $auth_yaml" "Installing registry UI and authentication"
        
        # Wait for ingress to be ready and capture registry URL
        log_info "Waiting for registry ingress to be ready..."
        local ingress_ready=false
        local attempts=0
        local max_attempts=30
        
        while [[ $attempts -lt $max_attempts && $ingress_ready == false ]]; do
            if kubectl get ingress registry -n registry >/dev/null 2>&1; then
                local registry_host=$(kubectl get ingress registry -n registry -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
                if [[ -n "$registry_host" ]]; then
                    ingress_ready=true
                    log_success "Registry ingress ready at: https://$registry_host"
                    
                    # Create registry-config configmap with the URL
                    if execute_with_suppression kubectl create configmap registry-config \
                        --from-literal=url="$registry_host" \
                        --from-literal=protocol="https" \
                        --from-literal=port="443" \
                        --from-literal=installed="$(date)" \
                        -n kube-system --dry-run=client -o yaml | kubectl apply -f -; then
                        log_success "Registry configuration stored in configmap"
                    else
                        log_warning "Failed to create registry configmap"
                    fi
                fi
            fi
            
            if [[ $ingress_ready == false ]]; then
                attempts=$((attempts + 1))
                sleep 2
            fi
        done
        
        if [[ $ingress_ready == false ]]; then
            log_warning "Registry ingress not ready, using NodePort fallback"
            # Fallback to NodePort URL
            local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
            local registry_url="${node_ip}:30120"
            
            if execute_with_suppression kubectl create configmap registry-config \
                --from-literal=url="$registry_url" \
                --from-literal=protocol="http" \
                --from-literal=port="30120" \
                --from-literal=installed="$(date)" \
                -n kube-system --dry-run=client -o yaml | kubectl apply -f -; then
                log_success "Registry configuration stored in configmap (NodePort fallback)"
            fi
        fi
        
        log_success "Container registry installed successfully"
        log_info "Registry API: https://$registry_host (or http://<node-ip>:30120)"
        log_info "Registry UI: http://<node-ip>:30121"
        log_info "Push images with: docker tag <image> $registry_host/<image>"
        complete_component "registry"
    else
        log_error "Container registry installation failed"
        fail_component "registry" "Helm installation failed"
        return 1
    fi
}

# Install Helm Chart Registry (ChartMuseum)
chartRegistryInst() {
    log_component_start "Chart Registry" "Installing Helm chart repository"
    start_component "chart-registry"
    
    local namespace="chart-registry"
    ensure_namespace "$namespace"
    
    # Add ChartMuseum Helm repository
    log_info "Adding ChartMuseum Helm repository"
    execute_with_suppression helm repo add chartmuseum https://chartmuseum.github.io/charts
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/chartmuseum-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
image:
  repository: ghcr.io/helm/chartmuseum
  tag: v0.15.0

env:
  open:
    STORAGE: local
    ALLOW_OVERWRITE: true
    DISABLE_API: false
    AUTH_ANONYMOUS_GET: true
    CONTEXT_PATH: ""
    INDEX_LIMIT: 0
    CACHE: ""
    BASIC_AUTH_USER: ""
    BASIC_AUTH_PASS: ""
    DEPTH: 1

service:
  type: NodePort
  nodePort: 30122
  port: 8080

ingress:
  enabled: false
  hosts:
    - name: charts.local

persistence:
  enabled: true
  accessMode: ReadWriteOnce
  size: 20Gi
  storageClass: local-path

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Enable chart manipulation APIs
env:
  open:
    DISABLE_API: false
    ALLOW_OVERWRITE: true
    AUTH_ANONYMOUS_GET: true

# Security configuration
securityContext:
  enabled: true
  runAsUser: 1000
  fsGroup: 1000
EOF
    fi
    
    helm_install_with_summary "chartmuseum" "chartmuseum/chartmuseum" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Helm chart registry installed successfully"
        log_info "Chart registry: http://<node-ip>:30122"
        log_info ""
        log_info "Add repository: helm repo add gok-charts http://<node-ip>:30122"
        log_info "Upload charts: curl --data-binary '@chart.tgz' http://<node-ip>:30122/api/charts"
        log_info ""
        log_info "Example chart upload:"
        log_info "  helm package ./my-chart"
        log_info "  curl --data-binary '@my-chart-1.0.0.tgz' http://<node-ip>:30122/api/charts"
        complete_component "chart-registry"
    else
        log_error "Helm chart registry installation failed"
        fail_component "chart-registry" "Helm installation failed"
        return 1
    fi
}

# Install Harbor registry (enterprise-grade registry with security)
harborInst() {
    log_component_start "Harbor" "Installing enterprise container registry"
    start_component "harbor"
    
    local namespace="harbor"
    ensure_namespace "$namespace"
    
    # Add Harbor Helm repository
    log_info "Adding Harbor Helm repository"
    execute_with_suppression helm repo add harbor https://helm.goharbor.io
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/harbor-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
expose:
  type: nodePort
  nodePort:
    ports:
      http:
        nodePort: 30123
      https:
        nodePort: 30124
  tls:
    enabled: false

externalURL: http://harbor.local:30123

harborAdminPassword: "Harbor12345"

database:
  type: internal
  internal:
    password: "changeit"

redis:
  type: internal

trivy:
  enabled: true

notary:
  enabled: false

chartmuseum:
  enabled: true

clair:
  enabled: false

persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      storageClass: "local-path"
      size: 50Gi
    chartmuseum:
      storageClass: "local-path"
      size: 5Gi
    jobservice:
      storageClass: "local-path"
      size: 1Gi
    database:
      storageClass: "local-path"
      size: 5Gi
    redis:
      storageClass: "local-path"
      size: 1Gi
    trivy:
      storageClass: "local-path"
      size: 5Gi

nginx:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

portal:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

core:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

jobservice:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

registry:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

chartmuseum:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

trivy:
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi
EOF
    fi
    
    helm_install_with_summary "harbor" "harbor/harbor" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=15m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Harbor registry installed successfully"
        log_info "Harbor UI: http://<node-ip>:30123"
        log_info "Admin credentials: admin / Harbor12345"
        log_info ""
        log_info "Features included:"
        log_info "  - Container registry with vulnerability scanning"
        log_info "  - Helm chart repository"
        log_info "  - Role-based access control"
        log_info "  - Image signing and content trust"
        log_info ""
        log_info "Docker login: docker login <node-ip>:30123"
        complete_component "harbor"
    else
        log_error "Harbor registry installation failed"
        fail_component "harbor" "Helm installation failed"
        return 1
    fi
}

# Install Nexus Repository Manager
nexusInst() {
    log_component_start "Nexus" "Installing Nexus Repository Manager"
    start_component "nexus"
    
    local namespace="nexus"
    ensure_namespace "$namespace"
    
    # Add Sonatype Helm repository
    log_info "Adding Sonatype Helm repository"
    execute_with_suppression helm repo add sonatype https://sonatype.github.io/helm3-charts/
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/nexus-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
image:
  repository: sonatype/nexus3
  tag: 3.41.1

nameOverride: ""
fullnameOverride: ""

deployment:
  additionalContainers: []
  additionalVolumes: []
  additionalVolumeMounts: []
  
nexusProxy:
  env:
    nexusDockerHost: nexus.local
    nexusHttpHost: nexus.local

nexus:
  docker:
    enabled: true
    registries:
      - host: nexus.local
        port: 5000
  env:
    - name: install4jAddVmParams
      value: "-Xms2g -Xmx2g -XX:MaxDirectMemorySize=3g"

service:
  type: NodePort
  ports:
    nexus-service:
      nodePort: 30125
      port: 8081
    nexus-docker-service:
      nodePort: 30126
      port: 5000

ingress:
  enabled: false

persistence:
  enabled: true
  storageClass: local-path
  storageSize: 50Gi

resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Security context
securityContext:
  runAsUser: 200
  runAsGroup: 200
  fsGroup: 200
EOF
    fi
    
    helm_install_with_summary "nexus" "sonatype/nexus-repository-manager" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Nexus Repository Manager installed successfully"
        log_info "Nexus UI: http://<node-ip>:30125"
        log_info "Docker registry: <node-ip>:30126"
        log_info ""
        log_info "Get admin password:"
        log_info "kubectl exec -n nexus deployment/nexus -- cat /nexus-data/admin.password"
        log_info ""
        log_info "Supported repositories:"
        log_info "  - Docker (hosted, proxy, group)"
        log_info "  - Helm charts"
        log_info "  - Maven, NPM, PyPI, and more"
        complete_component "nexus"
    else
        log_error "Nexus Repository Manager installation failed"
        fail_component "nexus" "Helm installation failed"
        return 1
    fi
}

# Install complete registry stack
registryStackInst() {
    log_component_start "Registry Stack" "Installing complete registry solution"
    start_component "registry-stack"
    
    log_info "Installing registry stack components..."
    
    # Install core registry components
    registryInst || return 1
    chartRegistryInst || return 1
    
    log_success "Registry stack installed successfully"
    log_info "Components installed:"
    log_info "  - Docker Registry: Container image storage"
    log_info "  - ChartMuseum: Helm chart repository"
    log_info ""
    log_info "Access points:"
    log_info "  - Container Registry: http://<node-ip>:30120"
    log_info "  - Registry UI: http://<node-ip>:30121"
    log_info "  - Chart Repository: http://<node-ip>:30122"
    
    complete_component "registry-stack"
}