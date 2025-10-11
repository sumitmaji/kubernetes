#!/bin/bash

# GOK Security Components Module - Cert-Manager, Keycloak, OAuth2, Vault, LDAP, Kerberos

# Install Cert-Manager for certificate management
certManagerInst() {
    log_component_start "Cert-Manager" "Installing certificate management system"
    start_component "cert-manager"
    
    local namespace="cert-manager"
    
    # Create namespace
    ensure_namespace "$namespace"
    
    # Add Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    
    # Install cert-manager CRDs
    execute_with_suppression \
        "kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml" \
        "Installing cert-manager CRDs"
    
    # Install cert-manager
    helm_install_with_summary "cert-manager" "jetstack/cert-manager" \
        "--namespace $namespace" \
        "--version v1.13.0" \
        "--set installCRDs=false" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        # Create ClusterIssuer for Let's Encrypt
        local issuer_yaml="${GOK_CONFIG_DIR}/cluster-issuer.yaml"
        if [[ ! -f "$issuer_yaml" ]]; then
            cat > "$issuer_yaml" << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Change this to your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Change this to your email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
        fi
        
        execute_with_suppression "kubectl apply -f $issuer_yaml" "Creating ClusterIssuers"
        
        log_success "Cert-Manager installed successfully"
        complete_component "cert-manager"
        
        # Show comprehensive installation summary
        show_component_summary "cert-manager" "$namespace"
    else
        log_error "Cert-Manager installation failed"
        fail_component "cert-manager" "Helm installation failed"
        return 1
    fi
}

# Install Keycloak identity and access management
keycloakInst() {
    log_component_start "Keycloak" "Installing identity and access management"
    start_component "keycloak"
    
    local namespace="keycloak"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/keycloak-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
auth:
  adminUser: admin
  adminPassword: admin123

postgresql:
  auth:
    postgresPassword: postgres123
    password: keycloak123
  persistence:
    enabled: true
    size: 8Gi

service:
  type: NodePort
  nodePorts:
    http: 30080

ingress:
  enabled: false  # Enable if you have ingress controller
  hostname: keycloak.local

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 2Gi

extraEnvVars:
  - name: KEYCLOAK_PRODUCTION
    value: "false"
  - name: KEYCLOAK_PROXY
    value: "edge"
EOF
    fi
    
    helm_install_with_summary "keycloak" "bitnami/keycloak" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Keycloak installed successfully"
        complete_component "keycloak"
        
        # Show comprehensive installation summary
        show_component_summary "keycloak" "$namespace"
    else
        log_error "Keycloak installation failed"
        fail_component "keycloak" "Helm installation failed"
        return 1
    fi
}

# Install OAuth2 Proxy
oauth2ProxyInst() {
    log_component_start "OAuth2 Proxy" "Installing OAuth2 authentication proxy"
    start_component "oauth2-proxy"
    
    local namespace="oauth2-proxy"
    ensure_namespace "$namespace"
    
    # Add OAuth2 Proxy Helm repository
    helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/oauth2-proxy-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
config:
  clientID: "oauth2-proxy"
  clientSecret: "oauth2-proxy-secret"
  cookieSecret: "OQINaROshtE9TcZkNAm-5Zs2Pv3xaWytBmc5W7sPX7w="
  
  configFile: |-
    provider = "keycloak"
    oidc_issuer_url = "http://keycloak.keycloak.svc.cluster.local:8080/realms/master"
    redirect_url = "http://oauth2-proxy.local/oauth2/callback"
    upstreams = [ "http://kubernetes-dashboard.kubernetes-dashboard.svc.cluster.local:80" ]
    email_domains = [ "*" ]
    cookie_domains = [ ".local" ]
    whitelist_domains = [ ".local" ]

service:
  type: NodePort
  nodePort: 30081

ingress:
  enabled: false
  hosts:
    - oauth2-proxy.local

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
EOF
    fi
    
    helm_install_with_summary "oauth2-proxy" "oauth2-proxy/oauth2-proxy" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=5m"
    
    if [[ $? -eq 0 ]]; then
        log_success "OAuth2 Proxy installed successfully"
        log_info "Access OAuth2 Proxy at: http://<node-ip>:30081"
        complete_component "oauth2-proxy"
    else
        log_error "OAuth2 Proxy installation failed"
        fail_component "oauth2-proxy" "Helm installation failed"
        return 1
    fi
}

