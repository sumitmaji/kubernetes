#!/bin/bash

# GOK Eclipse Che Installation Module
# Provides Eclipse Che cloud IDE deployment with OAuth integration

# Main installation function for Eclipse Che
install_che() {
    log_component_start "che" "Installing Eclipse Che cloud IDE with OAuth integration"
    
    # Fetch OIDC client secret and other required parameters
    log_substep "Retrieving OAuth configuration from secrets"
    local CLIENT_SECRET=$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_SECRET)
    local CLIENT_ID=$(dataFromSecret oauth-secrets kube-system OIDC_CLIENT_ID)
    local REALM_NAME=$(dataFromSecret oauth-secrets kube-system OAUTH_REALM)
    
    if [[ -z "$CLIENT_SECRET" || -z "$CLIENT_ID" || -z "$REALM_NAME" ]]; then
        log_error "Failed to retrieve OAuth configuration from secrets"
        log_component_error "che" "OAuth configuration missing"
        return 1
    fi
    
    log_success "OAuth configuration retrieved successfully"
    log_substep "Client ID: ${COLOR_CYAN}${CLIENT_ID}${COLOR_RESET}"
    log_substep "Realm: ${COLOR_CYAN}${REALM_NAME}${COLOR_RESET}"
    
    # Create local storage for Eclipse Che
    log_substep "Creating persistent storage for Eclipse Che"
    if execute_with_suppression createLocalStorageClassAndPV "eclipse-che-storage" "eclipse-che-pv" "/data/volumes/eclipse-che"; then
        log_success "Eclipse Che storage created"
    else
        log_warning "Storage creation had issues but continuing"
    fi
    
    # Install Chectl
    log_substep "Installing chectl CLI tool"
    
    # Check if chectl is already installed
    if command -v chectl &>/dev/null; then
        log_info "Chectl is already installed: $(chectl version 2>/dev/null | head -n1)"
        log_success "Chectl CLI tool available"
    else
        # Install chectl directly with bash pipe (not through execute_with_suppression to avoid arg length issues)
        if [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
            bash <(curl -sL https://che-incubator.github.io/chectl/install.sh)
        else
            bash <(curl -sL https://che-incubator.github.io/chectl/install.sh) >/dev/null 2>&1
        fi
        
        if command -v chectl &>/dev/null; then
            log_success "Chectl installed successfully"
        else
            log_error "Chectl installation failed"
            log_component_error "che" "Chectl installation failed"
            return 1
        fi
    fi
    
    # Create namespace
    log_substep "Creating eclipse-che namespace"
    if execute_with_suppression kubectl create namespace eclipse-che; then
        log_success "Namespace created"
    else
        log_info "Namespace eclipse-che already exists"
    fi
    
    # Create Keycloak CA certificate configmap
    log_substep "Setting up Keycloak CA certificates"
    local temp_ca_cert=$(mktemp)
    
    if kubectl get secret keycloak-gokcloud-com -n keycloak -o jsonpath="{.data['ca\.crt']}" 2>/dev/null | base64 -d > "$temp_ca_cert"; then
        if execute_with_suppression kubectl create configmap keycloak-certs --from-file=keycloak-ca.crt="$temp_ca_cert" -n eclipse-che; then
            log_success "Keycloak CA certificates configmap created"
        else
            log_warning "Keycloak certs configmap may already exist"
        fi
        
        # Label the configmap
        if execute_with_suppression kubectl label configmap keycloak-certs app.kubernetes.io/part-of=che.eclipse.org app.kubernetes.io/component=ca-bundle -n eclipse-che --overwrite; then
            log_success "Configmap labeled successfully"
        fi
    else
        log_warning "Could not retrieve Keycloak CA certificate, continuing without it"
    fi
    rm -f "$temp_ca_cert"
    
    # Create CheCluster patch file
    log_substep "Generating CheCluster configuration"
    local temp_patch_file=$(mktemp)
    
    cat > "$temp_patch_file" << EOF
kind: CheCluster
apiVersion: org.eclipse.che/v2
spec:
  devEnvironments:
    secondsOfInactivityBeforeIdling: -1
    storage:
      perUserStrategyPvcConfig:
        claimSize: 2Gi 
        storageClass: eclipse-che-storage
      pvcStrategy: per-user 
    
  networking:
    auth:
      oAuthClientName: ${CLIENT_ID}
      oAuthSecret: ${CLIENT_SECRET}
      identityProviderURL: "https://$(fullKeycloakUrl)/realms/${REALM_NAME}"
      gateway:
        oAuthProxy:
          cookieExpireSeconds: 300
  components:
    cheServer:
      extraVolumes:
        - name: keycloak-ca
          configMap:
            name: keycloak-certs
      extraVolumeMounts:
        - name: keycloak-ca
          mountPath: /etc/ssl/certs/keycloak-ca.crt
          subPath: keycloak-ca.crt
          readOnly: true
      extraProperties:
        CHE_OIDC_USERNAME__CLAIM: email
        CHE_OIDC_SKIP_CERTIFICATE_VERIFICATION: "true"
        REQUESTS_CA_BUNDLE: /etc/ssl/certs/keycloak-ca.crt
EOF
    
    log_success "CheCluster configuration generated"
    
    # Deploy Eclipse Che using chectl
    log_substep "Deploying Eclipse Che server"
    local temp_deploy_log=$(mktemp)
    local temp_deploy_error=$(mktemp)
    
    if chectl server:deploy --platform k8s --domain che.gokcloud.com --che-operator-cr-patch-yaml "$temp_patch_file" --skip-cert-manager >"$temp_deploy_log" 2>"$temp_deploy_error"; then
        log_success "Eclipse Che deployed successfully"
        log_component_success "che" "Eclipse Che is now running at https://che.gokcloud.com"
    else
        log_error "Eclipse Che deployment failed"
        if [[ -s "$temp_deploy_error" ]]; then
            cat "$temp_deploy_error" >&2
        fi
        rm -f "$temp_patch_file" "$temp_deploy_log" "$temp_deploy_error"
        log_component_error "che" "Eclipse Che deployment failed"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_patch_file" "$temp_deploy_log" "$temp_deploy_error"
    
    log_info "Eclipse Che installation completed successfully"
    return 0
}

# Export the function
export -f install_che
