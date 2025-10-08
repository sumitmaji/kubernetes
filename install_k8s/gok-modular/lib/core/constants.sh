#!/bin/bash

# GOK Constants Module - Global constants and configuration values

# Version information
export GOK_VERSION="2.0.0"
export GOK_BUILD_DATE="2025-10-08"

# Default cache settings
export GOK_UPDATE_CACHE_HOURS="${GOK_UPDATE_CACHE_HOURS:-6}"
export GOK_DEPS_CACHE_HOURS="${GOK_DEPS_CACHE_HOURS:-${GOK_UPDATE_CACHE_HOURS:-6}}"

# Component lists for bash completion
export GOK_INSTALL_COMPONENTS="docker kubernetes kubernetes-worker helm calico ingress cert-manager dashboard monitoring prometheus grafana fluentd opensearch keycloak oauth2 vault ldap jupyter devworkspace workspace che ttyd cloudshell console argocd jenkins spinnaker registry istio rabbitmq kyverno gok-agent gok-controller controller gok-login chart base base-services"

export GOK_RESET_COMPONENTS="docker kubernetes helm calico ingress cert-manager dashboard monitoring prometheus grafana fluentd opensearch keycloak oauth2 vault ldap jupyter devworkspace workspace che ttyd cloudshell console argocd jenkins spinnaker registry istio rabbitmq kyverno gok-agent gok-controller gok-login chart base-services"

export GOK_START_COMPONENTS="kubernetes docker helm"

export GOK_DEPLOY_COMPONENTS="app1"

export GOK_CREATE_RESOURCES="secret certificate kubeconfig"

export GOK_GENERATE_TYPES="microservice service api"

export GOK_PATCH_RESOURCES="ingress"

# Default namespaces
export GOK_DEFAULT_NAMESPACE="default"
export GOK_SYSTEM_NAMESPACE="kube-system"
export GOK_MONITORING_NAMESPACE="monitoring"
export GOK_SECURITY_NAMESPACE="security"

# Default ports and protocols
export GOK_DEFAULT_HTTP_PORT="80"
export GOK_DEFAULT_HTTPS_PORT="443"
export GOK_DEFAULT_SSH_PORT="22"

# Color codes for output
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_PURPLE='\033[0;35m'
export COLOR_CYAN='\033[0;36m'
export COLOR_WHITE='\033[1;37m'
export COLOR_NC='\033[0m' # No Color

# Icons and symbols
export ICON_SUCCESS="✅"
export ICON_ERROR="❌"
export ICON_WARNING="⚠️"
export ICON_INFO="ℹ️"
export ICON_ARROW="➜"
export ICON_BULLET="•"
export ICON_CHECK="✓"
export ICON_CROSS="✗"

# File extensions and patterns
export GOK_YAML_EXTENSIONS="yaml yml"
export GOK_CONFIG_EXTENSIONS="conf config cfg"
export GOK_SCRIPT_EXTENSIONS="sh bash"

# Timeout values (in seconds)
export GOK_DEFAULT_TIMEOUT="300"
export GOK_LONG_TIMEOUT="600"
export GOK_SHORT_TIMEOUT="30"

# Retry configurations
export GOK_DEFAULT_RETRIES="3"
export GOK_RETRY_DELAY="5"

# Log levels
export LOG_LEVEL_ERROR="ERROR"
export LOG_LEVEL_WARN="WARN"  
export LOG_LEVEL_INFO="INFO"
export LOG_LEVEL_DEBUG="DEBUG"
export LOG_LEVEL_TRACE="TRACE"

# Default log level
export GOK_LOG_LEVEL="${GOK_LOG_LEVEL:-INFO}"

# Component installation states
export COMPONENT_STATE_NOT_STARTED="not-started"
export COMPONENT_STATE_IN_PROGRESS="in-progress"
export COMPONENT_STATE_COMPLETED="completed"
export COMPONENT_STATE_FAILED="failed"
export COMPONENT_STATE_SKIPPED="skipped"

# Kubernetes resource types
export K8S_RESOURCE_DEPLOYMENT="deployment"
export K8S_RESOURCE_SERVICE="service"
export K8S_RESOURCE_INGRESS="ingress"
export K8S_RESOURCE_SECRET="secret"
export K8S_RESOURCE_CONFIGMAP="configmap"
export K8S_RESOURCE_NAMESPACE="namespace"
export K8S_RESOURCE_POD="pod"
export K8S_RESOURCE_PVC="pvc"
export K8S_RESOURCE_PV="pv"

# Helm repository names and URLs
declare -A HELM_REPOS
HELM_REPOS["bitnami"]="https://charts.bitnami.com/bitnami"
HELM_REPOS["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
HELM_REPOS["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
HELM_REPOS["jetstack"]="https://charts.jetstack.io"
HELM_REPOS["elastic"]="https://helm.elastic.co"
HELM_REPOS["grafana"]="https://grafana.github.io/helm-charts"

# Export the associative array
export HELM_REPOS

# Certificate manager challenge types
export CERTMANAGER_CHALLENGE_HTTP01="http01"
export CERTMANAGER_CHALLENGE_DNS01="dns01"

# Identity providers
export IDENTITY_PROVIDER_AUTH0="auth0"
export IDENTITY_PROVIDER_KEYCLOAK="keycloak"

# Default identity provider
export DEFAULT_IDENTITY_PROVIDER="${IDENTITY_PROVIDER:-keycloak}"