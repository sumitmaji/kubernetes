#!/bin/bash

# GOK Security Components Module - Cert-Manager, Keycloak, OAuth2, Vault, LDAP, Kerberos

# Helper functions for certificate management
getLetsEncEnv(){
  echo "${LETS_ENCRYPT_ENV}"
}

getLetsEncryptUrl(){
  [[ $(getLetsEncEnv) == 'prod' ]] && echo "https://acme-v02.api.letsencrypt.org/directory " || echo "https://acme-staging-v02.api.letsencrypt.org/directory"
}

isProd(){
  [[ $(getLetsEncEnv) == 'prod' ]] && echo "true" || echo "false"
}

getClusterIssuerName(){
  case "$CERTMANAGER_CHALANGE_TYPE" in
   'dns') echo "letsencrypt-$(getLetsEncEnv)" ;;
   'http') echo "letsencrypt-$(getLetsEncEnv)" ;;
   'selfsigned') echo "gokselfsign-ca-cluster-issuer" ;;
  esac
}

#Godday api calls are disabled, hence going to remove this call.
godaddyWebhook() {
  replaceEnvVariable  https://github.com/sumitmaji/kubernetes/raw/master/install_k8s/godaddy-cert-webhook/webhook-all.yml | kubectl create -f - --validate=false
  echo "Provide godaddy apikey and secret <API_KEY:SECRET>"
  API_KEY=$(promptSecret "Provide godaddy apikey and secret <API_KEY:SECRET>")
  kubectl create secret generic godaddy-api-key-secret --from-literal=api-key=$API_KEY -n cert-manager
}

addLetsEncryptStagingCertificates(){
  wget https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x1.pem
  sudo cp letsencrypt-stg-root-x1.pem /usr/local/share/ca-certificates/
  sudo update-ca-certificates
  echo "Added letsencrypt staging certificates, please reboot the system for it to effect"
}

godaddyWebhookReset() {
  kubectl delete -f https://github.com/sumitmaji/kubernetes/raw/master/install_k8s/godaddy-cert-webhook/webhook-all.yml
  kubectl delete secret godaddy-api-key-secret -n cert-manager
}

# Install Cert-Manager for certificate management
certManagerInst() {
    log_component_start "cert-manager" "Installing certificate management system"
    
    log_step "1" "Adding Jetstack Helm repository"
    execute_with_suppression helm repo add jetstack https://charts.jetstack.io
    execute_with_suppression helm repo update
    
    log_step "2" "Installing cert-manager via Helm"
    #kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.crds.yaml

    #--set serviceAccount.automountServiceAccountToken=false \
    #--set webhook.timeoutSeconds=30
    #--set startupapicheck.timeout=10m
    # --debug
    if helm_install_with_summary "cert-manager" "cert-manager" \
        cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --set global.leaderElection.namespace=cert-manager \
        --version v1.14.5 \
        --values https://github.com/sumitmaji/kubernetes/raw/master/install_k8s/cert-manager/values.yaml \
        --wait; then
        
        show_installation_summary "cert-manager" "cert-manager" "TLS certificate management system"
        log_component_success "cert-manager" "Certificate management system installed successfully"
    else
        log_error "cert-manager installation failed"
        return 1
    fi
}

