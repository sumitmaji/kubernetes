#!/bin/bash

# GOK Development Components Module - Jupyter, Console, TTYd, Eclipse Che, Cloud Shell

# Install JupyterHub development environment
jupyterInst() {
    log_component_start "JupyterHub" "Installing multi-user Jupyter development environment"
    start_component "jupyter"
    
    local namespace="jupyter"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add JupyterHub Helm repository
    helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/jupyter-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
hub:
  config:
    JupyterHub:
      authenticator_class: dummy
    DummyAuthenticator:
      password: jupyter123
  
  service:
    type: NodePort
    nodePort: 30084

proxy:
  secretToken: "a-very-secret-token-goes-here"
  
singleuser:
  image:
    name: jupyter/datascience-notebook
    tag: latest
  
  defaultUrl: "/lab"
  
  cpu:
    limit: 2
    guarantee: 0.5
  memory:
    limit: 2G
    guarantee: 512M
  
  storage:
    capacity: 10Gi
    homeMountPath: /home/jovyan
    dynamic:
      storageClass: local-path

ingress:
  enabled: false
  hosts:
    - jupyter.local

cull:
  enabled: true
  timeout: 3600
  every: 600
EOF
    fi
    
    helm_install_with_summary "jupyterhub" "jupyterhub/jupyterhub" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "JupyterHub installed successfully"
        log_info "Default password: jupyter123"
        log_info "Access JupyterHub at: http://<node-ip>:30084"
        complete_component "jupyter"
    else
        log_error "JupyterHub installation failed"
        fail_component "jupyter" "Helm installation failed"
        return 1
    fi
}

# Install JupyterHub (alias for jupyterInst)
jupyterhubInst() {
    jupyterInst
}

# Install Kubernetes Dashboard
dashboardInst() {
    log_component_start "Dashboard" "Installing Kubernetes Dashboard"
    start_component "dashboard"
    
    local namespace="kubernetes-dashboard"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add Kubernetes Dashboard Helm repository
    helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/dashboard-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
service:
  type: NodePort
  nodePort: 30085

protocolHttp: true

extraArgs:
  - --enable-skip-login
  - --disable-settings-authorizer

resources:
  requests:
    cpu: 100m
    memory: 200Mi
  limits:
    cpu: 500m
    memory: 500Mi

rbac:
  create: true
  clusterReadOnlyRole: true
EOF
    fi
    
    helm_install_with_summary "kubernetes-dashboard" "kubernetes-dashboard/kubernetes-dashboard" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        # Create admin service account
        local admin_yaml="${GOK_CONFIG_DIR}/dashboard-admin.yaml"
        if [[ ! -f "$admin_yaml" ]]; then
            cat > "$admin_yaml" << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $admin_yaml" "Creating dashboard admin user"
        
        log_success "Kubernetes Dashboard installed successfully"
        log_info "Access Dashboard at: http://<node-ip>:30085"
        log_info "Use 'Skip' option or get token with:"
        log_info "kubectl -n kubernetes-dashboard create token admin-user"
        complete_component "dashboard"
    else
        log_error "Kubernetes Dashboard installation failed"
        fail_component "dashboard" "Helm installation failed"
        return 1
    fi
}

# Install TTYd for terminal access
ttydInst() {
    log_component_start "TTYd" "Installing web-based terminal access"
    start_component "ttyd"
    
    local namespace="ttyd"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local ttyd_yaml="${GOK_CONFIG_DIR}/ttyd.yaml"
    if [[ ! -f "$ttyd_yaml" ]]; then
        cat > "$ttyd_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ttyd
  namespace: ttyd
  labels:
    app: ttyd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ttyd
  template:
    metadata:
      labels:
        app: ttyd
    spec:
      containers:
      - name: ttyd
        image: tsl0922/ttyd:latest
        args:
          - --port
          - "7681"
          - --credential
          - "admin:admin123"
          - bash
        ports:
        - containerPort: 7681
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: kubectl-config
          mountPath: /root/.kube
          readOnly: true
      volumes:
      - name: kubectl-config
        secret:
          secretName: kubectl-config
          optional: true
---
apiVersion: v1
kind: Service
metadata:
  name: ttyd
  namespace: ttyd
  labels:
    app: ttyd
spec:
  selector:
    app: ttyd
  ports:
  - port: 7681
    targetPort: 7681
    nodePort: 30086
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $ttyd_yaml" "Installing TTYd terminal"
    
    if [[ $? -eq 0 ]]; then
        log_success "TTYd installed successfully"
        log_info "Credentials: admin / admin123"
        log_info "Access terminal at: http://<node-ip>:30086"
        complete_component "ttyd"
    else
        log_error "TTYd installation failed"
        fail_component "ttyd" "Kubernetes deployment failed"
        return 1
    fi
}

