#!/bin/bash

# GOK-NEW Bash Completion
# Provides intelligent multi-level tab completion for gok-new commands and subcommands
# 
# Installation:
#   1. Source this file in your shell: source gok-completion.bash
#   2. Or add to ~/.bashrc: source /path/to/gok-completion.bash
#   3. Or install system-wide: sudo cp gok-completion.bash /etc/bash_completion.d/

_gok_completion() {
    local cur prev words cword split
    _init_completion -s || return

    # Get current word position and words
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD

    # Main commands available in gok-new
    local main_commands="
        install reset start deploy patch create generate status
        desc describe logs bash shell exec remote completion
        cache taint-node checkDns checkCurl help
    "

    # Infrastructure components
    local infrastructure_components="docker kubernetes kubernetes-worker helm calico ingress cluster master node tools k8s"
    
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
    
    # All components combined for install/reset
    local install_components="$infrastructure_components $monitoring_components $security_components $development_components $cicd_components $storage_components $networking_components $registry_components $platform_components"
    
    # Reset components (includes 'all')
    local reset_components="$install_components all"

    # Remote command subcommands
    local remote_subcommands="
        setup add list show exec copy status install-gok
        setup-ssh setup-keys copy-key setup-sudo
        passwordless-sudo test-connection help
    "

    # Create command types
    local create_types="
        user namespace deployment service configmap
        secret ingress certificate pv pvc
    "

    # Generate command types  
    local generate_types="
        cert certificate key token config
        manifest template chart
    "

    # Patch command types
    local patch_types="
        ingress cert-letsencrypt ldap-secure dns
    "

    # Status command types
    local status_types="
        cluster nodes pods services deployments
        ingress certificates system all
    "

    # Global options
    local global_opts="--help -h --debug --quiet --verbose -v"
    
    # Install command options
    local install_opts="--verbose -v --force-deps --skip-deps --namespace -n"
    
    # Reset command options
    local reset_opts="--force --all --namespace -n --confirm"
    
    # Status command options
    local status_opts="--format --output -o --watch -w"
    
    # Completion logic based on position and previous word
    case $cword in
        1)
            # First argument: complete main commands
            COMPREPLY=($(compgen -W "$main_commands" -- "$cur"))
            ;;
        2)
            # Second argument: complete based on first command
            case "${words[1]}" in
                "install")
                    COMPREPLY=($(compgen -W "$install_components" -- "$cur"))
                    ;;
                "reset"|"uninstall")
                    COMPREPLY=($(compgen -W "$reset_components" -- "$cur"))
                    ;;
                "remote")
                    COMPREPLY=($(compgen -W "$remote_subcommands" -- "$cur"))
                    ;;
                "create")
                    COMPREPLY=($(compgen -W "$create_types" -- "$cur"))
                    ;;
                "generate")
                    COMPREPLY=($(compgen -W "$generate_types" -- "$cur"))
                    ;;
                "patch")
                    COMPREPLY=($(compgen -W "$patch_types" -- "$cur"))
                    ;;
                "status")
                    COMPREPLY=($(compgen -W "$status_types" -- "$cur"))
                    ;;
                "desc"|"describe")
                    COMPREPLY=($(compgen -W "pod service deployment ingress node namespace configmap secret" -- "$cur"))
                    ;;
                "logs")
                    # Complete with pod names if kubectl is available
                    if command -v kubectl >/dev/null 2>&1; then
                        local pods=$(kubectl get pods --no-headers 2>/dev/null | awk '{print $1}')
                        COMPREPLY=($(compgen -W "$pods" -- "$cur"))
                    fi
                    ;;
                "bash"|"shell")
                    # Complete with pod names if kubectl is available
                    if command -v kubectl >/dev/null 2>&1; then
                        local pods=$(kubectl get pods --no-headers 2>/dev/null | awk '{print $1}')
                        COMPREPLY=($(compgen -W "$pods" -- "$cur"))
                    fi
                    ;;
                "exec")
                    # For exec, we can complete with configured remote aliases or direct commands
                    local exec_targets="all"
                    
                    # Try to load remote configuration for aliases
                    local gok_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                    local remote_config="${gok_root}/.config/remote-hosts"
                    if [[ -f "$remote_config" ]]; then
                        local aliases=$(grep "^HOST_" "$remote_config" 2>/dev/null | sed 's/^HOST_\([^=]*\)=.*/\1/')
                        exec_targets="$exec_targets $aliases"
                    fi
                    
                    COMPREPLY=($(compgen -W "$exec_targets" -- "$cur"))
                    ;;
                "completion")
                    COMPREPLY=($(compgen -W "bash zsh fish install uninstall" -- "$cur"))
                    ;;
                "cache")
                    COMPREPLY=($(compgen -W "clear refresh status" -- "$cur"))
                    ;;
                "taint-node")
                    # Complete with node names if kubectl is available
                    if command -v kubectl >/dev/null 2>&1; then
                        local nodes=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}')
                        COMPREPLY=($(compgen -W "$nodes" -- "$cur"))
                    fi
                    ;;
                "help")
                    COMPREPLY=($(compgen -W "$main_commands" -- "$cur"))
                    ;;
            esac
            ;;
        3)
            # Third argument: complete based on first two commands
            case "${words[1]}" in
                "remote")
                    case "${words[2]}" in
                        "setup")
                            # After 'gok-new remote setup', expect hostname/IP
                            COMPREPLY=()
                            ;;
                        "add")
                            # After 'gok-new remote add', expect alias name
                            COMPREPLY=()
                            ;;
                        "copy")
                            # Complete with local files
                            COMPREPLY=($(compgen -f -- "$cur"))
                            ;;
                        "exec")
                            # Complete with configured aliases or common commands
                            local gok_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                            local remote_config="${gok_root}/.config/remote-hosts"
                            local aliases="all"
                            if [[ -f "$remote_config" ]]; then
                                aliases="$aliases $(grep "^HOST_" "$remote_config" 2>/dev/null | sed 's/^HOST_\([^=]*\)=.*/\1/')"
                            fi
                            local common_commands="\"kubectl get pods\" \"docker ps\" \"systemctl status docker\" \"ls -la\" \"whoami\" \"hostname\" \"date\" \"uptime\""
                            COMPREPLY=($(compgen -W "$aliases $common_commands" -- "$cur"))
                            ;;
                        "status"|"test-connection"|"install-gok")
                            # Complete with configured aliases
                            local gok_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                            local remote_config="${gok_root}/.config/remote-hosts"
                            if [[ -f "$remote_config" ]]; then
                                local aliases=$(grep "^HOST_" "$remote_config" 2>/dev/null | sed 's/^HOST_\([^=]*\)=.*/\1/')
                                COMPREPLY=($(compgen -W "all $aliases" -- "$cur"))
                            else
                                COMPREPLY=($(compgen -W "all" -- "$cur"))
                            fi
                            ;;
                        "copy-key"|"setup-sudo")
                            # After hostname, expect username
                            COMPREPLY=()
                            ;;
                    esac
                    ;;
                "create")
                    case "${words[2]}" in
                        "user")
                            # After 'gok-new create user', expect username
                            COMPREPLY=()
                            ;;
                        "namespace")
                            # After 'gok-new create namespace', expect namespace name
                            COMPREPLY=()
                            ;;
                        "deployment"|"service")
                            # Complete with file names or resource names
                            COMPREPLY=($(compgen -f -- "$cur"))
                            ;;
                        "certificate"|"cert")
                            # Complete with domain names or certificate names
                            COMPREPLY=()
                            ;;
                    esac
                    ;;
                "generate")
                    case "${words[2]}" in
                        "cert"|"certificate")
                            # After certificate, expect domain or cert name
                            COMPREPLY=()
                            ;;
                        "key")
                            COMPREPLY=($(compgen -W "rsa ed25519 ecdsa" -- "$cur"))
                            ;;
                        "config")
                            COMPREPLY=($(compgen -W "kubeconfig docker registry" -- "$cur"))
                            ;;
                    esac
                    ;;
                "install")
                    case "${words[2]}" in
                        "cluster"|"master"|"node")
                            # Node-specific options
                            COMPREPLY=($(compgen -W "--master --worker --etcd --control-plane" -- "$cur"))
                            ;;
                        "k8s"|"kubernetes")
                            COMPREPLY=($(compgen -W "--version --network --cni" -- "$cur"))
                            ;;
                        "docker")
                            COMPREPLY=($(compgen -W "--version --registry --insecure" -- "$cur"))
                            ;;
                        "registry")
                            COMPREPLY=($(compgen -W "--secure --insecure --port" -- "$cur"))
                            ;;
                        "ingress")
                            COMPREPLY=($(compgen -W "nginx traefik istio" -- "$cur"))
                            ;;
                        "cert-manager")
                            COMPREPLY=($(compgen -W "--issuer --email --staging" -- "$cur"))
                            ;;
                    esac
                    ;;
                "exec")
                    # If second word was a target, complete with shell commands
                    if [[ "${words[2]}" != "exec" ]]; then
                        local common_commands="
                            kubectl docker systemctl journalctl ps top htop
                            ls cd pwd cat less more tail head grep find
                            whoami hostname date uptime df du free
                        "
                        COMPREPLY=($(compgen -W "$common_commands" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
        4)
            # Fourth argument and beyond - context-specific completions
            case "${words[1]}" in
                "remote")
                    case "${words[2]}" in
                        "setup")
                            case $cword in
                                4)
                                    # After hostname, expect username
                                    COMPREPLY=($(compgen -W "root ubuntu centos admin" -- "$cur"))
                                    ;;
                                5)
                                    # After username, expect key file
                                    COMPREPLY=($(compgen -f -- "$cur"))
                                    ;;
                                6)
                                    # After key file, expect sudo mode
                                    COMPREPLY=($(compgen -W "always auto never" -- "$cur"))
                                    ;;
                            esac
                            ;;
                        "add")
                            case $cword in
                                4)
                                    # After alias, expect hostname
                                    COMPREPLY=()
                                    ;;
                                5)
                                    # After hostname, expect username
                                    COMPREPLY=($(compgen -W "root ubuntu centos admin" -- "$cur"))
                                    ;;
                                6)
                                    # After username, expect key file
                                    COMPREPLY=($(compgen -f -- "$cur"))
                                    ;;
                            esac
                            ;;
                        "copy")
                            if [[ $cword -eq 4 ]]; then
                                # Remote path completion
                                COMPREPLY=()
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac

    # Handle file completion for certain contexts
    if [[ "$cur" == /* || "$cur" == ./* || "$cur" == ~/* ]]; then
        COMPREPLY=($(compgen -f -- "$cur"))
    fi

    return 0
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
} &&

# Register the completion function for gok-new
complete -F _gok_completion gok-new

# Also register for common aliases
complete -F _gok_completion gok

# Completion function for remote aliases (dynamic loading)
_gok_remote_aliases() {
    local gok_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local remote_config="${gok_root}/.config/remote-hosts"
    
    if [[ -f "$remote_config" ]]; then
        grep "^HOST_" "$remote_config" 2>/dev/null | sed 's/^HOST_\([^=]*\)=.*/\1/' | sort -u
    fi
}

# Helper function to get Kubernetes resources
_gok_k8s_resources() {
    local resource_type="$1"
    
    if command -v kubectl >/dev/null 2>&1; then
        case "$resource_type" in
            "pods"|"pod")
                kubectl get pods --no-headers 2>/dev/null | awk '{print $1}'
                ;;
            "services"|"service"|"svc")
                kubectl get services --no-headers 2>/dev/null | awk '{print $1}'
                ;;
            "deployments"|"deployment"|"deploy")
                kubectl get deployments --no-headers 2>/dev/null | awk '{print $1}'
                ;;
            "nodes"|"node")
                kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}'
                ;;
            "namespaces"|"namespace"|"ns")
                kubectl get namespaces --no-headers 2>/dev/null | awk '{print $1}'
                ;;
            "ingress"|"ing")
                kubectl get ingress --no-headers 2>/dev/null | awk '{print $1}'
                ;;
        esac
    fi
}

# Enhanced _init_completion function for older bash versions
if ! declare -F _init_completion >/dev/null 2>&1; then
    _init_completion() {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
        split=false
        return 0
    }
fi

# Export functions for use in subshells
export -f _gok_completion
export -f _gok_remote_aliases  
export -f _gok_k8s_resources

# Print installation message when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "✅ GOK-NEW bash completion loaded successfully"
    echo "   Try: gok-new <TAB><TAB>"
    echo "   Or:  gok-new remote <TAB><TAB>"
    echo "   Or:  gok-new install <TAB><TAB>"
fi