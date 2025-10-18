#!/bin/bash

# DevWorkspace Guidance Module

show_workspace_guidance() {
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📚 DevWorkspace Usage Guide${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🚀 Creating a DevWorkspace:${COLOR_RESET}"
    echo -e "  Interactive method:"
    echo -e "    ${COLOR_CYAN}./gok-new install workspace${COLOR_RESET}"
    echo -e "  You'll be prompted for:"
    echo -e "    • Namespace (default: che-user)"
    echo -e "    • Username (default: user1)"
    echo -e "    • Workspace name (default: devworkspace1)"
    echo -e "    • Manifest file path (default: devworkspace.yaml)"
    
    echo -e "\n${COLOR_YELLOW}🗑️ Deleting a DevWorkspace:${COLOR_RESET}"
    echo -e "  Interactive method:"
    echo -e "    ${COLOR_CYAN}./gok-new delete-workspace${COLOR_RESET}"
    echo -e "  Manual deletion:"
    echo -e "    ${COLOR_CYAN}kubectl delete devworkspace <name> -n <namespace>${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}📝 DevWorkspace Manifest:${COLOR_RESET}"
    echo -e "  • DevWorkspace manifests define your development environment"
    echo -e "  • Include container images, projects, commands, and volumes"
    echo -e "  • Example location: install_k8s/eclipseche/devworkspace.yaml"
    echo -e "  • Based on devfile.io specification"
    
    echo -e "\n${COLOR_YELLOW}👥 User Namespaces:${COLOR_RESET}"
    echo -e "  • Each user gets a dedicated namespace (e.g., che-user)"
    echo -e "  • Workspaces are isolated within user namespaces"
    echo -e "  • Multiple workspaces per user supported"
    
    echo -e "\n${COLOR_YELLOW}🔍 Viewing Workspaces:${COLOR_RESET}"
    echo -e "  List all workspaces:"
    echo -e "    ${COLOR_CYAN}kubectl get devworkspaces --all-namespaces${COLOR_RESET}"
    echo -e "  View specific workspace:"
    echo -e "    ${COLOR_CYAN}kubectl get devworkspace <name> -n <namespace> -o yaml${COLOR_RESET}"
    echo -e "  Check workspace status:"
    echo -e "    ${COLOR_CYAN}./gok-new summary workspace${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🔧 Workspace Management:${COLOR_RESET}"
    echo -e "  Start a stopped workspace:"
    echo -e "    ${COLOR_CYAN}kubectl patch devworkspace <name> -n <namespace> -p '{\"spec\":{\"started\":true}}' --type=merge${COLOR_RESET}"
    echo -e "  Stop a running workspace:"
    echo -e "    ${COLOR_CYAN}kubectl patch devworkspace <name> -n <namespace> -p '{\"spec\":{\"started\":false}}' --type=merge${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🐛 Troubleshooting:${COLOR_RESET}"
    echo -e "  Validate prerequisites:"
    echo -e "    ${COLOR_CYAN}./gok-new validate workspace${COLOR_RESET}"
    echo -e "  Check workspace pods:"
    echo -e "    ${COLOR_CYAN}kubectl get pods -n <namespace>${COLOR_RESET}"
    echo -e "  View workspace events:"
    echo -e "    ${COLOR_CYAN}kubectl describe devworkspace <name> -n <namespace>${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}📦 Dependencies:${COLOR_RESET}"
    echo -e "  Required:"
    echo -e "    • Eclipse Che (provides DevWorkspace Operator)"
    echo -e "    • python3-kubernetes"
    echo -e "    • python3-yaml"
    echo -e "  Installed via: ${COLOR_CYAN}./gok-new install che${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🌐 Accessing Workspaces:${COLOR_RESET}"
    echo -e "  • Workspaces are accessible via Eclipse Che dashboard"
    echo -e "  • Each workspace gets a unique URL"
    echo -e "  • IDE interface loads in browser"
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_workspace_guidance
