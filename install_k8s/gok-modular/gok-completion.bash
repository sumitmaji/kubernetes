#!/bin/bash

# GOK Modular System - Bash Completion Script
# This script provides tab completion for the gok-new command

_gok_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="install reset status desc logs bash create generate patch deploy start remote completion cache utils help"
    
    # Infrastructure components
    local infrastructure_components="docker kubernetes kubernetes-worker helm calico ingress"
    
    # Monitoring components
    local monitoring_components="prometheus grafana cadvisor metric-server monitoring heapster"
    
    # Security components
    local security_components="cert-manager keycloak oauth2-proxy vault ldap ldapclient kerberos kerberizedservices"
    
    # Development components
    local development_components="jupyter jupyterhub dashboard ttyd eclipseche cloud-shell console devworkspace workspace che"
    
    # CI/CD components
    local cicd_components="argocd jenkins spinnaker gitlab cicd"
    
    # Storage components
    local storage_components="opensearch rabbitmq kafka postgresql mysql redis"
    
    # Networking components
    local networking_components="istio fluentd calico-network network-policies metallb"
    
    # Registry components
    local registry_components="registry chart-registry harbor nexus registry-stack"
    
    # Platform components
    local platform_components="gok-cloud gok-debug gok-login base base-services all"
    
    # All components combined
    local all_components="$infrastructure_components $monitoring_components $security_components $development_components $cicd_components $storage_components $networking_components $registry_components $platform_components"
    
    # Global options
    local global_opts="--help -h --debug --quiet --verbose -v"
    
    # Install command options
    local install_opts="--verbose -v --force-deps --skip-deps --namespace -n"
    
    # Reset command options
    local reset_opts="--force --all --namespace -n --confirm"
    
    # Status command options
    local status_opts="--format --output -o --watch -w"
    
    case "${prev}" in
        gok-new)
            # Complete main commands
            COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
            return 0
            ;;
        install)
            # Complete component names for install command
            COMPREPLY=( $(compgen -W "${all_components}" -- ${cur}) )
            return 0
            ;;
        reset)
            # Complete component names for reset command
            COMPREPLY=( $(compgen -W "${all_components}" -- ${cur}) )
            return 0
            ;;
        status)
            # Complete component names for status command (optional)
            COMPREPLY=( $(compgen -W "${all_components} ${status_opts}" -- ${cur}) )
            return 0
            ;;
        desc|describe)
            # Complete Kubernetes resource types
            local k8s_resources="pods services deployments configmaps secrets nodes namespaces ingresses"
            COMPREPLY=( $(compgen -W "${k8s_resources}" -- ${cur}) )
            return 0
            ;;
        logs)
            # This would ideally complete with actual pod names, but for now use generic
            COMPREPLY=( $(compgen -W "$(kubectl get pods -o name 2>/dev/null | sed 's/pod\///' 2>/dev/null || echo '')" -- ${cur}) )
            return 0
            ;;
        bash)
            # Complete with pod names for bash command
            COMPREPLY=( $(compgen -W "$(kubectl get pods -o name 2>/dev/null | sed 's/pod\///' 2>/dev/null || echo '')" -- ${cur}) )
            return 0
            ;;
        create|generate)
            # Complete with creation types
            local create_types="deployment service configmap secret ingress namespace"
            COMPREPLY=( $(compgen -W "${create_types}" -- ${cur}) )
            return 0
            ;;
        patch)
            # Complete with patchable resources
            local patch_resources="deployment service configmap secret ingress"
            COMPREPLY=( $(compgen -W "${patch_resources}" -- ${cur}) )
            return 0
            ;;
        deploy)
            # Complete with deployment names
            COMPREPLY=( $(compgen -W "$(kubectl get deployments -o name 2>/dev/null | sed 's/deployment\///' 2>/dev/null || echo '')" -- ${cur}) )
            return 0
            ;;
        --namespace|-n)
            # Complete with available namespaces
            COMPREPLY=( $(compgen -W "$(kubectl get namespaces -o name 2>/dev/null | sed 's/namespace\///' 2>/dev/null || echo 'default kube-system')" -- ${cur}) )
            return 0
            ;;
        --output|-o)
            # Complete with output formats
            COMPREPLY=( $(compgen -W "json yaml table wide" -- ${cur}) )
            return 0
            ;;
        --format)
            # Complete with format options
            COMPREPLY=( $(compgen -W "table json yaml summary" -- ${cur}) )
            return 0
            ;;
    esac
    
    # Handle component-specific options
    local component=""
    local command=""
    
    # Find the command and component in the current command line
    for (( i=1; i<${#COMP_WORDS[@]}; i++ )); do
        case "${COMP_WORDS[i]}" in
            install|reset|status|desc|logs|bash|create|generate|patch|deploy|start|remote|completion|cache|utils|help)
                command="${COMP_WORDS[i]}"
                if [[ $i -lt $((${#COMP_WORDS[@]}-1)) ]]; then
                    component="${COMP_WORDS[i+1]}"
                fi
                break
                ;;
        esac
    done
    
    # Provide command-specific completions
    case "${command}" in
        install)
            case "${component}" in
                prometheus|grafana|monitoring)
                    COMPREPLY=( $(compgen -W "${install_opts} --values --set --wait --timeout" -- ${cur}) )
                    ;;
                kubernetes|k8s)
                    COMPREPLY=( $(compgen -W "${install_opts} --master --worker --version" -- ${cur}) )
                    ;;
                docker)
                    COMPREPLY=( $(compgen -W "${install_opts} --version --ce --ee" -- ${cur}) )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "${install_opts}" -- ${cur}) )
                    ;;
            esac
            ;;
        reset)
            COMPREPLY=( $(compgen -W "${reset_opts}" -- ${cur}) )
            ;;
        status)
            COMPREPLY=( $(compgen -W "${status_opts}" -- ${cur}) )
            ;;
    esac
    
    # If no completion found yet, try global options
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        COMPREPLY=( $(compgen -W "${global_opts}" -- ${cur}) )
    fi
}

