#!/bin/bash

# GOK Storage Components Module - OpenSearch, RabbitMQ, and other storage solutions

# Install OpenSearch for search and analytics
opensearchInst() {
    log_component_start "OpenSearch" "Installing OpenSearch search and analytics engine"
    start_component "opensearch"
    
    local namespace="opensearch"
    ensure_namespace "$namespace"
    
    # Add OpenSearch Helm repository
    log_info "Adding OpenSearch Helm repository"
    execute_with_suppression helm repo add opensearch https://opensearch-project.github.io/helm-charts/
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/opensearch-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
clusterName: "opensearch-cluster"

nodeGroup: "master"

masterService: "opensearch-cluster-master"

roles:
  - master
  - ingest
  - data
  - remote_cluster_client

replicas: 3

minimumMasterNodes: 2

config:
  opensearch.yml: |
    cluster.name: opensearch-cluster
    network.host: 0.0.0.0
    plugins:
      security:
        disabled: true
    discovery.seed_hosts: opensearch-cluster-master-headless
    cluster.initial_master_nodes: opensearch-cluster-master-0,opensearch-cluster-master-1,opensearch-cluster-master-2

persistence:
  enabled: true
  storageClass: "local-path"
  accessModes:
    - ReadWriteOnce
  size: 8Gi

resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "2000m"
    memory: "2Gi"

service:
  type: NodePort
  nodePort: 30096
  
extraEnvs:
  - name: DISABLE_INSTALL_DEMO_CONFIG
    value: "true"
  - name: DISABLE_SECURITY_PLUGIN
    value: "true"

sysctl:
  enabled: true

sysctlVmMaxMapCount: 262144
EOF
    fi
    
    helm_install_with_summary "opensearch" "opensearch/opensearch" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        # Install OpenSearch Dashboards
        local dashboard_values="${GOK_CONFIG_DIR}/opensearch-dashboards-values.yaml"
        if [[ ! -f "$dashboard_values" ]]; then
            cat > "$dashboard_values" << 'EOF'
opensearchHosts: "http://opensearch-cluster-master:9200"

service:
  type: NodePort
  nodePort: 30097

config:
  opensearch_dashboards.yml: |
    server.name: opensearch-dashboards
    server.host: 0.0.0.0
    opensearch.hosts: [http://opensearch-cluster-master:9200]
    opensearch.ssl.verificationMode: none
    opensearch.security.multitenancy.enabled: false
    opensearch.security.readonly_mode.roles: []

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"
EOF
        fi
        
        helm_install_with_summary "opensearch-dashboards" "opensearch/opensearch-dashboards" \
            "--namespace $namespace" \
            "--values $dashboard_values" \
            "--wait --timeout=5m"
        
        log_success "OpenSearch installed successfully"
        log_info "OpenSearch API: http://<node-ip>:30096"
        log_info "OpenSearch Dashboards: http://<node-ip>:30097"
        complete_component "opensearch"
    else
        log_error "OpenSearch installation failed"
        fail_component "opensearch" "Helm installation failed"
        return 1
    fi
}

# Install RabbitMQ message broker
rabbitmqInst() {
    log_component_start "RabbitMQ" "Installing message broker and queue system"
    start_component "rabbitmq"
    
    local namespace="rabbitmq"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/rabbitmq-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
auth:
  username: admin
  password: admin123

clustering:
  enabled: true
  replicaCount: 3

persistence:
  enabled: true
  storageClass: "local-path"
  size: 8Gi

service:
  type: NodePort
  nodePorts:
    amqp: 30098
    manager: 30099

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: false

extraConfiguration: |-
  load_definitions = /app/load_definition.json

loadDefinition:
  enabled: true
  existingSecret: ""

extraSecrets:
  load-definition:
    load_definition.json: |
      {
        "users": [
          {
            "name": "admin",
            "password": "admin123",
            "tags": "administrator"
          }
        ],
        "vhosts": [
          {
            "name": "/"
          }
        ],
        "permissions": [
          {
            "user": "admin",
            "vhost": "/",
            "configure": ".*",
            "write": ".*",
            "read": ".*"
          }
        ],
        "exchanges": [],
        "queues": [],
        "bindings": []
      }
EOF
    fi
    
    helm_install_with_summary "rabbitmq" "bitnami/rabbitmq" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "RabbitMQ installed successfully"
        log_info "Credentials: admin / admin123"
        log_info "AMQP Port: <node-ip>:30098"
        log_info "Management UI: http://<node-ip>:30099"
        complete_component "rabbitmq"
    else
        log_error "RabbitMQ installation failed"
        fail_component "rabbitmq" "Helm installation failed"
        return 1
    fi
}

# Install Apache Kafka message streaming
kafkaInst() {
    log_component_start "Kafka" "Installing Apache Kafka message streaming platform"
    start_component "kafka"
    
    local namespace="kafka"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository (if not already added)
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/kafka-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
replicaCount: 3

persistence:
  enabled: true
  storageClass: "local-path"
  size: 8Gi

zookeeper:
  enabled: true
  replicaCount: 3
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 8Gi

externalAccess:
  enabled: true
  service:
    type: NodePort
    nodePorts:
      - 30100
      - 30101
      - 30102

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

metrics:
  kafka:
    enabled: true
  jmx:
    enabled: true

livenessProbe:
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  initialDelaySeconds: 30
  periodSeconds: 30
EOF
    fi
    
    helm_install_with_summary "kafka" "bitnami/kafka" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Apache Kafka installed successfully"
        log_info "Kafka brokers accessible at:"
        log_info "  - <node-ip>:30100"
        log_info "  - <node-ip>:30101"
        log_info "  - <node-ip>:30102"
        complete_component "kafka"
    else
        log_error "Apache Kafka installation failed"
        fail_component "kafka" "Helm installation failed"
        return 1
    fi
}

# Install PostgreSQL database
postgresqlInst() {
    log_component_start "PostgreSQL" "Installing PostgreSQL database"
    start_component "postgresql"
    
    local namespace="postgresql"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository (if not already added)
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/postgresql-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
auth:
  postgresPassword: postgres123
  username: gokuser
  password: gokuser123
  database: gokdb

architecture: replication
replication:
  enabled: true
  readReplicas: 2

primary:
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 20Gi
  
  service:
    type: NodePort
    nodePorts:
      postgresql: 30103

readReplicas:
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 20Gi

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: false

backup:
  enabled: false
EOF
    fi
    
    helm_install_with_summary "postgresql" "bitnami/postgresql" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "PostgreSQL installed successfully"
        log_info "Database connection:"
        log_info "  Host: <node-ip>:30103"
        log_info "  Database: gokdb"
        log_info "  Username: gokuser"
        log_info "  Password: gokuser123"
        log_info "  Admin Password: postgres123"
        complete_component "postgresql"
    else
        log_error "PostgreSQL installation failed"
        fail_component "postgresql" "Helm installation failed"
        return 1
    fi
}

# Install MySQL database
mysqlInst() {
    log_component_start "MySQL" "Installing MySQL database"
    start_component "mysql"
    
    local namespace="mysql"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository (if not already added)
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/mysql-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
auth:
  rootPassword: root123
  username: gokuser
  password: gokuser123
  database: gokdb

architecture: replication

primary:
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 20Gi
  
  service:
    type: NodePort
    nodePorts:
      mysql: 30104

secondary:
  replicaCount: 2
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 20Gi

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: false
EOF
    fi
    
    helm_install_with_summary "mysql" "bitnami/mysql" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "MySQL installed successfully"
        log_info "Database connection:"
        log_info "  Host: <node-ip>:30104"
        log_info "  Database: gokdb"
        log_info "  Username: gokuser"
        log_info "  Password: gokuser123"
        log_info "  Root Password: root123"
        complete_component "mysql"
    else
        log_error "MySQL installation failed"
        fail_component "mysql" "Helm installation failed"
        return 1
    fi
}

# Install Redis cache
redisInst() {
    log_component_start "Redis" "Installing Redis cache and data store"
    start_component "redis"
    
    local namespace="redis"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository (if not already added)
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/redis-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
auth:
  enabled: true
  password: "redis123"

architecture: replication

master:
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 8Gi
  
  service:
    type: NodePort
    nodePorts:
      redis: 30105

replica:
  replicaCount: 2
  persistence:
    enabled: true
    storageClass: "local-path"
    size: 8Gi

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: false
EOF
    fi
    
    helm_install_with_summary "redis" "bitnami/redis" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Redis installed successfully"
        log_info "Redis connection:"
        log_info "  Host: <node-ip>:30105"
        log_info "  Password: redis123"
        complete_component "redis"
    else
        log_error "Redis installation failed"
        fail_component "redis" "Helm installation failed"
        return 1
    fi
}