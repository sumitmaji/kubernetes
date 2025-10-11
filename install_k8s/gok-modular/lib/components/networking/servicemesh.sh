#!/bin/bash

# GOK Networking Components Module - Istio, Fluentd, and networking tools

# Install Istio service mesh
istioInst() {
    log_component_start "Istio" "Installing service mesh platform"
    start_component "istio"
    
    local namespace="istio-system"
    ensure_namespace "$namespace"
    
    # Add Istio Helm repository
    log_info "Adding Istio Helm repository"
    execute_with_suppression helm repo add istio https://istio-release.storage.googleapis.com/charts
    execute_with_suppression helm repo update
    
    # Install Istio base (CRDs and cluster-wide resources)
    local base_values="${GOK_CONFIG_DIR}/istio-base-values.yaml"
    if [[ ! -f "$base_values" ]]; then
        cat > "$base_values" << 'EOF'
# Istio base configuration
defaultRevision: ""
EOF
    fi
    
    helm_install_with_summary "istio-base" "istio/base" \
        "--namespace $namespace" \
        "--values $base_values" \
        "--wait --timeout=5m"
    
    if [[ $? -ne 0 ]]; then
        log_error "Istio base installation failed"
        fail_component "istio" "Istio base installation failed"
        return 1
    fi
    
    # Install Istiod (control plane)
    local istiod_values="${GOK_CONFIG_DIR}/istiod-values.yaml"
    if [[ ! -f "$istiod_values" ]]; then
        cat > "$istiod_values" << 'EOF'
global:
  meshID: mesh1
  multiCluster:
    clusterName: cluster1
  network: network1

pilot:
  resources:
    requests:
      cpu: 500m
      memory: 2048Mi
    limits:
      cpu: 1000m
      memory: 4096Mi

telemetry:
  v2:
    enabled: true

meshConfig:
  defaultConfig:
    holdApplicationUntilProxyStarts: true
    proxyStatsMatcher:
      inclusionRegexps:
      - ".*_cx_.*"
EOF
    fi
    
    helm_install_with_summary "istiod" "istio/istiod" \
        "--namespace $namespace" \
        "--values $istiod_values" \
        "--wait --timeout=10m"
    
    if [[ $? -ne 0 ]]; then
        log_error "Istiod installation failed"
        fail_component "istio" "Istiod installation failed"
        return 1
    fi
    
    # Install Istio Gateway
    local gateway_namespace="istio-ingress"
    ensure_namespace "$gateway_namespace"
    kubectl label namespace "$gateway_namespace" istio-injection=enabled --overwrite
    
    local gateway_values="${GOK_CONFIG_DIR}/istio-gateway-values.yaml"
    if [[ ! -f "$gateway_values" ]]; then
        cat > "$gateway_values" << 'EOF'
service:
  type: NodePort
  ports:
    - port: 15021
      targetPort: 15021
      nodePort: 30110
      name: status-port
    - port: 80
      targetPort: 8080
      nodePort: 30111
      name: http2
    - port: 443
      targetPort: 8443
      nodePort: 30112
      name: https

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 2000m
    memory: 1024Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
EOF
    fi
    
    helm_install_with_summary "istio-ingress" "istio/gateway" \
        "--namespace $gateway_namespace" \
        "--values $gateway_values" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        # Install Kiali for observability
        local kiali_yaml="${GOK_CONFIG_DIR}/kiali.yaml"
        if [[ ! -f "$kiali_yaml" ]]; then
            cat > "$kiali_yaml" << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kiali
  namespace: istio-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kiali
rules:
- apiGroups: [""]
  resources: ["configmaps", "endpoints", "pods", "services", "nodes", "replicationcontrollers", "namespaces", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["config.istio.io", "security.istio.io", "networking.istio.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kiali
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kiali
subjects:
- kind: ServiceAccount
  name: kiali
  namespace: istio-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiali
  namespace: istio-system
data:
  config.yaml: |
    server:
      port: 20001
      web_root: /kiali
    external_services:
      prometheus:
        url: "http://prometheus-server.monitoring.svc.cluster.local:80"
      grafana:
        enabled: true
        in_cluster_url: 'http://grafana.monitoring.svc.cluster.local:80'
        url: 'http://grafana.local'
      tracing:
        enabled: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kiali
  namespace: istio-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kiali
  template:
    metadata:
      labels:
        app: kiali
    spec:
      serviceAccountName: kiali
      containers:
      - name: kiali
        image: quay.io/kiali/kiali:v1.73
        command:
        - "/opt/kiali/kiali"
        - "-config"
        - "/kiali-configuration/config.yaml"
        ports:
        - containerPort: 20001
        volumeMounts:
        - name: kiali-configuration
          mountPath: "/kiali-configuration"
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 1Gi
      volumes:
      - name: kiali-configuration
        configMap:
          name: kiali
---
apiVersion: v1
kind: Service
metadata:
  name: kiali
  namespace: istio-system
spec:
  selector:
    app: kiali
  ports:
  - port: 20001
    targetPort: 20001
    nodePort: 30113
  type: NodePort
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $kiali_yaml" "Installing Kiali observability"
        
        log_success "Istio service mesh installed successfully"
        log_info "Components installed:"
        log_info "  - Istio Base: Core CRDs and cluster resources"
        log_info "  - Istiod: Control plane"
        log_info "  - Istio Gateway: Ingress gateway"
        log_info "  - Kiali: Service mesh observability"
        log_info ""
        log_info "Access points:"
        log_info "  - HTTP Gateway: <node-ip>:30111"
        log_info "  - HTTPS Gateway: <node-ip>:30112"
        log_info "  - Kiali Dashboard: http://<node-ip>:30113"
        log_info ""
        log_info "Enable injection for namespace: kubectl label namespace <ns> istio-injection=enabled"
        complete_component "istio"
    else
        log_error "Istio gateway installation failed"
        fail_component "istio" "Istio gateway installation failed"
        return 1
    fi
}

# Install Fluentd for log collection
fluentdInst() {
    log_component_start "Fluentd" "Installing log collection and forwarding system"
    start_component "fluentd"
    
    local namespace="logging"
    ensure_namespace "$namespace"
    
    # Add Fluent Helm repository
    log_info "Adding Fluent Helm repository"
    execute_with_suppression helm repo add fluent https://fluent.github.io/helm-charts
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/fluentd-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
image:
  repository: fluent/fluentd-kubernetes-daemonset
  tag: v1.16-debian-elasticsearch7-1

resources:
  requests:
    cpu: 100m
    memory: 200Mi
  limits:
    cpu: 500m
    memory: 500Mi

tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

env:
  - name: FLUENT_ELASTICSEARCH_HOST
    value: "opensearch-cluster-master.opensearch.svc.cluster.local"
  - name: FLUENT_ELASTICSEARCH_PORT
    value: "9200"
  - name: FLUENT_ELASTICSEARCH_SCHEME
    value: "http"
  - name: FLUENTD_SYSTEMD_CONF
    value: disable
  - name: FLUENT_CONTAINER_TAIL_EXCLUDE_PATH
    value: /var/log/containers/fluent*

fileConfigs:
  04_outputs.conf: |-
    <match **>
      @type elasticsearch
      @id out_es
      @log_level info
      include_tag_key true
      host "#{ENV['FLUENT_ELASTICSEARCH_HOST']}"
      port "#{ENV['FLUENT_ELASTICSEARCH_PORT']}"
      path ""
      scheme "#{ENV['FLUENT_ELASTICSEARCH_SCHEME'] || 'http'}"
      ssl_verify "#{ENV['FLUENT_ELASTICSEARCH_SSL_VERIFY'] || 'true'}"
      ssl_version "#{ENV['FLUENT_ELASTICSEARCH_SSL_VERSION'] || 'TLSv1_2'}"
      reload_connections false
      reconnect_on_error true
      reload_on_failure true
      log_es_400_reason false
      logstash_prefix fluentd
      logstash_dateformat %Y.%m.%d
      logstash_format true
      index_name fluentd
      target_index_key
      type_name fluentd
      include_timestamp false
      template_name
      template_file
      template_overwrite false
      sniffer_class_name "Fluent::Plugin::ElasticsearchSimpleSniffer"
      request_timeout 5s
      application_name default
      suppress_type_name true
      enable_ilm false
      ilm_policy_id logstash-policy
      ilm_policy
      ilm_policy_overwrite false
      <buffer>
        flush_thread_count 8
        flush_interval 5s
        chunk_limit_size 2M
        queue_limit_length 32
        retry_max_interval 30
        retry_forever true
      </buffer>
    </match>
EOF
    fi
    
    helm_install_with_summary "fluentd" "fluent/fluentd" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Fluentd installed successfully"
        log_info "Log collection configured to send to OpenSearch"
        log_info "Fluentd will collect logs from all pods and nodes"
        complete_component "fluentd"
    else
        log_error "Fluentd installation failed"
        fail_component "fluentd" "Helm installation failed"
        return 1
    fi
}

# Install Calico network plugin (moved from infrastructure for logical grouping)
calicoNetworkInst() {
    log_component_start "Calico Network" "Installing Calico network plugin and policies"
    start_component "calico-network"
    
    # Download and apply Calico manifest
    local calico_yaml="${GOK_CONFIG_DIR}/calico.yaml"
    
    if [[ ! -f "$calico_yaml" ]]; then
        log_info "Downloading Calico manifest..."
        execute_with_suppression \
            "curl -sL https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml -o ${GOK_CONFIG_DIR}/tigera-operator.yaml" \
            "Downloading Tigera operator"
        
        execute_with_suppression \
            "curl -sL https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml -o $calico_yaml" \
            "Downloading Calico custom resources"
    fi
    
    # Install Tigera operator
    execute_with_suppression "kubectl create -f ${GOK_CONFIG_DIR}/tigera-operator.yaml" "Installing Tigera operator"
    
    # Modify Calico configuration for local environment
    if [[ -f "$calico_yaml" ]]; then
        sed -i 's|cidr: 192\.168\.0\.0/16|cidr: 10.244.0.0/16|g' "$calico_yaml"
    fi
    
    # Apply Calico configuration
    execute_with_suppression "kubectl create -f $calico_yaml" "Installing Calico network"
    
    # Wait for Calico to be ready
    log_info "Waiting for Calico installation to complete..."
    kubectl wait --for=condition=available --timeout=300s deployment/calico-kube-controllers -n calico-system
    
    if [[ $? -eq 0 ]]; then
        log_success "Calico network installed successfully"
        log_info "Network policy enforcement enabled"
        complete_component "calico-network"
    else
        log_error "Calico network installation failed"
        fail_component "calico-network" "Installation timeout or failure"
        return 1
    fi
}

# Install network policies for security
networkPoliciesInst() {
    log_component_start "Network Policies" "Installing default network security policies"
    start_component "network-policies"
    
    local policies_yaml="${GOK_CONFIG_DIR}/network-policies.yaml"
    if [[ ! -f "$policies_yaml" ]]; then
        cat > "$policies_yaml" << 'EOF'
# Default deny all ingress traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
# Allow DNS traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
---
# Allow system namespace traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-system-namespaces
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-public
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $policies_yaml" "Installing default network policies"
    
    if [[ $? -eq 0 ]]; then
        log_success "Network policies installed successfully"
        log_info "Default security policies applied to default namespace"
        log_info "Customize policies as needed for your applications"
        complete_component "network-policies"
    else
        log_error "Network policies installation failed"
        fail_component "network-policies" "Kubernetes apply failed"
        return 1
    fi
}

# Install MetalLB load balancer for bare metal
metallbInst() {
    log_component_start "MetalLB" "Installing load balancer for bare metal clusters"
    start_component "metallb"
    
    local namespace="metallb-system"
    ensure_namespace "$namespace"
    
    # Add MetalLB Helm repository
    log_info "Adding MetalLB Helm repository"
    execute_with_suppression helm repo add metallb https://metallb.github.io/metallb
    execute_with_suppression helm repo update
    
    helm_install_with_summary "metallb" "metallb/metallb" \
        "--namespace $namespace" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        # Configure MetalLB IP address pool
        local metallb_config="${GOK_CONFIG_DIR}/metallb-config.yaml"
        if [[ ! -f "$metallb_config" ]]; then
            cat > "$metallb_config" << 'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.250  # Update this range for your network
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF
        fi
        
        log_info "Waiting for MetalLB controller to be ready..."
        kubectl wait --namespace metallb-system \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=90s
        
        execute_with_suppression "kubectl apply -f $metallb_config" "Configuring MetalLB address pool"
        
        log_success "MetalLB installed successfully"
        log_info "Default IP pool: 192.168.1.200-192.168.1.250"
        log_info "Update the IP range in $metallb_config for your network"
        complete_component "metallb"
    else
        log_error "MetalLB installation failed"
        fail_component "metallb" "Helm installation failed"
        return 1
    fi
}