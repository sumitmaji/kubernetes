#!/bin/bash

# GOK Summaries Module - Installation summaries and status displays

# Show OAuth2-specific summary
show_oauth2_summary() {
  local oauth2_host="$1"
  local realm="$2"

  log_info "📋 OAuth2 Proxy Authentication Summary"
  echo

  echo -e "${COLOR_BRIGHT_BLUE}${COLOR_BOLD}🛡️  OAuth2 Proxy Authentication Details${COLOR_RESET}"
  echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Authentication Proxy Information:${COLOR_RESET}"
  echo -e "  🔐 ${COLOR_GREEN}OAuth2 Proxy${COLOR_RESET} - HTTP reverse proxy for authentication"
  echo -e "  🔗 ${COLOR_GREEN}Keycloak Integration${COLOR_RESET} - OIDC provider integration"
  echo -e "  🍪 ${COLOR_GREEN}Session Management${COLOR_RESET} - Secure cookie-based sessions"
  echo -e "  🛡️  ${COLOR_GREEN}Access Control${COLOR_RESET} - Group-based authorization"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Integration Configuration:${COLOR_RESET}"
  echo -e "  🏢 ${COLOR_CYAN}Identity Provider${COLOR_RESET}: ${oauth2_host}"
  echo -e "  🌍 ${COLOR_CYAN}Keycloak Realm${COLOR_RESET}: ${realm}"
  echo -e "  👥 ${COLOR_CYAN}Allowed Groups${COLOR_RESET}: administrators, developers"
  echo -e "  🍪 ${COLOR_CYAN}Cookie Domain${COLOR_RESET}: .gokcloud.com"
  echo -e "  ⏰ ${COLOR_CYAN}Session Duration${COLOR_RESET}: 8 hours (refresh: 1 hour)"
  echo

  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Authentication Features:${COLOR_RESET}"
  echo -e "  ✅ ${COLOR_GREEN}OIDC Integration${COLOR_RESET} - OpenID Connect with Keycloak"
  echo -e "  ✅ ${COLOR_GREEN}Group-based Access${COLOR_RESET} - Role-based authorization"
  echo -e "  ✅ ${COLOR_GREEN}Secure Cookies${COLOR_RESET} - HTTPs-only secure session cookies"
  echo -e "  ✅ ${COLOR_GREEN}Token Passing${COLOR_RESET} - Access token forwarding to backends"
  echo -e "  ✅ ${COLOR_GREEN}Domain Whitelisting${COLOR_RESET} - Restricted to trusted domains"
  echo -e "  ✅ ${COLOR_GREEN}Request Logging${COLOR_RESET} - Comprehensive authentication audit logs"
  echo

  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}💡 OAuth2 Proxy Benefits:${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• Protects any HTTP service with Keycloak authentication${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• Seamless single sign-on experience across all platform services${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• Group-based access control integrated with LDAP directory${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• Secure session management with configurable timeouts${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• Production-ready authentication proxy for enterprise environments${COLOR_RESET}"
  echo
}