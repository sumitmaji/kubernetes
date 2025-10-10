#!/bin/bash

# GOK CI/CD Components Module - ArgoCD, Jenkins, Spinnaker

# Install ArgoCD for GitOps continuous delivery
argocdInst() {
    log_component_start "ArgoCD" "Installing GitOps continuous delivery platform"
    start_component "argocd"
    
    local namespace="argocd"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add ArgoCD Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/argocd-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
server:
  service:
    type: NodePort
    nodePortHttp: 30090
    nodePortHttps: 30091
  
  config:
    url: "https://argocd.local"
    
  # Disable TLS for simplicity (enable in production)
  insecure: true
  
  extraArgs:
    - --insecure

dex:
  enabled: false

redis-ha:
  enabled: false

redis:
  enabled: true

controller:
  replicas: 1

repoServer:
  replicas: 1

applicationSet:
  enabled: true

notifications:
  enabled: true

configs:
  secret:
    # Default password is 'admin'
    argocdServerAdminPassword: "$2a$10$rRyBsGSHK6.uc8fntPwVIuLiMsqLmvAS7QLMGelE7AQxBKAj8Zl2O"
  
  repositories: |
    - type: git
      url: https://github.com/argoproj/argocd-example-apps.git
    - type: helm
      name: stable
      url: https://charts.helm.sh/stable
      
  params:
    server.insecure: true
EOF
    fi
    
    helm_install_with_summary "argocd" "argo/argo-cd" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "ArgoCD installed successfully"
        log_success "ArgoCD installed successfully"
        complete_component "argocd"
        
        # Show comprehensive installation summary
        show_component_summary "argocd" "$namespace"
    else
        log_error "ArgoCD installation failed"
        fail_component "argocd" "Helm installation failed"
        return 1
    fi
}

# Install Jenkins CI/CD automation
jenkinsInst() {
    log_component_start "Jenkins" "Installing CI/CD automation server"
    start_component "jenkins"
    
    local namespace="jenkins"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add Jenkins Helm repository
    helm repo add jenkinsci https://charts.jenkins.io
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/jenkins-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
controller:
  adminUser: "admin"
  adminPassword: "admin123"
  
  serviceType: NodePort
  nodePort: 30092
  
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
  
  installPlugins:
    - kubernetes:latest
    - workflow-job:latest
    - workflow-aggregator:latest
    - credentials-binding:latest
    - git:latest
    - github:latest
    - docker-workflow:latest
    - pipeline-stage-view:latest
    - blueocean:latest
  
  JCasC:
    defaultConfig: true
    configScripts:
      welcome-message: |
        jenkins:
          systemMessage: Welcome to Jenkins on Kubernetes!
        
        unclassified:
          location:
            url: http://jenkins.local:30092

agent:
  enabled: true
  
persistence:
  enabled: true
  storageClass: local-path
  size: 20Gi

rbac:
  create: true

serviceAccount:
  create: true
EOF
    fi
    
    helm_install_with_summary "jenkins" "jenkinsci/jenkins" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        # Create additional RBAC for Jenkins agents
        local rbac_yaml="${GOK_CONFIG_DIR}/jenkins-rbac.yaml"
        if [[ ! -f "$rbac_yaml" ]]; then
            cat > "$rbac_yaml" << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-agent
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-agent
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $rbac_yaml" "Configuring Jenkins RBAC"
        
        log_success "Jenkins installed successfully"
        log_info "Credentials: admin / admin123"
        log_info "Access Jenkins at: http://<node-ip>:30092"
        complete_component "jenkins"
    else
        log_error "Jenkins installation failed"
        fail_component "jenkins" "Helm installation failed"
        return 1
    fi
}

