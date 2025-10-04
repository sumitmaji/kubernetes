#!/bin/bash
# GOK Tab Completion Setup
# This file can be sourced independently to enable GOK tab completion
# Usage: source gok-completion.sh

# Simple word-based completion for GOK commands
_gok_simple_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands="install fix reset start deploy patch create generate bash desc logs status taint-node k8sSummary ingressSummary ingressReset certManagerReset prometheusGrafanaReset dashboardReset vaultReset cloudshellReset consoleReset jupyterHubReset ttydReset resetChart jenkinsReset oauth2ProxyReset kyvernoReset k8sInst k8sReset calicoInst dnsUtils kcurl customDns oauthAdmin checkDns checkCurl completion help"
    
    COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
    return 0
}

# Enable completion for gok command
complete -F _gok_simple_completion gok

echo "✅ GOK tab completion enabled!"
echo "💡 Now you can use:"
echo "   gok ingr<TAB>       # Completes to ingressSummary/ingressReset"
echo "   gok cert<TAB>       # Completes to certManagerReset"  
echo "   gok install <TAB>   # Shows installable components (basic)"
echo ""
echo "🔧 Test it: Try typing 'gok ingr' and press TAB"