# Install HashiCorp Vault
vaultInst() {
    log_component_start "Vault" "Installing HashiCorp Vault secrets management"
    start_component "vault"
    
    local namespace="vault"
    ensure_namespace "$namespace"
    
    # Add HashiCorp Helm repository
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    local values_file="${GOK_CONFIG_DIR}/vault-values.yaml"
    if [[ ! -f "$values_file" ]]; then
        cat > "$values_file" << 'EOF'
server:
  dev:
    enabled: false
  
  ha:
    enabled: true
    replicas: 3
  
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: local-path
  
  service:
    type: NodePort
    nodePort: 30082
  
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 1000m

ui:
  enabled: true
  serviceType: "NodePort"

csi:
  enabled: false
EOF
    fi
    
    helm_install_with_summary "vault" "hashicorp/vault" \
        "--namespace $namespace" \
        "--values $values_file" \
        "--wait --timeout=10m"
    
    if [[ $? -eq 0 ]]; then
        log_success "Vault installed successfully"
        log_info "Initialize Vault with: kubectl exec -n vault vault-0 -- vault operator init"
        log_info "Access Vault UI at: http://<node-ip>:30082"
        complete_component "vault"
    else
        log_error "Vault installation failed"
        fail_component "vault" "Helm installation failed"
        return 1
    fi
}

# Install LDAP authentication
ldapInst() {
    log_component_start "LDAP" "Installing LDAP authentication service"
    start_component "ldap"
    
    local namespace="ldap"
    ensure_namespace "$namespace"
    
    local ldap_yaml="${GOK_CONFIG_DIR}/ldap.yaml"
    if [[ ! -f "$ldap_yaml" ]]; then
        cat > "$ldap_yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openldap
  namespace: ldap
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openldap
  template:
    metadata:
      labels:
        app: openldap
    spec:
      containers:
      - name: openldap
        image: osixia/openldap:1.5.0
        env:
        - name: LDAP_ORGANISATION
          value: "GOK Organization"
        - name: LDAP_DOMAIN
          value: "gok.local"
        - name: LDAP_ADMIN_PASSWORD
          value: "admin123"
        - name: LDAP_CONFIG_PASSWORD
          value: "config123"
        ports:
        - containerPort: 389
        - containerPort: 636
        volumeMounts:
        - name: ldap-data
          mountPath: /var/lib/ldap
        - name: ldap-config
          mountPath: /etc/ldap/slapd.d
      volumes:
      - name: ldap-data
        emptyDir: {}
      - name: ldap-config
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: openldap
  namespace: ldap
spec:
  selector:
    app: openldap
  ports:
  - name: ldap
    port: 389
    targetPort: 389
  - name: ldaps
    port: 636
    targetPort: 636
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phpldapadmin
  namespace: ldap
spec:
  replicas: 1
  selector:
    matchLabels:
      app: phpldapadmin
  template:
    metadata:
      labels:
        app: phpldapadmin
    spec:
      containers:
      - name: phpldapadmin
        image: osixia/phpldapadmin:0.9.0
        env:
        - name: PHPLDAPADMIN_LDAP_HOSTS
          value: "openldap"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: phpldapadmin
  namespace: ldap
spec:
  selector:
    app: phpldapadmin
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30083
  type: NodePort
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $ldap_yaml" "Installing LDAP services"
    
    if [[ $? -eq 0 ]]; then
        log_success "LDAP installed successfully"
        log_info "LDAP Admin DN: cn=admin,dc=gok,dc=local"
        log_info "LDAP Admin Password: admin123"
        log_info "phpLDAPadmin UI: http://<node-ip>:30083"
        complete_component "ldap"
    else
        log_error "LDAP installation failed"
        fail_component "ldap" "Kubernetes deployment failed"
        return 1
    fi
}