# Function to generate completion script for different shells
generate_completion() {
    local shell_type="${1:-bash}"
    
    case "$shell_type" in
        bash)
            cat << 'EOF'
# GOK Modular System - Bash Completion
# Add this to your ~/.bashrc or source it directly:
# source /path/to/gok-completion.bash

_gok_completion() {
    # ... (completion function content) ...
}

# Register the completion function
complete -F _gok_completion gok-new
complete -F _gok_completion ./gok-new
EOF
            ;;
        zsh)
            cat << 'EOF'
# GOK Modular System - Zsh Completion
# Add this to your ~/.zshrc or place in your zsh completions directory

#compdef gok-new

_gok_new() {
    local context state line
    
    _arguments \
        '1:command:(install reset status desc logs bash create generate patch deploy start remote completion cache utils help)' \
        '*::arg:->args'
    
    case $state in
        args)
            case $words[2] in
                install|reset)
                    _arguments \
                        '*:component:(docker kubernetes helm calico ingress prometheus grafana monitoring dashboard jupyter jenkins argocd vault keycloak registry opensearch rabbitmq istio all base)'
                    ;;
                status)
                    _arguments \
                        '::component:(docker kubernetes helm calico ingress prometheus grafana monitoring dashboard jupyter jenkins argocd vault keycloak registry opensearch rabbitmq istio)' \
                        '--format[output format]:format:(table json yaml)' \
                        '--output[output type]:output:(json yaml table wide)'
                    ;;
                desc|logs|bash)
                    _arguments \
                        '*:resource:_command_names'
                    ;;
            esac
            ;;
    esac
}

_gok_new "$@"
EOF
            ;;
        fish)
            cat << 'EOF'
# GOK Modular System - Fish Completion
# Place in ~/.config/fish/completions/gok-new.fish

# Main commands
complete -c gok-new -n '__fish_use_subcommand' -a 'install' -d 'Install components'
complete -c gok-new -n '__fish_use_subcommand' -a 'reset' -d 'Reset/uninstall components'
complete -c gok-new -n '__fish_use_subcommand' -a 'status' -d 'Show component status'
complete -c gok-new -n '__fish_use_subcommand' -a 'desc' -d 'Describe resources'
complete -c gok-new -n '__fish_use_subcommand' -a 'logs' -d 'Show logs'
complete -c gok-new -n '__fish_use_subcommand' -a 'bash' -d 'Open shell in pod'
complete -c gok-new -n '__fish_use_subcommand' -a 'help' -d 'Show help'

