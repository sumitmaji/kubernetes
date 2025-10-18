#!/bin/bash

# Eclipse Che Guidance Module

show_che_guidance() {
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📚 Eclipse Che Usage Guide${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🌐 Accessing Eclipse Che:${COLOR_RESET}"
    local che_url=$(kubectl get checluster -n eclipse-che -o jsonpath='{.items[0].status.cheURL}' 2>/dev/null)
    if [[ -n "$che_url" ]]; then
        echo -e "  URL: ${COLOR_GREEN}$che_url${COLOR_RESET}"
        echo -e "  Login via OAuth2/Keycloak authentication"
    else
        echo -e "  ${COLOR_RED}⚠ Che URL not available yet. Wait for deployment to complete.${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_YELLOW}👤 User Authentication:${COLOR_RESET}"
    echo -e "  • Eclipse Che integrates with Keycloak OAuth"
    echo -e "  • Use your Keycloak credentials to log in"
    echo -e "  • First login creates a user namespace automatically"
    
    echo -e "\n${COLOR_YELLOW}💡 Creating Workspaces:${COLOR_RESET}"
    echo -e "  • Use the Che dashboard to create workspaces"
    echo -e "  • Or use the CLI: ${COLOR_CYAN}./gok-new install workspace${COLOR_RESET}"
    echo -e "  • Or manually: ${COLOR_CYAN}./gok-new create-workspace${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🔧 CLI Commands:${COLOR_RESET}"
    echo -e "  Check status:"
    echo -e "    ${COLOR_CYAN}chectl server:status -n eclipse-che${COLOR_RESET}"
    echo -e "  View logs:"
    echo -e "    ${COLOR_CYAN}chectl server:logs -n eclipse-che${COLOR_RESET}"
    echo -e "  Update Che:"
    echo -e "    ${COLOR_CYAN}chectl server:update -n eclipse-che${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🐛 Troubleshooting:${COLOR_RESET}"
    echo -e "  View component summary:"
    echo -e "    ${COLOR_CYAN}./gok-new summary che${COLOR_RESET}"
    echo -e "  Check pod status:"
    echo -e "    ${COLOR_CYAN}kubectl get pods -n eclipse-che${COLOR_RESET}"
    echo -e "  View pod logs:"
    echo -e "    ${COLOR_CYAN}kubectl logs -n eclipse-che <pod-name>${COLOR_RESET}"
    echo -e "  Validate installation:"
    echo -e "    ${COLOR_CYAN}./gok-new validate che${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}📦 Storage:${COLOR_RESET}"
    echo -e "  • Che uses PVCs for persistent storage"
    echo -e "  • Each workspace gets its own PVC"
    echo -e "  • Default storage class is used automatically"
    
    echo -e "\n${COLOR_YELLOW}🔐 Security:${COLOR_RESET}"
    echo -e "  • OAuth2 authentication via Keycloak"
    echo -e "  • TLS certificates from cert-manager/Let's Encrypt"
    echo -e "  • User workspaces isolated in separate namespaces"
    
    echo -e "\n${COLOR_YELLOW}🔄 Reset/Uninstall:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}./gok-new reset che${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_che_guidance
