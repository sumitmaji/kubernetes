#!/bin/bash

# GOK-NEW Bash Completion
# Provides intelligent multi-level tab completion for gok-new commands and subcommands
# 
# Installation:
#   1. Source this file in your shell: source gok-completion.bash
#   2. Or add to ~/.bashrc: source /path/to/gok-completion.bash
#   3. Or install system-wide: sudo cp gok-completion.bash /etc/bash_completion.d/

_gok_new_completion() {
    local cur prev words cword
    
    # Initialize completion variables manually
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD

    # Main commands available in gok-new
    local main_commands="
        install reset start deploy patch create generate status
        desc describe logs bash shell exec remote completion
        cache show summary next taint-node checkDns checkCurl debug troubleshoot help
    "

    # Infrastructure components
    local infrastructure_components="docker kubernetes kubernetes-worker helm calico ingress haproxy cluster master node tools k8s"
    
    # Monitoring components
    local monitoring_components="prometheus grafana cadvisor metric-server monitoring heapster"
    
    # Security components
    local security_components="cert-manager keycloak oauth2 oauth2-proxy vault ldap ldapclient kerberos kerberizedservices kyverno"
    
    # Development components
    local development_components="jupyter jupyterhub dashboard ttyd eclipseche cloud-shell console controller gok-agent gok-controller devworkspace workspace che"
    
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

    # Start command components
    local start_components="kubernetes kubelet proxy ha docker containerd"

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
                "start")
                    COMPREPLY=($(compgen -W "$start_components" -- "$cur"))
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
                "show")
                    COMPREPLY=($(compgen -W "configuration config" -- "$cur"))
                    ;;
                "summary")
                    COMPREPLY=($(compgen -W "$install_components" -- "$cur"))
                    ;;
                "next")
                    COMPREPLY=($(compgen -W "$install_components" -- "$cur"))
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
                    COMPREPLY=($(compgen -W "bash zsh fish install uninstall status help" -- "$cur"))
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
                "debug"|"troubleshoot")
                    local debug_commands="
                        init setup context ctx namespace ns shell bash exec logs log tail
                        describe desc watch resources top pods pod services svc forward
                        pf port-forward network net ingress ing decode secret cert certificate
                        config cfg cluster status health troubleshoot fix performance perf
                        dashboard dash summary overview events utils utilities aliases help
                    "
                    COMPREPLY=($(compgen -W "$debug_commands" -- "$cur"))
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
                "debug"|"troubleshoot")
                    case "${words[2]}" in
                        "init")
                            COMPREPLY=($(compgen -W "--force --verbose --check" -- "$cur"))
                            ;;
                        "shell"|"bash")
                            # Complete with pod names if kubectl is available
                            if command -v kubectl >/dev/null 2>&1; then
                                local pods=$(kubectl get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
                                COMPREPLY=($(compgen -W "$pods" -- "$cur"))
                            fi
                            ;;
                        "logs"|"tail"|"watch")
                            # Complete with pod names
                            if command -v kubectl >/dev/null 2>&1; then
                                local pods=$(kubectl get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
                                COMPREPLY=($(compgen -W "$pods" -- "$cur"))
                            fi
                            ;;
                        "desc"|"describe")
                            COMPREPLY=($(compgen -W "pod service deployment node pv pvc configmap secret ingress" -- "$cur"))
                            ;;
                        "decode")
                            # Complete with secret names
                            if command -v kubectl >/dev/null 2>&1; then
                                local secrets=$(kubectl get secrets -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
                                COMPREPLY=($(compgen -W "$secrets" -- "$cur"))
                            fi
                            ;;
                        "network")
                            COMPREPLY=($(compgen -W "--test --trace --verbose" -- "$cur"))
                            ;;
                        "performance")
                            COMPREPLY=($(compgen -W "--cpu --memory --disk --network" -- "$cur"))
                            ;;
                        "context"|"current")
                            if command -v kubectl >/dev/null 2>&1; then
                                local contexts=$(kubectl config get-contexts -o name 2>/dev/null)
                                COMPREPLY=($(compgen -W "$contexts" -- "$cur"))
                            fi
                            ;;
                    esac
                    ;;
                "completion")
                    case "${words[2]}" in
                        "install"|"uninstall")
                            COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
                            ;;
                    esac
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
} &&

# Register the completion function for gok-new
complete -F _gok_new_completion gok-new

# Don't register for 'gok' to avoid conflicts with system gok

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

# Note: _init_completion removed for compatibility

# Export functions for use in subshells
export -f _gok_new_completion
export -f _gok_remote_aliases  
export -f _gok_k8s_resources

# Print installation message when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "✅ GOK-NEW bash completion loaded successfully"
    echo "   Try: gok-new <TAB><TAB>"
    echo "   Or:  gok-new remote <TAB><TAB>"
    echo "   Or:  gok-new install <TAB><TAB>"
fi