#!/bin/bash

# GOK Login Summary Functions
# This module provides summary information for GOK Login operations

show_gok_login_reset_summary() {
  local status="$1"
  local duration="${2:-0}"

  echo ""
  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🔄 GOK LOGIN RESET SUMMARY${COLOR_RESET}"
  echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════════${COLOR_RESET}"
  echo ""

  if [[ "$status" == "already-reset" ]]; then
    echo -e "${COLOR_GREEN}✅ GOK Login was already reset or never installed${COLOR_RESET}"
  else
    echo -e "${COLOR_GREEN}✅ Components Successfully Removed:${COLOR_RESET}"
    echo -e "  • GOK Login Helm release uninstalled"
    echo -e "  • GOK Login namespace and all resources deleted"
    echo -e "  • Authentication service containers removed"
    echo -e "  • Ingress and TLS certificates cleaned up"
    echo ""
    echo -e "${COLOR_YELLOW}⚠️  Important Notes:${COLOR_RESET}"
    echo -e "  • ${COLOR_RED}Authentication service is no longer available${COLOR_RESET}"
    echo -e "  • Users cannot generate new kubeconfig files"
    echo -e "  • Existing kubeconfig files remain valid until expiry"
    echo -e "  • Login script is still available for reinstallation"
  fi

  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}📋 Next Steps:${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}1. Fresh Installation:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}gok install gok-login               # Reinstall GOK Login service${COLOR_RESET}"
  echo ""
  echo -e "${COLOR_CYAN}2. Alternative Authentication:${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}kubectl config use-context admin    # Use admin kubeconfig${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}# Or use existing kubeconfig files generated before reset${COLOR_RESET}"
}

# Export the function to make it available
export -f show_gok_login_reset_summary