# Install LDAP client configuration
ldapclientInst() {
    log_component_start "LDAP Client" "Installing LDAP client configuration"
    start_component "ldapclient"
    
    # This would typically configure nodes to use LDAP for authentication
    log_info "LDAP client configuration is node-specific"
    log_info "Please run the LDAP client setup script on each node"
    
    # Create configuration template
    local config_file="${GOK_CONFIG_DIR}/ldap-client-config.sh"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
#!/bin/bash
# LDAP Client Configuration Script
# Run this script on each node that needs LDAP authentication

# Install LDAP client packages
apt-get update
apt-get install -y libnss-ldap libpam-ldap ldap-utils

# Configure LDAP client
cat > /etc/ldap/ldap.conf << EOL
BASE dc=gok,dc=local
URI ldap://openldap.ldap.svc.cluster.local:389
SIZELIMIT 12
TIMELIMIT 15
DEREF never
TLS_CACERTDIR /etc/ssl/certs
EOL

# Update NSS configuration
sed -i 's/^passwd:.*$/passwd: files ldap/' /etc/nsswitch.conf
sed -i 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf
sed -i 's/^shadow:.*$/shadow: files ldap/' /etc/nsswitch.conf

echo "LDAP client configuration completed"
EOF
        chmod +x "$config_file"
    fi
    
    log_success "LDAP client configuration template created"
    log_info "Configuration script: $config_file"
    complete_component "ldapclient"
}

# Install Kerberos authentication
kerberosInst() {
    log_component_start "Kerberos" "Installing Kerberos authentication service"
    start_component "kerberos"
    
    local namespace="kerberos"
    ensure_namespace "$namespace"
    
    local kerberos_yaml="${GOK_CONFIG_DIR}/kerberos.yaml"
    if [[ ! -f "$kerberos_yaml" ]]; then
        cat > "$kerberos_yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kerberos-config
  namespace: kerberos
data:
  krb5.conf: |
    [libdefaults]
        default_realm = GOK.LOCAL
        dns_lookup_realm = false
        dns_lookup_kdc = false
        ticket_lifetime = 24h
        renew_lifetime = 7d
        forwardable = true
    
    [realms]
        GOK.LOCAL = {
            kdc = kerberos.kerberos.svc.cluster.local:88
            admin_server = kerberos.kerberos.svc.cluster.local:749
        }
    
    [domain_realm]
        .gok.local = GOK.LOCAL
        gok.local = GOK.LOCAL
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kerberos
  namespace: kerberos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kerberos
  template:
    metadata:
      labels:
        app: kerberos
    spec:
      containers:
      - name: kerberos
        image: gcavalcante8808/krb5-server:latest
        env:
        - name: KRB5_REALM
          value: "GOK.LOCAL"
        - name: KRB5_KDC
          value: "kerberos.kerberos.svc.cluster.local"
        - name: KRB5_PASS
          value: "admin123"
        ports:
        - containerPort: 88
          protocol: UDP
        - containerPort: 88
          protocol: TCP
        - containerPort: 749
          protocol: TCP
        volumeMounts:
        - name: kerberos-config
          mountPath: /etc/krb5.conf
          subPath: krb5.conf
      volumes:
      - name: kerberos-config
        configMap:
          name: kerberos-config
---
apiVersion: v1
kind: Service
metadata:
  name: kerberos
  namespace: kerberos
spec:
  selector:
    app: kerberos
  ports:
  - name: kdc-udp
    port: 88
    targetPort: 88
    protocol: UDP
  - name: kdc-tcp
    port: 88
    targetPort: 88
    protocol: TCP
  - name: admin
    port: 749
    targetPort: 749
    protocol: TCP
  type: ClusterIP
EOF
    fi
    
    execute_with_suppression "kubectl apply -f $kerberos_yaml" "Installing Kerberos services"
    
    if [[ $? -eq 0 ]]; then
        log_success "Kerberos installed successfully"
        log_info "Realm: GOK.LOCAL"
        log_info "Admin password: admin123"
        complete_component "kerberos"
    else
        log_error "Kerberos installation failed"
        fail_component "kerberos" "Kubernetes deployment failed"
        return 1
    fi
}

# Install kerberized services
kerberizedservicesInst() {
    log_component_start "Kerberized Services" "Installing Kerberos-enabled services"
    start_component "kerberizedservices"
    
    # Ensure Kerberos is installed first
    if ! is_component_successful "kerberos"; then
        log_info "Installing Kerberos dependency..."
        kerberosInst || return 1
    fi
    
    log_info "Kerberized services configuration is application-specific"
    log_info "Services that support Kerberos authentication:"
    log_info "  - SSH (via PAM)"
    log_info "  - HTTP services (via mod_auth_kerb)"
    log_info "  - HDFS, Spark, etc."
    
    complete_component "kerberizedservices"
}