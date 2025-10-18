#!/bin/bash

# GOK Login Validation Functions
# This module validates the GOK Login installation and configuration

validate_gok_login_installation() {
  local component="gok-login"
  local errors=0

  echo ""
  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔍 GOK LOGIN VALIDATION${COLOR_RESET}"
  echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""

  # Check namespace
  echo -e "${COLOR_CYAN}📁 Checking namespace...${COLOR_RESET}"
  if kubectl get namespace gok-login >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✅ Namespace 'gok-login' exists${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Namespace 'gok-login' not found${COLOR_RESET}"
    ((errors++))
  fi

  # Check Helm release
  echo -e "${COLOR_CYAN}📦 Checking Helm release...${COLOR_RESET}"
  if helm list -n gok-login --short 2>/dev/null | grep -q "^gok-login$"; then
    echo -e "${COLOR_GREEN}✅ Helm release 'gok-login' is installed${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}❌ Helm release 'gok-login' not found${COLOR_RESET}"
    ((errors++))
  fi

  # Check pods
  echo -e "${COLOR_CYAN}🐳 Checking pods...${COLOR_RESET}"
  local pod_count=$(kubectl get pods -n gok-login -l app.kubernetes.io/name=gok-login --no-headers 2>/dev/null | wc -l)
  if [[ $pod_count -gt 0 ]]; then
    echo -e "${COLOR_GREEN}✅ Found $pod_count GOK Login pod(s)${COLOR_RESET}"

    # Check pod status
    local ready_pods=$(kubectl get pods -n gok-login -l app.kubernetes.io/name=gok-login --no-headers 2>/dev/null | grep -c "Running")
    if [[ $ready_pods -eq $pod_count ]]; then
      echo -e "${COLOR_GREEN}✅ All pods are running${COLOR_RESET}"
    else
      echo -e "${COLOR_YELLOW}⚠️  Some pods are not ready ($ready_pods/$pod_count running)${COLOR_RESET}"
    fi
  else
    echo -e "${COLOR_RED}❌ No GOK Login pods found${COLOR_RESET}"
    ((errors++))
  fi

  # Check service
  echo -e "${COLOR_CYAN}🌐 Checking service...${COLOR_RESET}"
  if kubectl get service gok-login -n gok-login >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✅ Service 'gok-login' exists${COLOR_RESET}"

    # Check service endpoints
    local endpoints=$(kubectl get endpoints gok-login -n gok-login -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | wc -w)
    if [[ $endpoints -gt 0 ]]; then
      echo -e "${COLOR_GREEN}✅ Service has $endpoints endpoint(s)${COLOR_RESET}"
    else
      echo -e "${COLOR_RED}❌ Service has no endpoints${COLOR_RESET}"
      ((errors++))
    fi
  else
    echo -e "${COLOR_RED}❌ Service 'gok-login' not found${COLOR_RESET}"
    ((errors++))
  fi

  # Check ingress
  echo -e "${COLOR_CYAN}🌐 Checking ingress...${COLOR_RESET}"
  if kubectl get ingress gok-login -n gok-login >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✅ Ingress 'gok-login' exists${COLOR_RESET}"

    # Check ingress hosts
    local hosts=$(kubectl get ingress gok-login -n gok-login -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
    if [[ -n "$hosts" ]]; then
      echo -e "${COLOR_GREEN}✅ Ingress configured for host(s): $hosts${COLOR_RESET}"
    else
      echo -e "${COLOR_YELLOW}⚠️  Ingress has no host configuration${COLOR_RESET}"
    fi
  else
    echo -e "${COLOR_RED}❌ Ingress 'gok-login' not found${COLOR_RESET}"
    ((errors++))
  fi

  # Check OIDC configuration if enabled
  echo -e "${COLOR_CYAN}🔐 Checking OIDC configuration...${COLOR_RESET}"
  if kubectl get secret oidc-secret -n keycloak >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✅ OIDC secret found in keycloak namespace${COLOR_RESET}"

    # Check if OIDC is configured in the deployment
    local oidc_enabled=$(kubectl get deployment gok-login -n gok-login -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="OIDC_ENABLED")].value}' 2>/dev/null)
    if [[ "$oidc_enabled" == "true" ]]; then
      echo -e "${COLOR_GREEN}✅ OIDC is enabled in GOK Login${COLOR_RESET}"
    else
      echo -e "${COLOR_YELLOW}⚠️  OIDC is not enabled in GOK Login${COLOR_RESET}"
    fi
  else
    echo -e "${COLOR_YELLOW}⚠️  OIDC secret not found - OIDC authentication not configured${COLOR_RESET}"
  fi

  # Summary
  echo ""
  if [[ $errors -eq 0 ]]; then
    echo -e "${COLOR_GREEN}🎉 GOK Login validation completed successfully${COLOR_RESET}"
    return 0
  else
    echo -e "${COLOR_RED}❌ GOK Login validation failed with $errors error(s)${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}💡 Run 'gok install gok-login' to reinstall or check the troubleshooting guide${COLOR_RESET}"
    return 1
  fi
}

# Export the function to make it available
export -f validate_gok_login_installation