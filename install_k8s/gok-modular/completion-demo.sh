#!/bin/bash

# GOK-NEW Tab Completion Demo & Installation Guide
# Complete setup and usage guide for tab completion

echo "🚀 GOK-NEW Tab Completion System"
echo "================================="
echo ""
echo "This guide will help you set up and use the comprehensive tab completion system for gok-new."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}$1${NC}"
    echo "$(echo "$1" | sed 's/./-/g')"
}

print_command() {
    echo -e "${CYAN}$ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}💡 $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check current status
print_header "Current Status"

if complete -p gok-new >/dev/null 2>&1; then
    print_success "Tab completion is currently active in this session"
    echo "   Registration: $(complete -p gok-new)"
else
    print_error "Tab completion is not active in this session"
fi

if grep -q "gok-completion.bash" ~/.bashrc 2>/dev/null; then
    print_success "Completion is installed in ~/.bashrc"
else
    echo "   Completion not permanently installed"
fi

echo ""

print_header "Installation Options"

echo "1. Install permanently (recommended):"
print_command "gok-new completion install"
echo ""

echo "2. Source for current session only:"
print_command "source ./gok-completion.bash"
echo ""

echo "3. Manual installation to ~/.bashrc:"
print_command "echo 'source $(pwd)/gok-completion.bash' >> ~/.bashrc"
echo ""

print_header "Multi-Level Completion Examples"
echo ""

echo "🎯 Level 1 - Main Commands:"
print_command "gok-new <TAB><TAB>"
echo "   Shows: install, reset, remote, exec, status, create, generate, etc."
echo ""

echo "🎯 Level 2 - Command-Specific Options:"
print_command "gok-new install <TAB><TAB>"
echo "   Shows: docker, kubernetes, prometheus, grafana, cert-manager, etc."
echo ""

print_command "gok-new remote <TAB><TAB>"
echo "   Shows: setup, add, list, copy, exec, status, test-connection, etc."
echo ""

print_command "gok-new create <TAB><TAB>"
echo "   Shows: user, namespace, deployment, service, configmap, etc."
echo ""

echo "🎯 Level 3 - Parameter Completion:"
print_command "gok-new remote setup <TAB><TAB>"
echo "   Suggests: hostname/IP input"
echo ""

print_command "gok-new remote setup 192.168.1.100 <TAB><TAB>"
echo "   Shows: root, ubuntu, centos, admin"
echo ""

print_command "gok-new completion <TAB><TAB>"
echo "   Shows: bash, zsh, fish, install, uninstall, status, help"
echo ""

echo "🎯 Level 4 - Advanced Context:"
print_command "gok-new remote setup 192.168.1.100 ubuntu <TAB><TAB>"
echo "   Shows: SSH key file paths"
echo ""

print_command "gok-new remote setup 192.168.1.100 ubuntu ~/.ssh/id_rsa <TAB><TAB>"
echo "   Shows: always, auto, never (sudo modes)"
echo ""

print_header "Smart Context-Aware Features"
echo ""

echo "🧠 Dynamic Remote Host Completion:"
echo "   After configuring remote hosts, they appear in exec completions"
print_command "gok-new exec <TAB><TAB>"
echo "   Shows: all, master, node1, worker2 (your configured hosts)"
echo ""

echo "🧠 Kubernetes Resource Completion:"
print_command "gok-new logs <TAB><TAB>"
echo "   Shows: actual pod names from kubectl (if available)"
echo ""

echo "🧠 File Path Completion:"
print_command "gok-new remote copy <TAB><TAB>"
echo "   Shows: local files and directories"
echo ""

print_header "Installation Test"
echo ""

# Test if we can install completion
if [[ -f "./gok-completion.bash" ]]; then
    print_success "Completion script found: ./gok-completion.bash"
    
    echo ""
    print_info "Testing completion installation..."
    
    # Show what the install command would do
    echo ""
    echo "The install command will:"
    echo "  1. Add source line to ~/.bashrc"
    echo "  2. Load completion for current session"
    echo "  3. Enable system-wide installation if possible"
    
    echo ""
    read -p "Would you like to install completion now? (y/N): " choice
    
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        print_command "./gok-new completion install"
        ./gok-new completion install
    else
        print_info "You can install later with: ./gok-new completion install"
    fi
else
    print_error "Completion script not found. Please ensure gok-completion.bash exists."
fi

print_header "Usage Tips"
echo ""

echo "💡 Completion Tips:"
echo "   • Press TAB once to complete if there's only one match"
echo "   • Press TAB twice to see all available options"
echo "   • Start typing and press TAB to filter completions"
echo "   • Use spaces properly: 'gok-new install <TAB>' not 'gok-newinstall<TAB>'"
echo ""

echo "🔧 Troubleshooting:"
echo "   • If completion doesn't work, restart your terminal"
echo "   • Check installation: gok-new completion status"
echo "   • Reload manually: source ~/.bashrc"
echo "   • For debugging: set COMP_DEBUG=1"
echo ""

echo "📚 Command Categories:"
echo "   • Infrastructure: docker, kubernetes, helm, ingress"
echo "   • Monitoring: prometheus, grafana, heapster"
echo "   • Security: cert-manager, keycloak, vault, ldap"
echo "   • Development: jupyter, dashboard, console"
echo "   • CI/CD: argocd, jenkins, spinnaker"
echo "   • Remote: setup, exec, copy, status"
echo ""

print_header "Quick Reference"
echo ""

echo "📖 Most Useful Completions:"
echo ""
print_command "gok-new <TAB><TAB>                    # All commands"
print_command "gok-new install <TAB><TAB>            # All components"
print_command "gok-new remote <TAB><TAB>             # Remote operations"
print_command "gok-new remote setup <host> <TAB>     # Usernames"
print_command "gok-new exec <TAB><TAB>               # Remote hosts"
print_command "gok-new completion <TAB><TAB>         # Completion actions"
print_command "gok-new status <TAB><TAB>             # Status types"
print_command "gok-new create <TAB><TAB>             # Resource types"
echo ""

print_success "Tab completion setup guide complete!"
print_info "Try the completions in your terminal now!"