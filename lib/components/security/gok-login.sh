#!/bin/bash

# GOK Login Component Installation
# This module handles the installation of GOK Login authentication service

gokLoginInst() {
  local start_time=$(date +%s)
  local component="gok-login"

  echo ""
  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔐 GOK LOGIN INSTALLATION${COLOR_RESET}"
  echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""

  # Check if already installed
  if helm list -n gok-login --short 2>/dev/null | grep -q "^gok-login$"; then
    echo -e "${COLOR_YELLOW}⚠️  GOK Login is already installed${COLOR_RESET}"
    echo -e "${COLOR_CYAN}Use 'gok reset gok-login' to remove existing installation first${COLOR_RESET}"
    return 1
  fi

  echo -e "${COLOR_CYAN}📦 Installing GOK Login authentication service...${COLOR_RESET}"

  # Create namespace
  kubectl create namespace gok-login --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1

  # Add Helm repository if not exists
  if ! helm repo list | grep -q "^gok-login"; then
    helm repo add gok-login https://charts.gok.com/login >/dev/null 2>&1
    helm repo update >/dev/null 2>&1
  fi

  # Prepare Helm values
  local helm_values=""
  helm_values="$helm_values --set image.repository=gok-login"
  helm_values="$helm_values --set image.tag=latest"
  helm_values="$helm_values --set service.type=ClusterIP"
  helm_values="$helm_values --set ingress.enabled=true"
  helm_values="$helm_values --set ingress.hosts[0].host=login.k8s.local"
  helm_values="$helm_values --set ingress.tls[0].secretName=gok-login-tls"
  helm_values="$helm_values --set ingress.tls[0].hosts[0]=login.k8s.local"

  # Configure OIDC if available
  if kubectl get secret oidc-secret -n keycloak >/dev/null 2>&1; then
    local oidc_client_id=$(kubectl get secret oidc-secret -n keycloak -o jsonpath='{.data.client-id}' | base64 -d 2>/dev/null)
    local oidc_client_secret=$(kubectl get secret oidc-secret -n keycloak -o jsonpath='{.data.client-secret}' | base64 -d 2>/dev/null)
    local oidc_issuer_url=$(kubectl get secret oidc-secret -n keycloak -o jsonpath='{.data.issuer-url}' | base64 -d 2>/dev/null)

    if [[ -n "$oidc_client_id" && -n "$oidc_client_secret" && -n "$oidc_issuer_url" ]]; then
      helm_values="$helm_values --set oidc.enabled=true"
      helm_values="$helm_values --set oidc.clientId=$oidc_client_id"
      helm_values="$helm_values --set oidc.clientSecret=$oidc_client_secret"
      helm_values="$helm_values --set oidc.issuerUrl=$oidc_issuer_url"
      helm_values="$helm_values --set oidc.redirectUrl=https://login.k8s.local/oauth2/callback"
    fi
  fi

  # Install Helm chart
  if helm upgrade --install gok-login gok-login/gok-login \
    --namespace gok-login \
    --create-namespace \
    --wait \
    --timeout 600s \
    $helm_values >/dev/null 2>&1; then

    echo -e "${COLOR_GREEN}✅ GOK Login installed successfully${COLOR_RESET}"

    # Wait for pods to be ready
    echo -e "${COLOR_CYAN}⏳ Waiting for GOK Login pods to be ready...${COLOR_RESET}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gok-login -n gok-login --timeout=300s >/dev/null 2>&1

    # Show installation summary
    show_installation_summary "gok-login" "gok-login" "GOK Login authentication service"

    local duration=$(( $(date +%s) - start_time ))
    echo ""
    echo -e "${COLOR_GREEN}🎉 GOK Login installation completed in ${duration}s${COLOR_RESET}"

    return 0
  else
    echo -e "${COLOR_RED}❌ Failed to install GOK Login${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}📋 Troubleshooting:${COLOR_RESET}"
    echo -e "  • Check Helm repositories: helm repo list"
    echo -e "  • Check namespace: kubectl get ns gok-login"
    echo -e "  • Check pods: kubectl get pods -n gok-login"
    echo -e "  • Check logs: kubectl logs -l app.kubernetes.io/name=gok-login -n gok-login"
    return 1
  fi
}

# Export the function to make it available
export -f gokLoginInst