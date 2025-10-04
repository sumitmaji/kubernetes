#!/bin/bash
# GOK Tab Completion Setup
# This file can be sourced independently to enable GOK tab completion
# Usage: source gok-completion.sh

# Self-healing completion function for GOK commands
_gok_enhanced_completion() {
    # Auto-heal: Check if completion is properly registered
    if ! complete -p gok >/dev/null 2>&1; then
        # Silent self-repair - re-register completion
        complete -F _gok_enhanced_completion gok 2>/dev/null || true
    fi
    
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
    
    # Final failsafe: If something went wrong, try basic completion
    if [ ${#COMPREPLY[@]} -eq 0 ]; then
        case ${COMP_CWORD} in
            1)
                # Fallback to basic main commands
                COMPREPLY=($(compgen -W "install reset ingressSummary k8sSummary help" -- ${cur}))
                ;;
        esac
    fi
}

# Auto-healing watchdog - monitors and fixes completion automatically
_gok_completion_watchdog() {
    # Check if the main completion function exists
    if ! type _gok_enhanced_completion >/dev/null 2>&1; then
        # Function missing - this script may have been partially loaded
        return 1
    fi
    
    # Check if completion is registered
    if ! complete -p gok >/dev/null 2>&1; then
        # Re-register silently
        complete -F _gok_enhanced_completion gok 2>/dev/null
    fi
    
    # Verify the registration worked
    if complete -p gok >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Wrapper function that auto-heals before calling the real completion
_gok_auto_healing_completion() {
    # Run watchdog check and auto-repair
    if ! _gok_completion_watchdog; then
        # Emergency fallback - provide basic completion
        local cur="${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=($(compgen -W "install reset ingressSummary k8sSummary help" -- ${cur}))
        return 0
    fi
    
    # Call the main completion function
    _gok_enhanced_completion
}

# Function to ensure completion is properly registered
ensure_gok_completion() {
    # Remove any existing completion to avoid conflicts
    complete -r gok 2>/dev/null || true
    
    # Register the auto-healing completion wrapper
    complete -F _gok_auto_healing_completion gok
    
    # Verify registration
    if complete -p gok >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Enable completion for gok command
if ensure_gok_completion; then
    echo "✅ GOK enhanced tab completion enabled!"
else
    echo "❌ Failed to register GOK completion"
    echo "💡 Try running: complete -F _gok_enhanced_completion gok"
fi
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

# Function to fix completion if it stops working
fix_gok_completion() {
    echo "🔧 Fixing GOK completion..."
    
    # Remove old completion
    complete -r gok 2>/dev/null || true
    
    # Re-register with the function
    if type _gok_enhanced_completion >/dev/null 2>&1; then
        complete -F _gok_enhanced_completion gok
        echo "✅ GOK completion re-registered"
        
        # Test it
        echo "🧪 Testing completion..."
        COMP_WORDS=("gok" "k8sSum")
        COMP_CWORD=1
        COMPREPLY=()
        _gok_enhanced_completion
        
        if [ ${#COMPREPLY[@]} -gt 0 ]; then
            echo "✅ Test passed: gok k8sSum → ${COMPREPLY[@]}"
        else
            echo "❌ Test failed: No completions found"
        fi
    else
        echo "❌ Completion function not found"
        echo "💡 Re-source this file: source gok-completion.sh"
    fi
}

# Create a smart gok alias that ensures completion is always available
# This provides an extra layer of protection
if ! alias gok >/dev/null 2>&1 || [[ "$(alias gok 2>/dev/null)" != *"_gok_background_check"* ]]; then
    # Create an alias that checks completion before running gok
    alias gok='_gok_background_check 2>/dev/null; command gok'
fi

echo ""
echo "🤖 Auto-healing completion enabled - no manual fixes needed!"

# Add a lightweight background check that runs with each prompt
# This ensures completion stays registered across shell sessions
_gok_background_check() {
    # Only check occasionally to avoid performance impact
    if [ $((RANDOM % 20)) -eq 0 ]; then
        if ! complete -p gok >/dev/null 2>&1; then
            # Silent auto-repair
            complete -F _gok_auto_healing_completion gok 2>/dev/null || true
        fi
    fi
}

# Add to PROMPT_COMMAND if not already there
if [[ "$PROMPT_COMMAND" != *"_gok_background_check"* ]]; then
    if [ -n "$PROMPT_COMMAND" ]; then
        export PROMPT_COMMAND="$PROMPT_COMMAND; _gok_background_check"
    else
        export PROMPT_COMMAND="_gok_background_check"
    fi
fi