setupCertiIssuers() {
  log_component_start "cert-issuers" "Configuring certificate issuers and CA infrastructure"

if [ $CERTMANAGER_CHALANGE_TYPE == 'dns' ]; then
  log_step "1" "Creating Let's Encrypt DNS challenge cluster issuer"
  if execute_with_suppression kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $(getClusterIssuerName)
spec:
  acme:
    email: majisumitkumar@gmail.com
    server: $(getLetsEncryptUrl)
    privateKeySecretRef:
      name: letsencrypt-$(getLetsEncEnv)
    solvers:
    - dns01:
        webhook:
          config:
            apiKeySecretRef:
              name: godaddy-api-key-secret
              key: api-key
            production: $(isProd)
            ttl: 600
          groupName: $(rootDomain)
          solverName: godaddy
      selector:
       dnsNames:
       - '$(defaultSubdomain).$(rootDomain)'
       - '*.$(rootDomain)'
EOF
  then
    log_success "Let's Encrypt DNS challenge issuer created ($(getClusterIssuerName))"
  else
    log_error "Failed to create Let's Encrypt DNS challenge issuer"
    return 1
  fi
  
  log_step "2" "Installing GoDaddy DNS webhook"
  if godaddyWebhook; then
    log_success "GoDaddy DNS webhook installed"
  else
    log_error "Failed to install GoDaddy DNS webhook"
    return 1
  fi
  
  log_step "3" "Adding Let's Encrypt staging certificates"
  if addLetsEncryptStagingCertificates; then
    log_success "Let's Encrypt staging certificates configured"
  else
    log_error "Failed to configure Let's Encrypt staging certificates"
    return 1
  fi
elif [ $CERTMANAGER_CHALANGE_TYPE == 'http' ]; then
  log_step "1" "Creating Let's Encrypt HTTP challenge cluster issuer"
  if execute_with_suppression kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $(getClusterIssuerName)
spec:
  acme:
    email: majisumitkumar@gmail.com
    server: $(getLetsEncryptUrl)
    #preferredChain: "(STAGING) Pretend Pear X1"
    privateKeySecretRef:
      name: letsencrypt-$(getLetsEncEnv)
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
EOF
  then
    log_success "Let's Encrypt HTTP challenge issuer created ($(getClusterIssuerName))"
  else
    log_error "Failed to create Let's Encrypt HTTP challenge issuer"
    return 1
  fi
  
  log_step "2" "Adding Let's Encrypt staging certificates"
  if addLetsEncryptStagingCertificates; then
    log_success "Let's Encrypt staging certificates configured"
  else
    log_error "Failed to configure Let's Encrypt staging certificates"
    return 1
  fi
elif [ $CERTMANAGER_CHALANGE_TYPE == 'selfsigned' ]; then
  # https://medium.com/geekculture/a-simple-ca-setup-with-kubernetes-cert-manager-bc8ccbd9c2
  # https://gist.github.com/jakexks/c1de8238cbee247333f8c274dc0d6f0f
  
  log_step "1" "Creating self-signed cluster issuer"
  local retry_count=0
  local max_retries=5
  while [ $retry_count -lt $max_retries ]; do
    if execute_with_suppression kubectl apply -f - <<EOYAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
EOYAML
    then
      log_success "Self-signed cluster issuer created"
      break
    else
      retry_count=$((retry_count + 1))
      if [ $retry_count -eq $max_retries ]; then
        log_error "Failed to create self-signed cluster issuer after $max_retries attempts"
        return 1
      fi
      sleep 1
    fi
  done

  if execute_with_suppression kubectl wait --timeout=10s --for=condition=Ready clusterissuers.cert-manager.io selfsigned-cluster-issuer; then
    log_success "Self-signed cluster issuer is ready"
  else
    log_error "Self-signed cluster issuer failed to become ready"
    return 1
  fi

  log_step "2" "Creating CA certificate authority"
  if execute_with_suppression kubectl apply -f - <<EOYAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gokselfsign-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: gokselfsign-ca
  secretName: gokselfsign-ca
  subject:
    organizations:
      - GOK Inc.
    organizationalUnits:
      - Widgets
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
EOYAML
  then
    log_success "CA certificate created (GOK Inc. authority)"
  else
    log_error "Failed to create CA certificate"
    return 1
  fi

  if execute_with_suppression kubectl wait --timeout=10s -n cert-manager --for=condition=Ready certificates.cert-manager.io gokselfsign-ca; then
    log_success "CA certificate is ready and issued"
  else
    log_error "CA certificate failed to become ready"
    return 1
  fi

  log_step "3" "Creating production CA cluster issuer"
  if execute_with_suppression kubectl apply -f - <<EOYAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $(getClusterIssuerName)
spec:
  ca:
    secretName: gokselfsign-ca
EOYAML
  then
    log_success "Production CA cluster issuer created ($(getClusterIssuerName))"
  else
    log_error "Failed to create production CA cluster issuer"
    return 1
  fi

  if execute_with_suppression kubectl wait --timeout=10s --for=condition=Ready clusterissuers.cert-manager.io "$(getClusterIssuerName)"; then
    log_success "Production CA cluster issuer is ready"
  else
    log_error "Production CA cluster issuer failed to become ready"
    return 1
  fi

  log_step "4" "Installing CA certificate to system trust store"
  # Extract CA certificate using proper shell command with redirection handling
  # Fixed: Wrap in 'bash -c' to ensure redirection works with execute_with_suppression 
  if execute_with_suppression bash -c 'kubectl get secrets -n cert-manager gokselfsign-ca -o json | jq -r ".data[\"tls.crt\"]" | base64 -d > /usr/local/share/ca-certificates/issuer.crt'; then
    log_success "CA certificate extracted from Kubernetes secret"
  else
    log_error "Failed to extract CA certificate"
    return 1
  fi

  # Add the issuer.crt to export directory so that the worker nodes can add the same to their trusted certificates.
  if execute_with_suppression mkdir -p /export/certs && execute_with_suppression cp /usr/local/share/ca-certificates/issuer.crt /export/certs/issuer.crt; then
    log_success "CA certificate copied to shared storage for worker nodes"
  else
    log_error "Failed to copy CA certificate to shared storage"
    return 1
  fi

  if execute_with_suppression update-ca-certificates; then
    log_success "System certificate store updated with GOK CA"
  else
    log_error "Failed to update system certificate store"
    return 1
  fi

  log_step "4b" "Refreshing certificates in Kubernetes cluster (avoiding system reboot)"
  log_info "⚠️ Self-signed certificate added to system CA store - applying cluster-wide refresh instead of system reboot"
  
  # Restart containerd/docker to pick up new CA certificates
  if systemctl is-active --quiet containerd; then
    log_info "🔄 Restarting containerd to refresh CA certificates"
    if execute_with_suppression systemctl restart containerd; then
      log_success "Containerd restarted successfully"
    else
      log_warning "Failed to restart containerd - certificates may not be fully effective"
    fi
  elif systemctl is-active --quiet docker; then
    log_info "🔄 Restarting Docker to refresh CA certificates"
    if execute_with_suppression systemctl restart docker; then
      log_success "Docker restarted successfully"
    else
      log_warning "Failed to restart Docker - certificates may not be fully effective"
    fi
  fi
  
  # Restart kubelet to refresh certificates
  log_info "🔄 Restarting kubelet to refresh CA certificates"
  if execute_with_suppression systemctl restart kubelet; then
    log_success "Kubelet restarted successfully"
  else
    log_warning "Failed to restart kubelet - certificates may not be fully effective"
  fi
  
  # Wait for kubelet to be ready
  log_info "⏳ Waiting for kubelet to become ready..."
  sleep 10
  
  # Restart cert-manager pods to pick up new CA certificates
  log_info "🔄 Restarting cert-manager pods to refresh CA certificates"
  if execute_with_suppression kubectl rollout restart deployment cert-manager -n cert-manager; then
    log_success "Cert-manager deployment restarted"
  else
    log_warning "Failed to restart cert-manager deployment"
  fi
  
  if execute_with_suppression kubectl rollout restart deployment cert-manager-webhook -n cert-manager; then
    log_success "Cert-manager webhook restarted"
  else
    log_warning "Failed to restart cert-manager webhook"
  fi
  
  if execute_with_suppression kubectl rollout restart deployment cert-manager-cainjector -n cert-manager; then
    log_success "Cert-manager CA injector restarted"
  else
    log_warning "Failed to restart cert-manager CA injector"
  fi
  
  # Wait for cert-manager components to be ready
  log_info "⏳ Waiting for cert-manager components to become ready..."
  if execute_with_suppression kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n cert-manager; then
    log_success "Cert-manager deployment is ready"
  else
    log_warning "Cert-manager deployment may not be fully ready"
  fi
  
  if execute_with_suppression kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n cert-manager; then
    log_success "Cert-manager webhook is ready"
  else
    log_warning "Cert-manager webhook may not be fully ready"
  fi
  
  # Restart kube-system components that use certificates
  log_info "🔄 Restarting core Kubernetes components to refresh certificates"
  
  # Restart kube-proxy daemonset
  if execute_with_suppression kubectl rollout restart daemonset kube-proxy -n kube-system; then
    log_success "Kube-proxy daemonset restarted"
  else
    log_warning "Failed to restart kube-proxy daemonset"
  fi
  
  # Restart CoreDNS
  if execute_with_suppression kubectl rollout restart deployment coredns -n kube-system; then
    log_success "CoreDNS deployment restarted"
  else
    log_warning "Failed to restart CoreDNS deployment"
  fi
  
  # If there's an ingress controller, restart it
  if kubectl get deployment -n ingress-nginx nginx-ingress-controller >/dev/null 2>&1; then
    log_info "🔄 Restarting NGINX ingress controller"
    if execute_with_suppression kubectl rollout restart deployment nginx-ingress-controller -n ingress-nginx; then
      log_success "NGINX ingress controller restarted"
    else
      log_warning "Failed to restart NGINX ingress controller"
    fi
  fi
  
  # Restart any other critical components that might use certificates
  if kubectl get deployment -n vault vault >/dev/null 2>&1; then
    log_info "🔄 Restarting Vault deployment"
    if execute_with_suppression kubectl rollout restart deployment vault -n vault; then
      log_success "Vault deployment restarted"
    else
      log_warning "Failed to restart Vault deployment"
    fi
  fi
  
  if kubectl get deployment -n rabbitmq rabbitmq >/dev/null 2>&1; then
    log_info "🔄 Restarting RabbitMQ deployment"
    if execute_with_suppression kubectl rollout restart deployment rabbitmq -n rabbitmq; then
      log_success "RabbitMQ deployment restarted"
    else
      log_warning "Failed to restart RabbitMQ deployment"
    fi
  fi
  
  # Restart HAProxy if it's running
  if docker ps --filter "name=master-proxy" --filter "status=running" -q | grep -q .; then
    log_info "🔄 Restarting HAProxy to refresh CA certificates"
    if startHa; then
      log_success "HAProxy restarted successfully"
    else
      log_warning "Failed to restart HAProxy - certificates may not be fully effective"
    fi
  elif [ -f /opt/haproxy.cfg ]; then
    log_info "🔄 HAProxy configuration found - starting HAProxy with new certificates"
    if startHa; then
      log_success "HAProxy started successfully with updated certificates"
    else
      log_warning "Failed to start HAProxy"
    fi
  fi
  
  # Final verification
  log_info "🔍 Verifying certificate refresh completion"
  
  # Test certificate validation
  if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /usr/local/share/ca-certificates/issuer.crt >/dev/null 2>&1; then
    log_success "✅ Self-signed CA certificate is properly trusted by the system"
  else
    log_warning "⚠️ Certificate validation test failed - some components may not recognize the new CA"
  fi
  
  # Check cluster health
  log_info "🏥 Checking cluster health status"
  if kubectl get nodes >/dev/null 2>&1; then
    log_success "✅ Kubernetes cluster is responsive"
  else
    log_warning "⚠️ Kubernetes cluster may not be fully responsive"
  fi
  
  log_success "🎉 Certificate refresh completed - cluster-wide certificate update applied without system reboot"
  log_info "📋 Next steps: Verify your applications can validate certificates issued by the new CA"
  log_info "💡 Tip: If you encounter certificate validation issues, run 'kubectl rollout restart deployment <deployment-name>' for specific applications"
fi

  log_step "5" "Creating default domain certificate"
  if execute_with_suppression kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $(sedRootDomain)-tls
  namespace: default
spec:
  secretName: $(sedRootDomain)
  issuerRef:
    name: $(getClusterIssuerName)
    kind: ClusterIssuer
  commonName: $(defaultSubdomain).$(rootDomain)
  dnsNames:
    - $(defaultSubdomain).$(rootDomain)
  issuerRef:
    name: $(getClusterIssuerName)
    kind: ClusterIssuer
EOF
  then
    log_success "Default domain certificate created ($(defaultSubdomain).$(rootDomain))"
  else
    log_error "Failed to create default domain certificate"
    return 1
  fi

  log_warning "Self-signed certificate added to system CA store - system reboot recommended for full effect"
  log_component_success "cert-issuers" "Certificate issuers and CA infrastructure configured successfully"
}

# Install Keycloak identity and access management
keycloakInst() {
    log_component_start "Keycloak" "Installing identity and access management"
    start_component "keycloak"
    
    local namespace="keycloak"
    ensure_namespace "$namespace"
    
    # Add Bitnami Helm repository
    log_info "Adding Bitnami Helm repository"
    execute_with_suppression helm repo add bitnami https://charts.bitnami.com/bitnami
    execute_with_suppression helm repo update
    
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
    log_info "Adding OAuth2 Proxy Helm repository"
    execute_with_suppression helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
    execute_with_suppression helm repo update
    
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
    log_info "Adding HashiCorp Helm repository"
    execute_with_suppression helm repo add hashicorp https://helm.releases.hashicorp.com
    execute_with_suppression helm repo update
    
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