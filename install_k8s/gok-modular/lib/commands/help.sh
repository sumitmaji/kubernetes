#!/bin/bash

# GOK Help Command Module - Documentation and usage information

# Main help command handler
helpCmd() {
    local topic="${1:-}"
    
    case "$topic" in
        "install")
            show_install_help
            ;;
        "reset")
            show_reset_help
            ;;
        "commands")
            show_commands_help
            ;;
        "components")
            show_components_help
            ;;
        *)
            show_main_help
            ;;
    esac
}

# Show main help information
show_main_help() {
    cat << 'EOF'
GOK - Kubernetes Operations Toolkit (Modular Version)
====================================================

GOK is a comprehensive toolkit for managing Kubernetes clusters and deploying
cloud-native applications with integrated security, monitoring, and DevOps tools.

USAGE:
  gok <command> [options]

CORE COMMANDS:

Lifecycle Management:
  install <component>     Install and configure components
  reset <component>       Reset and uninstall components
  start <component>       Start system services
  deploy <component>      Deploy applications

Resource Management:
  create <resource>       Create Kubernetes resources and configurations
  generate <type>         Generate microservice templates
  patch <resource>        Patch and modify existing resources

Operations:
  desc [target]           Describe pods or GOK methods
  logs                    View pod logs and diagnostics
  bash                    Open interactive terminal in pods
  exec <command>          Execute commands on remote VMs
  status                  Check Helm release status

System Management:
  remote <action>         Execute remote operations
  completion <action>     Manage bash completion
  cache <action>          Manage system caches

COMPONENT CATEGORIES:

Infrastructure:
  • docker, kubernetes, kubernetes-worker, helm, calico, ingress
  
Security:
  • cert-manager, keycloak, oauth2, vault, ldap, kyverno
  
Monitoring:
  • monitoring, prometheus, grafana, fluentd, opensearch
  
Development:
  • dashboard, jupyter, devworkspace, workspace, che, ttyd, cloudshell, console
  
CI/CD:
  • argocd, jenkins, spinnaker, registry
  
GOK Platform:
  • gok-agent, gok-controller, controller, gok-login, chart
  
Solutions:
  • base, base-services

GLOBAL OPTIONS:
  --verbose, -v           Enable verbose output
  --help, -h              Show help information

EXAMPLES:
  gok install kubernetes                    # Install Kubernetes master
  gok install base-services --verbose       # Install essential services
  gok reset monitoring                      # Uninstall monitoring stack
  gok create secret myapp-secret           # Create a Kubernetes secret
  gok exec "kubectl get pods"              # Execute command on remote VM
  gok desc methods                         # Show all available methods
  gok remote setup                         # Configure remote hosts

GETTING HELP:
  gok help install        # Help for install command
  gok help reset          # Help for reset command
  gok help components     # List all available components
  gok help commands       # List all available commands

For more detailed information about specific commands or components,
use 'gok <command> --help' or visit: https://github.com/sumitmaji/kubernetes

EOF
}

# Show commands help
show_commands_help() {
    cat << 'EOF'
GOK Commands Reference
=====================

INSTALLATION COMMANDS:
  install <component>     Install Kubernetes components
                         Examples: gok install kubernetes
                                  gok install monitoring

RESET COMMANDS:
  reset <component>       Uninstall and cleanup components
                         Examples: gok reset keycloak
                                  gok reset monitoring

RESOURCE COMMANDS:
  create <type> <name>    Create Kubernetes resources
                         Examples: gok create secret app-secret
                                  gok create certificate domain-cert

  patch <resource> <name> Modify existing resources
                         Examples: gok patch ingress app-ingress letsencrypt

  generate <type>         Generate templates and configurations
                         Examples: gok generate microservice
                                  gok generate service

DIAGNOSTIC COMMANDS:
  desc [target]          Describe pods or show method documentation
                         Examples: gok desc
                                  gok desc methods

  logs                   View and follow pod logs
                         Examples: gok logs

  bash                   Open shell in selected pod
                         Examples: gok bash

  show <info>            Display system information
                         Examples: gok show configuration

  status                 Check system and component status
                         Examples: gok status

  show <info>            Display system information
                         Examples: gok show configuration

SYSTEM COMMANDS:
  remote <action>        Manage remote host operations
                         Examples: gok remote setup
                                  gok remote exec "command"

  cache <action>         Manage system caches
                         Examples: gok cache status
                                  gok cache clear

  completion <action>    Manage bash completion
                         Examples: gok completion enable

DEPLOYMENT COMMANDS:
  start <service>        Start system services
                         Examples: gok start kubernetes

  deploy <app>           Deploy applications
                         Examples: gok deploy app1

Each command supports --help for detailed usage information.
EOF
}

