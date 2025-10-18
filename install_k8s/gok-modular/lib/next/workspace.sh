#!/bin/bash

# DevWorkspace Next Module - Provides recommendations after workspace creation

get_workspace_next_component() {
    # Workspace is typically the end of the development setup path
    # Could suggest monitoring or other operational tools
    echo ""
}

get_workspace_next_rationale() {
    cat <<EOF
${COLOR_GREEN}✅ Development environment is ready!${COLOR_RESET}

${COLOR_YELLOW}Next steps:${COLOR_RESET}
  • Access Eclipse Che dashboard and open your workspace
  • Start coding in the browser-based IDE
  • Create additional workspaces for different projects
  • Invite team members to collaborate

${COLOR_YELLOW}Optional enhancements:${COLOR_RESET}
  • ${COLOR_CYAN}monitoring${COLOR_RESET} - Monitor workspace resource usage
  • ${COLOR_CYAN}argocd${COLOR_RESET} - Set up GitOps workflows for deployments

${COLOR_CYAN}Happy coding! 🚀${COLOR_RESET}
EOF
}

export -f get_workspace_next_component
export -f get_workspace_next_rationale