# Install Eclipse Che IDE
eclipsecheInst() {
    log_component_start "Eclipse Che" "Installing cloud IDE"
    start_component "eclipseche"
    
    local namespace="eclipse-che"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add Eclipse Che Helm repository
    helm repo add eclipse-che https://eclipse.github.io/che-operator/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/eclipse-che-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
cheCluster:
  spec:
    server:
      cheHost: che.local
      chePort: 8080
      cheApiExternal: true
      cheDebug: false
      
    database:
      externalDb: false
      chePostgresHostName: ''
      chePostgresPort: ''
      chePostgresUser: ''
      chePostgresPassword: ''
      chePostgresDb: ''
      
    auth:
      openShiftoAuth: false
      identityProviderType: keycloak
      
    storage:
      pvcStrategy: per-workspace
      pvcClaimSize: 1Gi
      workspacePVCStorageClassName: local-path
      
    k8s:
      ingressDomain: local
      tlsSupport: false
      
    metrics:
      enable: true
EOF
    fi
    
    # Install Che Operator first
    execute_with_suppression \
        "kubectl apply -f https://github.com/eclipse/che-operator/releases/latest/download/che-operator-crds.yaml" \
        "Installing Che CRDs"
    
    helm_install_with_summary "che-operator" "eclipse-che/che-operator" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Eclipse Che installed successfully"
        log_info "Access Eclipse Che at: http://che.local (configure DNS or use port-forward)"
        complete_component "eclipseche"
    else
        log_error "Eclipse Che installation failed"
        fail_component "eclipseche" "Helm installation failed"
        return 1
    fi
}

# Install Cloud Shell environment
cloudshellInst() {
    log_component_start "Cloud Shell" "Installing cloud shell development environment"
    start_component "cloud-shell"
    
    local namespace="cloud-shell"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local cloudshell_yaml="${GOK_CONFIG_DIR}/cloud-shell.yaml"
    if [[ ! -f "$cloudshell_yaml" ]]; then
        cat > "$cloudshell_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloud-shell
  namespace: cloud-shell
  labels:
    app: cloud-shell
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloud-shell
  template:
    metadata:
      labels:
        app: cloud-shell
    spec:
      containers:
      - name: cloud-shell
        image: google/cloud-sdk:slim
        command: ["/bin/bash"]
        args:
          - -c
          - |
            apt-get update && apt-get install -y curl wget vim nano htop git
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl && mv kubectl /usr/local/bin/
            curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            chmod 700 get_helm.sh && ./get_helm.sh
            exec tail -f /dev/null
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: workspace
          mountPath: /workspace
        - name: kubeconfig
          mountPath: /root/.kube
          readOnly: true
        env:
        - name: SHELL
          value: "/bin/bash"
      volumes:
      - name: workspace
        emptyDir: {}
      - name: kubeconfig
        secret:
          secretName: kubeconfig
          optional: true
---
apiVersion: v1
kind: Service
metadata:
  name: cloud-shell
  namespace: cloud-shell
  labels:
    app: cloud-shell
spec:
  selector:
    app: cloud-shell
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30087
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $cloudshell_yaml" "Installing Cloud Shell environment"
    
    if [[ $? -eq 0 ]]; then
        log_success "Cloud Shell installed successfully"
        log_info "Connect with: kubectl exec -it -n cloud-shell deployment/cloud-shell -- /bin/bash"
        log_info "Or access via: http://<node-ip>:30087"
        complete_component "cloud-shell"
    else
        log_error "Cloud Shell installation failed"
        fail_component "cloud-shell" "Kubernetes deployment failed"
        return 1
    fi
}

# Install Console (web console)
consoleInst() {
    log_component_start "Console" "Installing web-based console"
    start_component "console"
    
    local namespace="console"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    local console_yaml="${GOK_CONFIG_DIR}/console.yaml"
    if [[ ! -f "$console_yaml" ]]; then
        cat > "$console_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-console
  namespace: console
  labels:
    app: web-console
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-console
  template:
    metadata:
      labels:
        app: web-console
    spec:
      containers:
      - name: wetty
        image: wettyoss/wetty:latest
        args:
          - --host
          - "0.0.0.0"
          - --port
          - "3000"
          - --base
          - "/"
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: REMOTE_SSH_SERVER
          value: "localhost"
        - name: REMOTE_SSH_PORT
          value: "22"
---
apiVersion: v1
kind: Service
metadata:
  name: web-console
  namespace: console
  labels:
    app: web-console
spec:
  selector:
    app: web-console
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30088
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $console_yaml" "Installing web console"
    
    if [[ $? -eq 0 ]]; then
        log_success "Web Console installed successfully"
        log_info "Access console at: http://<node-ip>:30088"
        complete_component "console"
    else
        log_error "Web Console installation failed"
        fail_component "console" "Kubernetes deployment failed"
        return 1
    fi
}

# Install development workspace (combination of tools)
devworkspaceInst() {
    log_component_start "Dev Workspace" "Installing development workspace bundle"
    start_component "devworkspace"
    
    log_info "Installing development workspace components..."
    
    # Install core development tools
    dashboardInst || return 1
    jupyterInst || return 1
    ttydInst || return 1
    consoleInst || return 1
    
    log_success "Development workspace installed successfully"
    log_info "Available development tools:"
    log_info "  - Kubernetes Dashboard: http://<node-ip>:30085"
    log_info "  - JupyterHub: http://<node-ip>:30084"
    log_info "  - Terminal (TTYd): http://<node-ip>:30086"
    log_info "  - Web Console: http://<node-ip>:30088"
    
    complete_component "devworkspace"
}

# Alias for devworkspaceInst
workspaceInst() {
    devworkspaceInst
}

# Alias for eclipsecheInst
cheInst() {
    eclipsecheInst
}