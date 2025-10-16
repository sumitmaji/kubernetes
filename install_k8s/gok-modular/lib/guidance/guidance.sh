#!/bin/bash

# GOK Guidance Module - Next steps and module recommendations

# Show OAuth2 next steps and recommend RabbitMQ
show_oauth2_next_steps() {
  echo
  echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🚀 OAuth2 Proxy Post-Installation Steps${COLOR_RESET}"
  echo

  echo -e "${COLOR_MAGENTA}${COLOR_BOLD}Immediate Next Steps:${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  1. Test OAuth2 authentication with protected services${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  2. Configure additional applications to use OAuth2 proxy${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  3. Set up group-based access policies in Keycloak${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  4. Monitor authentication logs and session management${COLOR_RESET}"
  echo

  echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: RabbitMQ${COLOR_RESET}"
  echo -e "${COLOR_CYAN}OAuth2 provides authentication - now add RabbitMQ for messaging and communication!${COLOR_RESET}"
  echo
  echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install RabbitMQ next?${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📨 Reliable message broker for asynchronous communication${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🔗 Decouples services for better scalability and resilience${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 📊 Enables event-driven architecture patterns${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🚀 High-performance messaging for microservices${COLOR_RESET}"
  echo -e "${COLOR_GREEN}• 🛡️  Secure messaging with authentication and authorization${COLOR_RESET}"
  echo
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install RabbitMQ now?${COLOR_RESET}"
  echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install rabbitmq${COLOR_RESET}"
  echo

  # Suggest and install RabbitMQ as the next step
  suggest_and_install_next_module "oauth2"
}

# Suggest and install next module based on current installation
suggest_and_install_next_module() {
  local current_module="$1"

  case "$current_module" in
    "keycloak")
      echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: OAuth2 Proxy${COLOR_RESET}"
      echo -e "${COLOR_CYAN}Keycloak provides identity management - now add OAuth2 proxy for authentication!${COLOR_RESET}"
      echo
      echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install OAuth2 proxy next?${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🛡️  Protects any HTTP service with Keycloak authentication${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🔐 Single sign-on experience across all platform services${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 👥 Group-based access control integrated with LDAP${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🍪 Secure session management with configurable timeouts${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🏢 Production-ready authentication proxy for enterprises${COLOR_RESET}"
      echo
      echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install OAuth2 Proxy now?${COLOR_RESET}"
      echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install oauth2${COLOR_RESET}"
      ;;
    "oauth2")
      echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: RabbitMQ${COLOR_RESET}"
      echo -e "${COLOR_CYAN}OAuth2 provides authentication - now add RabbitMQ for messaging!${COLOR_RESET}"
      echo
      echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install RabbitMQ next?${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 📨 Reliable message broker for asynchronous communication${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🔗 Decouples services for better scalability and resilience${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 📊 Enables event-driven architecture patterns${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🚀 High-performance messaging for microservices${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🛡️  Secure messaging with authentication and authorization${COLOR_RESET}"
      echo
      echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install RabbitMQ now?${COLOR_RESET}"
      echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install rabbitmq${COLOR_RESET}"
      ;;
    "rabbitmq")
      echo -e "${COLOR_BRIGHT_MAGENTA}${COLOR_BOLD}🎯 Recommended Next Installation: Jenkins${COLOR_RESET}"
      echo -e "${COLOR_CYAN}RabbitMQ provides messaging - now add Jenkins for CI/CD pipelines!${COLOR_RESET}"
      echo
      echo -e "${COLOR_YELLOW}${COLOR_BOLD}Why install Jenkins next?${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🔄 Automated build, test, and deployment pipelines${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 📦 Artifact management and version control integration${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🤖 Extensive plugin ecosystem for diverse tooling${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 📊 Comprehensive monitoring and reporting capabilities${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• 🚀 Scalable architecture for growing development teams${COLOR_RESET}"
      echo
      echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}Install Jenkins now?${COLOR_RESET}"
      echo -e "${COLOR_CYAN}  Command: ${COLOR_BOLD}gok install jenkins${COLOR_RESET}"
      ;;
    *)
      echo -e "${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}📋 Installation Complete${COLOR_RESET}"
      echo -e "${COLOR_CYAN}All core platform components have been installed successfully!${COLOR_RESET}"
      echo
      echo -e "${COLOR_YELLOW}${COLOR_BOLD}Next Steps:${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• Configure your applications to use the installed services${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• Set up monitoring and alerting for production readiness${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• Review security configurations and access policies${COLOR_RESET}"
      echo -e "${COLOR_GREEN}• Test end-to-end functionality of your platform${COLOR_RESET}"
      ;;
  esac
}