#!/bin/bash

# GOK Platform Components Module - GOK-specific platform services and bundles

# Install GOK Cloud platform services
gokCloudInst() {
    log_component_start "GOK Cloud" "Installing GOK cloud platform services"
    start_component "gok-cloud"
    
    local namespace="gok-platform"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local gok_cloud_yaml="${GOK_CONFIG_DIR}/gok-cloud.yaml"
    if [[ ! -f "$gok_cloud_yaml" ]]; then
        cat > "$gok_cloud_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-cloud-api
  namespace: gok-platform
  labels:
    app: gok-cloud-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gok-cloud-api
  template:
    metadata:
      labels:
        app: gok-cloud-api
    spec:
      containers:
      - name: gok-api
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: gok-api-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: gok-api-config
        configMap:
          name: gok-cloud-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gok-cloud-config
  namespace: gok-platform
data:
  default.conf: |
    server {
        listen 80;
        server_name gok-cloud;
        
        location /api/v1/health {
            return 200 '{"status":"healthy","platform":"gok-cloud","version":"1.0.0"}';
            add_header Content-Type application/json;
        }
        
        location /api/v1/components {
            return 200 '{"components":["docker","kubernetes","helm","monitoring","security","storage"]}';
            add_header Content-Type application/json;
        }
        
        location / {
            return 200 '<!DOCTYPE html>
<html>
<head><title>GOK Cloud Platform</title></head>
<body>
<h1>GOK Cloud Platform</h1>
<p>Welcome to the GOK Kubernetes Operations Platform</p>
<ul>
<li><a href="/api/v1/health">Health Check</a></li>
<li><a href="/api/v1/components">Available Components</a></li>
</ul>
</body>
</html>';
            add_header Content-Type text/html;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: gok-cloud-api
  namespace: gok-platform
  labels:
    app: gok-cloud-api
spec:
  selector:
    app: gok-cloud-api
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30130
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $gok_cloud_yaml" "Installing GOK Cloud API"
    
    if [[ $? -eq 0 ]]; then
        log_success "GOK Cloud platform installed successfully"
        log_info "GOK Cloud API: http://<node-ip>:30130"
        log_info "Health endpoint: http://<node-ip>:30130/api/v1/health"
        complete_component "gok-cloud"
    else
        log_error "GOK Cloud platform installation failed"
        fail_component "gok-cloud" "Kubernetes deployment failed"
        return 1
    fi
}

# Install GOK Debug tools and utilities
gokDebugInst() {
    log_component_start "GOK Debug" "Installing debugging and troubleshooting tools"
    start_component "gok-debug"
    
    local namespace="gok-debug"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local debug_yaml="${GOK_CONFIG_DIR}/gok-debug.yaml"
    if [[ ! -f "$debug_yaml" ]]; then
        cat > "$debug_yaml" << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gok-debug-toolkit
  namespace: gok-debug
  labels:
    app: gok-debug-toolkit
spec:
  selector:
    matchLabels:
      app: gok-debug-toolkit
  template:
    metadata:
      labels:
        app: gok-debug-toolkit
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: debug-toolkit
        image: nicolaka/netshoot:latest
        command: ["/bin/bash"]
        args:
          - -c
          - |
            # Install additional debugging tools
            apk add --no-cache htop iotop stress-ng
            
            # Keep container running
            exec tail -f /dev/null
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-root
          mountPath: /host
          readOnly: true
        - name: docker-socket
          mountPath: /var/run/docker.sock
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
      tolerations:
      - operator: Exists
      volumes:
      - name: host-root
        hostPath:
          path: /
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-debug-web
  namespace: gok-debug
  labels:
    app: gok-debug-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gok-debug-web
  template:
    metadata:
      labels:
        app: gok-debug-web
    spec:
      containers:
      - name: debug-web
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: debug-scripts
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: debug-scripts
        configMap:
          name: gok-debug-scripts
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gok-debug-scripts
  namespace: gok-debug
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>GOK Debug Tools</title></head>
    <body>
    <h1>GOK Debug & Troubleshooting Tools</h1>
    <h2>Available Tools:</h2>
    <ul>
    <li><strong>Network Debug:</strong> kubectl exec -n gok-debug ds/gok-debug-toolkit -- nslookup kubernetes.default</li>
    <li><strong>DNS Test:</strong> kubectl exec -n gok-debug ds/gok-debug-toolkit -- dig @8.8.8.8 google.com</li>
    <li><strong>Network Connectivity:</strong> kubectl exec -n gok-debug ds/gok-debug-toolkit -- nc -zv <service-ip> <port></li>
    <li><strong>Container Inspection:</strong> kubectl exec -n gok-debug ds/gok-debug-toolkit -- docker ps</li>
    <li><strong>Process Monitor:</strong> kubectl exec -it -n gok-debug ds/gok-debug-toolkit -- htop</li>
    <li><strong>Network Traffic:</strong> kubectl exec -n gok-debug ds/gok-debug-toolkit -- tcpdump -i any</li>
    </ul>
    <h2>Troubleshooting Commands:</h2>
    <pre>
# Get debug pod on specific node
kubectl get pods -n gok-debug -o wide

# Execute debug session
kubectl exec -it -n gok-debug ds/gok-debug-toolkit -- bash

# Network debugging
kubectl exec -n gok-debug ds/gok-debug-toolkit -- netstat -tuln
kubectl exec -n gok-debug ds/gok-debug-toolkit -- ss -tuln

# DNS resolution
kubectl exec -n gok-debug ds/gok-debug-toolkit -- nslookup kubernetes.default.svc.cluster.local
    </pre>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: gok-debug-web
  namespace: gok-debug
  labels:
    app: gok-debug-web
spec:
  selector:
    app: gok-debug-web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30131
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $debug_yaml" "Installing GOK Debug toolkit"
    
    if [[ $? -eq 0 ]]; then
        log_success "GOK Debug toolkit installed successfully"
        log_info "Debug tools available on each node via DaemonSet"
        log_info "Debug web interface: http://<node-ip>:30131"
        log_info ""
        log_info "Quick debug access:"
        log_info "kubectl exec -it -n gok-debug ds/gok-debug-toolkit -- bash"
        complete_component "gok-debug"
    else
        log_error "GOK Debug toolkit installation failed"
        fail_component "gok-debug" "Kubernetes deployment failed"
        return 1
    fi
}

# Install GOK Login service (authentication gateway)
gokLoginInst() {
    log_component_start "GOK Login" "Installing authentication gateway service"
    start_component "gok-login"
    
    local namespace="gok-login"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local login_yaml="${GOK_CONFIG_DIR}/gok-login.yaml"
    if [[ ! -f "$login_yaml" ]]; then
        cat > "$login_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gok-login-service
  namespace: gok-login
  labels:
    app: gok-login-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gok-login-service
  template:
    metadata:
      labels:
        app: gok-login-service
    spec:
      containers:
      - name: login-service
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: login-config
          mountPath: /etc/nginx/conf.d
        - name: login-content
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 300m
            memory: 256Mi
      volumes:
      - name: login-config
        configMap:
          name: gok-login-config
      - name: login-content
        configMap:
          name: gok-login-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gok-login-config
  namespace: gok-login
data:
  default.conf: |
    server {
        listen 80;
        server_name gok-login;
        
        location /login {
            try_files $uri $uri/ /login.html;
        }
        
        location /auth {
            return 200 '{"authenticated": true, "user": "admin", "token": "sample-jwt-token"}';
            add_header Content-Type application/json;
        }
        
        location /logout {
            return 200 '{"message": "Logged out successfully"}';
            add_header Content-Type application/json;
        }
        
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gok-login-content
  namespace: gok-login
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>GOK Platform Login</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
            .container { max-width: 400px; margin: 50px auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .logo { text-align: center; margin-bottom: 30px; }
            .form-group { margin-bottom: 20px; }
            label { display: block; margin-bottom: 5px; font-weight: bold; }
            input[type="text"], input[type="password"] { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box; }
            .btn { width: 100%; padding: 12px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
            .btn:hover { background: #0056b3; }
            .links { text-align: center; margin-top: 20px; }
            .links a { color: #007bff; text-decoration: none; margin: 0 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="logo">
                <h1>🚀 GOK Platform</h1>
                <p>Kubernetes Operations Toolkit</p>
            </div>
            <form action="/auth" method="post">
                <div class="form-group">
                    <label for="username">Username:</label>
                    <input type="text" id="username" name="username" value="admin" required>
                </div>
                <div class="form-group">
                    <label for="password">Password:</label>
                    <input type="password" id="password" name="password" value="admin123" required>
                </div>
                <button type="submit" class="btn">Login</button>
            </form>
            <div class="links">
                <a href="http://localhost:30085">Dashboard</a> |
                <a href="http://localhost:30084">JupyterHub</a> |
                <a href="http://localhost:30090">ArgoCD</a>
            </div>
        </div>
    </body>
    </html>
  login.html: |
    <!DOCTYPE html>
    <html>
    <head><title>GOK Platform - Login</title></head>
    <body>
    <h1>Authentication Required</h1>
    <p>Please log in to access GOK Platform services.</p>
    <a href="/">Return to Login</a>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: gok-login-service
  namespace: gok-login
  labels:
    app: gok-login-service
spec:
  selector:
    app: gok-login-service
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30132
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $login_yaml" "Installing GOK Login service"
    
    if [[ $? -eq 0 ]]; then
        log_success "GOK Login service installed successfully"
        log_info "Login portal: http://<node-ip>:30132"
        log_info "Default credentials: admin / admin123"
        complete_component "gok-login"
    else
        log_error "GOK Login service installation failed"
        fail_component "gok-login" "Kubernetes deployment failed"
        return 1
    fi
}

# Install base infrastructure bundle
baseInst() {
    log_component_start "Base Infrastructure" "Installing base infrastructure stack"
    start_component "base"
    
    log_info "Installing base infrastructure components..."
    
    # Check if Docker is already installed
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        dockrInst || return 1
    else
        log_info "Docker already installed, skipping..."
    fi
    
    # Install Kubernetes if not already installed
    if ! command -v kubectl &> /dev/null; then
        log_info "Installing Kubernetes..."
        k8sInst || return 1
    else
        log_info "Kubernetes tools already installed, checking cluster..."
        if ! kubectl cluster-info &>/dev/null; then
            log_warning "Kubernetes cluster not accessible"
        fi
    fi
    
    # Install Helm
    log_info "Installing Helm..."
    helmInst || return 1
    
    # Install Ingress Controller
    log_info "Installing Ingress Controller..."
    ingressInst || return 1
    
    # Install Calico networking
    log_info "Installing Calico networking..."
    calicoInst || return 1
    
    log_success "Base infrastructure installed successfully"
    log_info "Base components installed:"
    log_info "  - Docker: Container runtime"
    log_info "  - Kubernetes: Container orchestration"
    log_info "  - Helm: Package manager"
    log_info "  - Ingress: HTTP(S) load balancer"
    log_info "  - Calico: Network plugin and policies"
    
    complete_component "base"
}

# Install base services bundle (essential platform services)
baseServicesInst() {
    log_component_start "Base Services" "Installing essential platform services"
    start_component "base-services"
    
    log_info "Installing base services..."
    
    # Install monitoring stack
    log_info "Installing monitoring..."
    monitoringInst || return 1
    
    # Install security components
    log_info "Installing security services..."
    certManagerInst || return 1
    vaultInst || return 1
    
    # Install registry services
    log_info "Installing registry services..."
    registryInst || return 1
    chartRegistryInst || return 1
    
    # Install development tools
    log_info "Installing development tools..."
    dashboardInst || return 1
    
    log_success "Base services installed successfully"
    log_info "Base services components:"
    log_info "  - Monitoring: Prometheus + Grafana"
    log_info "  - Security: Cert-Manager + Vault"
    log_info "  - Registry: Container + Chart repositories"
    log_info "  - Development: Kubernetes Dashboard"
    
    complete_component "base-services"
}

# Install everything (complete platform)
allInst() {
    log_component_start "Complete Platform" "Installing all GOK platform components"
    start_component "all"
    
    log_info "Installing complete GOK platform..."
    log_info "This will install all available components and may take 30-60 minutes"
    
    # Install base infrastructure
    baseInst || return 1
    
    # Install base services
    baseServicesInst || return 1
    
    # Install additional components
    log_info "Installing additional components..."
    
    # Development environment
    jupyterInst || return 1
    ttydInst || return 1
    
    # CI/CD pipeline
    jenkinsInst || return 1
    argocdInst || return 1
    
    # Storage services
    opensearchInst || return 1
    rabbitmqInst || return 1
    
    # Networking
    istioInst || return 1
    
    # Security
    keycloakInst || return 1
    ldapInst || return 1
    
    # GOK platform services
    gokCloudInst || return 1
    gokDebugInst || return 1
    gokLoginInst || return 1
    
    log_success "Complete GOK platform installed successfully!"
    log_info ""
    log_info "🎉 GOK Platform Installation Complete!"
    log_info ""
    log_info "📊 Monitoring & Observability:"
    log_info "  - Prometheus: Metrics collection"
    log_info "  - Grafana: Dashboards and visualization"
    log_info "  - Kiali: Service mesh observability"
    log_info ""
    log_info "🔒 Security & Authentication:"
    log_info "  - Cert-Manager: Certificate management"
    log_info "  - Vault: Secrets management"
    log_info "  - Keycloak: Identity and access management"
    log_info "  - LDAP: Directory services"
    log_info ""
    log_info "🚀 Development & CI/CD:"
    log_info "  - JupyterHub: Interactive development"
    log_info "  - Jenkins: Build automation"
    log_info "  - ArgoCD: GitOps delivery"
    log_info "  - TTYd: Terminal access"
    log_info ""
    log_info "📦 Storage & Registry:"
    log_info "  - Container Registry: Image storage"
    log_info "  - Helm Charts: Package repository"
    log_info "  - OpenSearch: Search and analytics"
    log_info "  - RabbitMQ: Message queue"
    log_info ""
    log_info "🌐 Networking & Service Mesh:"
    log_info "  - Istio: Service mesh"
    log_info "  - Ingress: Load balancing"
    log_info "  - Calico: Network policies"
    log_info ""
    log_info "🛠️ GOK Platform Services:"
    log_info "  - GOK Cloud: Platform API"
    log_info "  - GOK Debug: Troubleshooting tools"
    log_info "  - GOK Login: Authentication portal"
    log_info ""
    log_info "Access your platform at: http://<node-ip>:30132 (GOK Login Portal)"
    
    complete_component "all"
}