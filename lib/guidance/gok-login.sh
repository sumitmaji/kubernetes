#!/bin/bash

# GOK Login Guidance Functions
# This module provides guidance and next steps for GOK Login operations

show_gok_login_next_steps() {
  local duration="$1"

  echo ""
  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔐 GOK LOGIN ACCESS INFORMATION${COLOR_RESET}"
  echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🌐 Service Access:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}URL:${COLOR_RESET}      https://gok-login.$(rootDomain)"
  echo -e "  ${COLOR_CYAN}Purpose:${COLOR_RESET}  Kubernetes authentication and kubeconfig generation"
  echo -e "  ${COLOR_CYAN}Method:${COLOR_RESET}   LDAP/OIDC authentication"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🔧 Authentication Script Usage:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}Script Location:${COLOR_RESET} ${COLOR_BOLD}${MOUNT_PATH}/kubernetes/install_k8s/gok-login/login.sh${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}📋 Login Script Commands:${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}1. Basic Login (Interactive):${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}cd ${MOUNT_PATH}/kubernetes/install_k8s/gok-login${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}./login.sh${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}2. Login with Username:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}./login.sh --username your-username${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}3. Login with Custom Server:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}./login.sh --server https://gok-login.$(rootDomain)${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}4. Get Help:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}./login.sh --help${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}🎯 What the Script Does:${COLOR_RESET}"
  echo -e "  • ${COLOR_GREEN}Authenticates${COLOR_RESET} against LDAP/OIDC providers"
  echo -e "  • ${COLOR_GREEN}Generates${COLOR_RESET} personalized kubeconfig file"
  echo -e "  • ${COLOR_GREEN}Configures${COLOR_RESET} kubectl for secure cluster access"
  echo -e "  • ${COLOR_GREEN}Sets up${COLOR_RESET} RBAC permissions based on user groups"
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}📚 Additional Resources:${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}Check Status:${COLOR_RESET}     ${COLOR_DIM}kubectl get pods -n gok-login${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}View Logs:${COLOR_RESET}        ${COLOR_DIM}kubectl logs -l app=gok-login -n gok-login${COLOR_RESET}"
  echo -e "  ${COLOR_CYAN}Service Info:${COLOR_RESET}     ${COLOR_DIM}kubectl get svc -n gok-login${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_GREEN}🎉 GOK Login authentication service ready! Login script available at gok-login/login.sh${COLOR_RESET}"
  echo ""
}

# Export the function to make it available
export -f show_gok_login_next_steps