# Components for install/reset
set -l components docker kubernetes helm calico ingress prometheus grafana monitoring dashboard jupyter jenkins argocd vault keycloak registry opensearch rabbitmq istio all base

complete -c gok-new -n '__fish_seen_subcommand_from install reset' -a "$components"

# Global options
complete -c gok-new -l help -s h -d 'Show help'
complete -c gok-new -l debug -d 'Enable debug output'
complete -c gok-new -l quiet -d 'Suppress non-error output'
complete -c gok-new -l verbose -s v -d 'Enable verbose output'

# Install options
complete -c gok-new -n '__fish_seen_subcommand_from install' -l namespace -s n -d 'Target namespace'
complete -c gok-new -n '__fish_seen_subcommand_from install' -l force-deps -d 'Force dependency installation'
complete -c gok-new -n '__fish_seen_subcommand_from install' -l skip-deps -d 'Skip dependency checks'
EOF
            ;;
    esac
}

# Install completion for the current shell
install_completion() {
    local shell_type="${1:-bash}"
    local install_path=""
    
    case "$shell_type" in
        bash)
            # Try different possible locations for bash completions
            if [[ -d "/etc/bash_completion.d" ]]; then
                install_path="/etc/bash_completion.d/gok-new"
            elif [[ -d "/usr/local/etc/bash_completion.d" ]]; then
                install_path="/usr/local/etc/bash_completion.d/gok-new"
            elif [[ -d "${HOME}/.local/share/bash-completion/completions" ]]; then
                install_path="${HOME}/.local/share/bash-completion/completions/gok-new"
                mkdir -p "$(dirname "$install_path")"
            else
                install_path="${HOME}/.gok-completion.bash"
            fi
            ;;
        zsh)
            # Get zsh completion directory
            if [[ -d "/usr/local/share/zsh/site-functions" ]]; then
                install_path="/usr/local/share/zsh/site-functions/_gok-new"
            elif [[ -d "${HOME}/.local/share/zsh/site-functions" ]]; then
                install_path="${HOME}/.local/share/zsh/site-functions/_gok-new"
                mkdir -p "$(dirname "$install_path")"
            else
                install_path="${HOME}/.gok-completion.zsh"
            fi
            ;;
        fish)
            install_path="${HOME}/.config/fish/completions/gok-new.fish"
            mkdir -p "$(dirname "$install_path")"
            ;;
    esac
    
    if [[ -n "$install_path" ]]; then
        generate_completion "$shell_type" > "$install_path"
        echo "Completion installed to: $install_path"
        
        case "$shell_type" in
            bash)
                if [[ "$install_path" == *".gok-completion.bash" ]]; then
                    echo "Add this line to your ~/.bashrc:"
                    echo "source $install_path"
                fi
                ;;
            zsh)
                if [[ "$install_path" == *".gok-completion.zsh" ]]; then
                    echo "Add this line to your ~/.zshrc:"
                    echo "source $install_path"
                fi
                echo "You may need to run: compinit"
                ;;
            fish)
                echo "Fish completion installed. Restart your shell or run: source $install_path"
                ;;
        esac
    fi
}

# Main completion function - register with bash
complete -F _gok_completion gok-new
complete -F _gok_completion ./gok-new

# If script is run directly, install completion
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        install)
            install_completion "${2:-bash}"
            ;;
        generate)
            generate_completion "${2:-bash}"
            ;;
        bash|zsh|fish)
            generate_completion "$1"
            ;;
        *)
            echo "GOK Modular System - Command Completion"
            echo ""
            echo "Usage:"
            echo "  $0 install [bash|zsh|fish]    Install completion for shell"
            echo "  $0 generate [bash|zsh|fish]   Generate completion script"
            echo ""
            echo "Or source this file directly for bash completion:"
            echo "  source $0"
            ;;
    esac
fi