# Show components help
show_components_help() {
    cat << 'EOF'
GOK Components Reference
========================

INFRASTRUCTURE COMPONENTS:
  docker                 Docker container runtime and management
  kubernetes            Kubernetes master node setup
  kubernetes-worker     Kubernetes worker node configuration
  helm                  Helm package manager for Kubernetes
  calico                Calico network plugin for pod networking
  ingress               NGINX Ingress Controller for traffic routing

SECURITY COMPONENTS:
  cert-manager          Automated certificate management
  keycloak             Identity and access management platform
  oauth2               OAuth2 proxy for authentication
  vault                HashiCorp Vault for secrets management
  ldap                 LDAP server for directory services
  kyverno              Policy engine for Kubernetes security

MONITORING COMPONENTS:
  monitoring           Complete monitoring stack (Prometheus + Grafana)
  prometheus           Prometheus metrics collection and alerting
  grafana              Grafana dashboards and visualization
  fluentd              Log collection and aggregation
  opensearch           Search and analytics platform

DEVELOPMENT COMPONENTS:
  dashboard            Kubernetes web-based dashboard
  jupyter              JupyterHub for data science and development
  devworkspace         Development workspace environments
  workspace            Enhanced development workspace (v2)
  che                  Eclipse Che web-based IDE
  ttyd                 Web-based terminal access
  cloudshell           Cloud shell development environment
  console              Web-based management console

CI/CD COMPONENTS:
  argocd               GitOps continuous delivery platform
  jenkins              Automation server for CI/CD pipelines
  spinnaker            Multi-cloud deployment platform
  registry             Private container registry

GOK PLATFORM COMPONENTS:
  gok-agent            GOK platform agent for node management
  gok-controller       GOK platform controller for orchestration
  controller           Combined installation of agent and controller
  gok-login            Authentication service for GOK platform
  chart                Helm chart registry and management

OTHER COMPONENTS:
  rabbitmq             Message broker for distributed systems
  istio                Service mesh for microservices communication

SOLUTION BUNDLES:
  base                 Essential infrastructure (docker, k8s, helm, ingress)
  base-services        Core services (vault, keycloak, registry, cert-manager)

COMPONENT DEPENDENCIES:
  • Most components require 'kubernetes' to be installed first
  • Helm-based components require 'helm' to be installed
  • Security components often depend on 'cert-manager'
  • Monitoring components work best with 'ingress' for access

Use 'gok install <component> --help' for component-specific information.
EOF
}

# Show version information
show_version() {
    echo "GOK - Kubernetes Operations Toolkit"
    echo "Version: ${GOK_VERSION:-2.0.0-modular}"
    echo "Build Date: ${GOK_BUILD_DATE:-2025-10-08}"
    echo "Architecture: Modular"
    echo ""
    echo "Copyright (c) 2025 GOK Platform Team"
    echo "License: MIT"
    echo ""
    echo "For more information: https://github.com/sumitmaji/kubernetes"
}

# Show quick reference
show_quick_reference() {
    cat << 'EOF'
GOK Quick Reference
===================

Most Common Commands:
  gok install kubernetes                # Install Kubernetes
  gok install base-services            # Install essential services  
  gok install monitoring               # Install Prometheus + Grafana
  gok reset <component>                # Uninstall component
  gok status                           # Check system status
  gok desc                             # Describe selected pod
  gok logs                             # View pod logs

Quick Setup:
  gok install docker                   # 1. Install Docker
  gok install kubernetes              # 2. Install Kubernetes
  gok install helm                    # 3. Install Helm
  gok install ingress                 # 4. Install Ingress
  gok install cert-manager            # 5. Install cert-manager
  gok install monitoring              # 6. Install monitoring

Troubleshooting:
  gok desc methods                     # Show all available functions
  gok help components                  # List all components
  gok cache clear                      # Clear system caches
  gok remote status                    # Check remote connections
EOF
}

# Command completion help
show_completion_help() {
    cat << 'EOF'
GOK Bash Completion
===================

Enable bash completion for GOK commands:

  gok completion enable               # Enable completion for current session
  gok completion setup                # Setup permanent completion

Manual setup:
  1. Add this line to your ~/.bashrc:
     source <(gok completion script)
     
  2. Reload your shell:
     source ~/.bashrc

Usage:
  gok <TAB>                          # Show available commands
  gok install <TAB>                  # Show available components
  gok reset <TAB>                    # Show installed components

EOF
}