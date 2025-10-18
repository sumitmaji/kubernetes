#!/bin/bash

# DevWorkspace V2 Guidance Module

show_workspacev2_guidance() {
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📚 DevWorkspace V2 Usage Guide${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🚀 Creating a DevWorkspace V2:${COLOR_RESET}"
    echo -e "  Interactive method with template selection:"
    echo -e "    ${COLOR_CYAN}./gok-new install workspacev2${COLOR_RESET}"
    echo -e "  Or use the direct command:"
    echo -e "    ${COLOR_CYAN}./gok-new create-workspace-v2${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}📋 Available Workspace Templates:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}1. core-java${COLOR_RESET}"
    echo -e "     • Pure Java development environment"
    echo -e "     • JDK, Maven, Gradle pre-installed"
    echo -e "     • Ideal for core Java projects"
    
    echo -e "\n  ${COLOR_CYAN}2. springboot-web${COLOR_RESET}"
    echo -e "     • Spring Boot web application development"
    echo -e "     • Spring Framework, Tomcat embedded"
    echo -e "     • Perfect for building web services"
    
    echo -e "\n  ${COLOR_CYAN}3. python-web${COLOR_RESET}"
    echo -e "     • Python web development"
    echo -e "     • Flask, Django support"
    echo -e "     • Python 3.x environment"
    
    echo -e "\n  ${COLOR_CYAN}4. springboot-backend${COLOR_RESET}"
    echo -e "     • Spring Boot backend microservices"
    echo -e "     • RESTful API development"
    echo -e "     • Database integration ready"
    
    echo -e "\n  ${COLOR_CYAN}5. tensorflow${COLOR_RESET}"
    echo -e "     • Machine Learning with TensorFlow"
    echo -e "     • Jupyter notebooks included"
    echo -e "     • GPU support (if available)"
    
    echo -e "\n  ${COLOR_CYAN}6. microservice-study${COLOR_RESET}"
    echo -e "     • Microservices architecture patterns"
    echo -e "     • Service mesh examples"
    echo -e "     • Container orchestration study"
    
    echo -e "\n  ${COLOR_CYAN}7. javaparser${COLOR_RESET}"
    echo -e "     • Java code parsing and analysis"
    echo -e "     • AST manipulation tools"
    echo -e "     • Code generation utilities"
    
    echo -e "\n  ${COLOR_CYAN}8. nlp${COLOR_RESET}"
    echo -e "     • Natural Language Processing"
    echo -e "     • NLTK, spaCy, transformers"
    echo -e "     • Text analysis and modeling"
    
    echo -e "\n  ${COLOR_CYAN}9. kubeauthentication${COLOR_RESET}"
    echo -e "     • Kubernetes authentication mechanisms"
    echo -e "     • RBAC, ServiceAccounts study"
    echo -e "     • Security best practices"
    
    echo -e "\n${COLOR_YELLOW}🗑️ Deleting a DevWorkspace V2:${COLOR_RESET}"
    echo -e "  Interactive deletion:"
    echo -e "    ${COLOR_CYAN}./gok-new delete-workspace-v2${COLOR_RESET}"
    echo -e "  Or use reset command:"
    echo -e "    ${COLOR_CYAN}./gok-new reset workspacev2${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🔍 Viewing Workspace Status:${COLOR_RESET}"
    echo -e "  Check all workspaces:"
    echo -e "    ${COLOR_CYAN}kubectl get devworkspaces --all-namespaces${COLOR_RESET}"
    echo -e "  View specific workspace:"
    echo -e "    ${COLOR_CYAN}kubectl get devworkspace <name> -n <username> -o yaml${COLOR_RESET}"
    echo -e "  Check workspace summary:"
    echo -e "    ${COLOR_CYAN}./gok-new summary workspacev2${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}🔧 Workspace Management:${COLOR_RESET}"
    echo -e "  Start a stopped workspace:"
    echo -e "    ${COLOR_CYAN}kubectl patch devworkspace <name> -n <username> \\${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}  -p '{\"spec\":{\"started\":true}}' --type=merge${COLOR_RESET}"
    
    echo -e "\n  Stop a running workspace:"
    echo -e "    ${COLOR_CYAN}kubectl patch devworkspace <name> -n <username> \\${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}  -p '{\"spec\":{\"started\":false}}' --type=merge${COLOR_RESET}"
    
    echo -e "\n  View workspace logs:"
    echo -e "    ${COLOR_CYAN}kubectl logs -n <username> -l controller.devfile.io/devworkspace_name=<name>${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}👥 User Namespace Management:${COLOR_RESET}"
    echo -e "  • Each user gets their own namespace"
    echo -e "  • Namespace name matches the username"
    echo -e "  • Multiple workspace templates per user supported"
    echo -e "  • Workspaces are isolated by namespace"
    
    echo -e "\n${COLOR_YELLOW}🌐 Accessing Workspaces:${COLOR_RESET}"
    echo -e "  • Access via Eclipse Che dashboard"
    echo -e "  • Each workspace gets a unique URL"
    echo -e "  • Browser-based IDE with full functionality"
    echo -e "  • Persistent storage for all files"
    
    echo -e "\n${COLOR_YELLOW}💾 Workspace Persistence:${COLOR_RESET}"
    echo -e "  • All workspace data is persisted"
    echo -e "  • PVCs created automatically per workspace"
    echo -e "  • Data survives workspace restarts"
    echo -e "  • Backup important data regularly"
    
    echo -e "\n${COLOR_YELLOW}🐛 Troubleshooting:${COLOR_RESET}"
    echo -e "  Validate prerequisites:"
    echo -e "    ${COLOR_CYAN}./gok-new validate workspacev2${COLOR_RESET}"
    
    echo -e "\n  Check workspace pods:"
    echo -e "    ${COLOR_CYAN}kubectl get pods -n <username>${COLOR_RESET}"
    
    echo -e "\n  View workspace events:"
    echo -e "    ${COLOR_CYAN}kubectl describe devworkspace <name> -n <username>${COLOR_RESET}"
    
    echo -e "\n  Check DevWorkspace Operator logs:"
    echo -e "    ${COLOR_CYAN}kubectl logs -n eclipse-che -l app.kubernetes.io/name=devworkspace-controller${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}📦 Dependencies:${COLOR_RESET}"
    echo -e "  Required components:"
    echo -e "    • Eclipse Che (provides DevWorkspace Operator)"
    echo -e "    • python3-kubernetes"
    echo -e "    • python3-yaml"
    echo -e "    • Kubernetes cluster with storage provisioner"
    
    echo -e "\n  Install Che first:"
    echo -e "    ${COLOR_CYAN}./gok-new install che${COLOR_RESET}"
    
    echo -e "\n${COLOR_YELLOW}⚡ Best Practices:${COLOR_RESET}"
    echo -e "  • Choose the right template for your project"
    echo -e "  • Stop workspaces when not in use to save resources"
    echo -e "  • Use meaningful usernames for easy identification"
    echo -e "  • Regularly backup important workspace data"
    echo -e "  • Monitor workspace resource usage"
    echo -e "  • Delete unused workspaces to free up resources"
    
    echo -e "\n${COLOR_YELLOW}🔗 Workflow Example:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} Install Eclipse Che: ${COLOR_CYAN}./gok-new install che${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} Create workspace: ${COLOR_CYAN}./gok-new create-workspace-v2${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} Select template (e.g., springboot-web)"
    echo -e "  ${COLOR_CYAN}4.${COLOR_RESET} Access Che dashboard and start coding"
    echo -e "  ${COLOR_CYAN}5.${COLOR_RESET} Stop workspace when done"
    echo -e "  ${COLOR_CYAN}6.${COLOR_RESET} Delete when project complete"
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_workspacev2_guidance