# Install Spinnaker multi-cloud deployment platform
spinnakerInst() {
    log_component_start "Spinnaker" "Installing multi-cloud deployment platform"
    start_component "spinnaker"
    
    local namespace="spinnaker"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add Spinnaker Helm repository
    helm repo add spinnaker https://opsmx.github.io/spinnaker-helm/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/spinnaker-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
halyard:
  spinnakerVersion: 1.30.0
  image:
    repository: us-docker.pkg.dev/spinnaker-community/docker/halyard
    tag: 1.47.0
  
  additionalScripts:
    create: true
    data:
      enable_gcs_artifacts.sh: |-
        echo "Spinnaker configuration scripts can be added here"

spinnakerFeatureFlags:
  - artifacts
  - pipeline-templates
  - managed-pipeline-templates-v2-ui

minio:
  enabled: true
  defaultBucket:
    enabled: true
    name: spinnaker
  accessKey: "spinnaker"
  secretKey: "spinnaker123"
  
redis:
  enabled: true
  
ingress:
  enabled: false

spinnakerConfig:
  config:
    version: 1.30.0
    persistentStorage:
      persistentStoreType: s3
      s3:
        bucket: spinnaker
        rootFolder: front50
        endpoint: http://spinnaker-minio:9000
        accessKeyId: spinnaker
        secretAccessKey: spinnaker123

  service-settings:
    deck:
      env:
        API_HOST: http://spin-gate.spinnaker.svc.cluster.local:8084
    gate:
      env:
        server.servlet.context-path: /api/v1

  profiles:
    clouddriver:
      kubernetes:
        enabled: true
        accounts:
          - name: spinnaker-account
            requiredGroupMembership: []
            providerVersion: V2
            permissions: {}
            dockerRegistries: []
            configureImagePullSecrets: true
            cacheThreads: 1
            namespaces: ["default", "spinnaker"]
            omitNamespaces: []
            kinds: []
            omitKinds: []
            customResources: []
            cachingPolicies: []
            kubeconfigFile: /home/spinnaker/.kube/config

nodeSelector:
  kubernetes.io/os: linux
EOF
    fi
    
    helm_install_with_summary "spinnaker" "spinnaker/spinnaker" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=15m"
    
    if [[ $? -eq 0 ]]; then
        # Expose Spinnaker UI
        local service_yaml="${GOK_CONFIG_DIR}/spinnaker-services.yaml"
        if [[ ! -f "$service_yaml" ]]; then
            cat > "$service_yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: spin-deck-np
  namespace: spinnaker
spec:
  type: NodePort
  selector:
    app: spin
    cluster: spin-deck
  ports:
  - port: 9000
    targetPort: 9000
    nodePort: 30093
---
apiVersion: v1
kind: Service
metadata:
  name: spin-gate-np
  namespace: spinnaker
spec:
  type: NodePort
  selector:
    app: spin
    cluster: spin-gate
  ports:
  - port: 8084
    targetPort: 8084
    nodePort: 30094
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $service_yaml" "Exposing Spinnaker services"
        
        log_success "Spinnaker installed successfully"
        log_info "Access Spinnaker UI at: http://<node-ip>:30093"
        log_info "Spinnaker API at: http://<node-ip>:30094"
        log_info "Default storage credentials: spinnaker / spinnaker123"
        complete_component "spinnaker"
    else
        log_error "Spinnaker installation failed"
        fail_component "spinnaker" "Helm installation failed"
        return 1
    fi
}

# Install CI/CD pipeline tools bundle
cicdInst() {
    log_component_start "CI/CD Bundle" "Installing complete CI/CD pipeline stack"
    start_component "cicd"
    
    log_info "Installing CI/CD pipeline components..."
    
    # Install components in order
    jenkinsInst || return 1
    argocdInst || return 1
    
    log_success "CI/CD pipeline stack installed successfully"
    log_info "Components installed:"
    log_info "  - Jenkins: CI/CD automation and build pipelines"
    log_info "  - ArgoCD: GitOps continuous delivery"
    log_info ""
    log_info "Access points:"
    log_info "  - Jenkins: http://<node-ip>:30092 (admin/admin123)"
    log_info "  - ArgoCD: http://<node-ip>:30090 (admin/admin)"
    
    complete_component "cicd"
}

# Install GitLab CI (alternative CI/CD solution)
gitlabInst() {
    log_component_start "GitLab" "Installing GitLab CI/CD platform"
    start_component "gitlab"
    
    local namespace="gitlab"
    kubectl create namespace "$namespace" 2>/dev/null || true
    
    # Add GitLab Helm repository
    helm repo add gitlab https://charts.gitlab.io/
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/gitlab-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
global:
  hosts:
    domain: local
    externalIP: 192.168.1.100  # Update with your node IP
  
  ingress:
    configureCertmanager: false
    class: nginx
  
  edition: ce

gitlab:
  webservice:
    service:
      type: NodePort
      nodePort: 30095

gitlab-runner:
  runners:
    privileged: true
    tags: "kubernetes,docker"

registry:
  enabled: true

postgresql:
  install: true

redis:
  install: true

nginx-ingress:
  enabled: false

cert-manager:
  install: false
EOF
    fi
    
    log_info "Installing GitLab (this may take 10-15 minutes)..."
    
    helm_install_with_summary "gitlab" "gitlab/gitlab" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=20m"
    
    if [[ $? -eq 0 ]]; then
        log_success "GitLab installed successfully"
        log_info "Access GitLab at: http://<node-ip>:30095"
        log_info "Get root password with:"
        log_info "kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d"
        complete_component "gitlab"
    else
        log_error "GitLab installation failed"
        fail_component "gitlab" "Helm installation failed"
        return 1
    fi
}