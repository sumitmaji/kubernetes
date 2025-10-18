#!/bin/bash

# Eclipse Che Next Module - Provides next component recommendations after Che installation

get_che_next_component() {
    echo "workspace"
}

get_che_next_rationale() {
    cat <<EOF
${COLOR_YELLOW}Why workspace?${COLOR_RESET}
Eclipse Che provides the platform for cloud-based development environments.
The next logical step is to create DevWorkspaces where developers can actually
work on their projects. DevWorkspaces provide:
  • Isolated development environments per user/project
  • Pre-configured development containers
  • Integrated IDE experience in the browser
  • Persistent storage for project files
  • Collaborative development capabilities

${COLOR_CYAN}Create your first workspace to start developing!${COLOR_RESET}
EOF
}

export -f get_che_next_component
export -f get_che_next_rationale
