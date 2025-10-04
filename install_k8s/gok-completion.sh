#!/bin/bash
# GOK Tab Completion Setup
# This file can be sourced independently to enable GOK tab completion
# Usage: source gok-completion.sh

# Enhanced completion function for GOK commands
_gok_enhanced_completion() {
    local cur prev opts base
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="install fix reset start deploy patch create generate bash desc logs status taint-node k8sSummary ingressSummary ingressReset certManagerReset prometheusGrafanaReset dashboardReset vaultReset cloudshellReset consoleReset jupyterHubReset ttydReset resetChart jenkinsReset oauth2ProxyReset kyvernoReset k8sInst k8sReset calicoInst dnsUtils kcurl customDns oauthAdmin checkDns checkCurl completion help"
    
    # Install components
    local install_components="docker helm kubernetes kubernetes-worker cert-manager ingress dashboard monitoring fluentd opensearch keycloak oauth2 vault ldap jupyter devworkspace workspace che ttyd cloudshell console argocd jenkins spinnaker registry istio rabbitmq kyverno gok-agent gok-controller controller gok-login chart base base-services"
    
    # Reset components  
    local reset_components="kubernetes kubernetes-worker cert-manager ingress dashboard monitoring fluentd opensearch keycloak oauth2 vault ldap jupyter devworkspace workspace che ttyd cloudshell console argocd jenkins spinnaker registry istio rabbitmq kyverno gok-agent gok-controller controller gok-login chart base-services"
    
    # Start components
    local start_components="kubernetes proxy kubelet"
    
    # Create resources
    local create_resources="secret certificate kubeconfig"
    
    # Generate service types
    local generate_types="python-api python-reactjs"
    
    # Patch resources
    local patch_resources="ingress"
    
    case ${COMP_CWORD} in
        1)
            # First argument - complete main commands
            COMPREPLY=($(compgen -W "${commands}" -- ${cur}))
            return 0
            ;;
        2)
            # Second argument - complete based on first command
            case ${prev} in
                install)
                    COMPREPLY=($(compgen -W "${install_components}" -- ${cur}))
                    return 0
                    ;;
                reset)
                    COMPREPLY=($(compgen -W "${reset_components}" -- ${cur}))
                    return 0
                    ;;
                start)
                    COMPREPLY=($(compgen -W "${start_components}" -- ${cur}))
                    return 0
                    ;;
                create)
                    COMPREPLY=($(compgen -W "${create_resources}" -- ${cur}))
                    return 0
                    ;;
                generate)
                    COMPREPLY=($(compgen -W "${generate_types}" -- ${cur}))
                    return 0
                    ;;
                patch)
                    COMPREPLY=($(compgen -W "${patch_resources}" -- ${cur}))
                    return 0
                    ;;
                completion)
                    COMPREPLY=($(compgen -W "enable setup quick standalone" -- ${cur}))
                    return 0
                    ;;
                *)
                    # No specific completion for other commands
                    return 0
                    ;;
            esac
            ;;
        *)
            # For 3+ arguments, provide basic flags
            COMPREPLY=($(compgen -W "--verbose -v --help -h" -- ${cur}))
            return 0
            ;;
    esac
}

# Enable completion for gok command
complete -F _gok_enhanced_completion gok

echo "✅ GOK enhanced tab completion enabled!"
echo "💡 Full two-level completion now available:"
echo ""
echo "📋 Main Commands:"
echo "   gok ingr<TAB>           # ingressSummary, ingressReset"
echo "   gok k8s<TAB>            # k8sSummary, k8sInst, k8sReset"
echo "   gok cert<TAB>           # certManagerReset"
echo ""
echo "🚀 Install Components:"
echo "   gok install kub<TAB>    # kubernetes, kubernetes-worker"
echo "   gok install cert<TAB>   # cert-manager"
echo "   gok install mon<TAB>    # monitoring"
echo "   gok install jen<TAB>    # jenkins"
echo ""
echo "🔄 Reset Components:"
echo "   gok reset ingr<TAB>     # ingress"
echo "   gok reset kub<TAB>      # kubernetes, kubernetes-worker"
echo ""
echo "📦 Other Commands:"
echo "   gok create cert<TAB>    # certificate"
echo "   gok generate py<TAB>    # python-api, python-reactjs"
echo ""
echo "🔧 Test it: Try 'gok install kub<TAB>' - should show kubernetes options!"