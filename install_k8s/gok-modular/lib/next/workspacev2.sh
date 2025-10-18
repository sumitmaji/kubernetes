#!/bin/bash

# DevWorkspace V2 Next Module - Provides recommendations after workspace creation

get_workspacev2_next_component() {
    # WorkspaceV2 is typically the end of the development setup path
    # Could suggest monitoring or other operational tools
    echo ""
}

get_workspacev2_next_rationale() {
    cat <<EOF
${COLOR_GREEN}✅ Template-based development environment is ready!${COLOR_RESET}

${COLOR_YELLOW}Your DevWorkspace V2 Setup:${COLOR_RESET}
  • Template-based workspace created with pre-configured tools
  • Access Eclipse Che dashboard to start development
  • Multiple workspace templates available for different projects
  • Isolated environments per user and project type

${COLOR_YELLOW}Next steps for development:${COLOR_RESET}
  • ${COLOR_CYAN}Access Che Dashboard${COLOR_RESET} - Open your workspace in the browser
  • ${COLOR_CYAN}Clone your project${COLOR_RESET} - Import code from Git repositories
  • ${COLOR_CYAN}Start coding${COLOR_RESET} - Use the browser-based IDE
  • ${COLOR_CYAN}Create more workspaces${COLOR_RESET} - Try different templates for various projects

${COLOR_YELLOW}Create additional workspaces:${COLOR_RESET}
  • ${COLOR_CYAN}./gok-new create-workspace-v2${COLOR_RESET} - Create another workspace with different template
  • ${COLOR_CYAN}./gok-new summary workspacev2${COLOR_RESET} - View all your workspaces

${COLOR_YELLOW}Optional platform enhancements:${COLOR_RESET}
  • ${COLOR_CYAN}monitoring${COLOR_RESET} - Monitor workspace resource usage and performance
  • ${COLOR_CYAN}argocd${COLOR_RESET} - Set up GitOps workflows for deployments
  • ${COLOR_CYAN}jenkins${COLOR_RESET} - Add CI/CD pipelines for your projects

${COLOR_YELLOW}Template options available:${COLOR_RESET}
  • ${COLOR_CYAN}core-java${COLOR_RESET} - Pure Java development
  • ${COLOR_CYAN}springboot-web${COLOR_RESET} - Web applications with Spring Boot
  • ${COLOR_CYAN}python-web${COLOR_RESET} - Python web development
  • ${COLOR_CYAN}tensorflow${COLOR_RESET} - Machine Learning projects
  • ${COLOR_CYAN}microservice-study${COLOR_RESET} - Microservices architecture
  • ${COLOR_CYAN}nlp${COLOR_RESET} - Natural Language Processing
  • And more...

${COLOR_CYAN}Happy coding with your template-based workspace! 🚀${COLOR_RESET}
EOF
}

export -f get_workspacev2_next_component
export -f get_workspacev2_next_rationale
