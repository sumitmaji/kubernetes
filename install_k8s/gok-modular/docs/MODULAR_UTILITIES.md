# GOK Modular Utility Systems Documentation

## Overview

The GOK modular architecture includes comprehensive utility systems that provide powerful functionality for any component to easily incorporate. These systems are designed to be plug-and-play, requiring minimal integration effort while providing enterprise-grade capabilities.

## Available Utility Systems

### 1. Next-Steps Guidance System (`lib/utils/guidance.sh`)

**Purpose**: Provides intelligent component-specific recommendations and installation chains

**Key Functions**:
- `suggest_next_installations()` - Analyzes current platform state and suggests next components
- `suggest_and_install_next_module(component, auto_install)` - Provides post-installation guidance  
- `show_component_guidance(component)` - Shows component-specific setup instructions
- `display_platform_overview()` - Complete platform status with URLs and credentials
- `recommend_installation_path(use_case)` - Tailored recommendations for dev/prod/security

**Integration Example**:
```bash
# Source the guidance system
source "${GOK_ROOT}/lib/utils/guidance.sh"

# After successful component installation
suggest_and_install_next_module "kubernetes"

# Show platform overview
display_platform_overview

# Get recommendations for specific use case  
recommend_installation_path "development"
```

### 2. Repository Fix Utility (`lib/utils/repository_fix.sh`)

**Purpose**: Handles Helm repository 404 errors and package manager conflicts

**Key Functions**:
- `fix_helm_repository_errors()` - Comprehensive Helm repository issue resolution
- `fix_package_repository_issues()` - General package repository problem fixing
- `setup_modern_repositories(tool)` - Configure modern repositories for helm/kubernetes/docker
- `clean_old_helm_repositories()` - Remove problematic old repository configurations

**Integration Example**:
```bash
# Source the repository fix system
source "${GOK_ROOT}/lib/utils/repository_fix.sh"

# Before installing Helm-based components
if ! helm repo list >/dev/null 2>&1; then
    log_warning "Helm repository issues detected"
    fix_helm_repository_errors
fi

# Setup modern repositories
setup_modern_repositories "helm"
```

### 3. Installation Validation System (`lib/utils/validation.sh`)

**Purpose**: Comprehensive component health checks and verification

**Key Functions**:
- `validate_component_installation(component, timeout)` - Main validation entry point
- `validate_kubernetes_cluster(timeout)` - Kubernetes-specific validation
- `check_deployment_readiness(deployment, namespace)` - Deployment status checking
- `wait_for_pods_ready(selector, timeout, namespace)` - Pod readiness with timeout
- `check_service_connectivity(service, namespace)` - Service accessibility testing

**Integration Example**:
```bash
# Source the validation system
source "${GOK_ROOT}/lib/utils/validation.sh"

# After component installation
if validate_component_installation "monitoring" 300; then
    log_success "Monitoring stack validation passed"
else
    log_error "Monitoring stack validation failed"
    # Handle validation failure
fi

# Check specific deployments
if check_deployment_readiness "prometheus" "monitoring"; then
    log_success "Prometheus is ready"
fi
```

### 4. Deployment Verification System (`lib/utils/verification.sh`)

**Purpose**: Enhanced issue detection with troubleshooting guidance

**Key Functions**:
- `verify_component_deployment(component, namespace)` - Complete deployment health check
- `check_image_pull_issues(namespace, component)` - Docker image pull problem detection
- `check_resource_constraints(namespace, component)` - Resource limitation identification  
- `check_configuration_issues(namespace, component)` - Configuration problem analysis
- `diagnose_deployment_issues(namespace, component)` - Detailed issue diagnosis

**Integration Example**:
```bash
# Source the verification system
source "${GOK_ROOT}/lib/utils/verification.sh"

# Comprehensive deployment verification
if verify_component_deployment "argocd" "argocd"; then
    log_success "ArgoCD deployment is healthy"
else
    log_warning "ArgoCD deployment has issues"
    # Detailed diagnostics are automatically shown
fi

# Check specific issues
check_image_pull_issues "monitoring" "prometheus"
check_resource_constraints "monitoring" "grafana"
```

### 5. Interactive Installation System (`lib/utils/interactive.sh`)

**Purpose**: Guided wizard with prerequisite checking and component selection

**Key Functions**:
- `interactive_installation()` - Main interactive installation wizard
- `check_prerequisites()` - System prerequisite validation
- `interactive_profile_installation()` - Profile-based installation (dev/prod/security)
- `interactive_custom_installation()` - Custom component selection
- `show_installation_completion_summary()` - Post-installation guidance

**Integration Example**:
```bash
# Source the interactive system
source "${GOK_ROOT}/lib/utils/interactive.sh"

# Launch interactive installation
interactive_installation

# Check prerequisites before installation
if check_prerequisites; then
    log_success "Prerequisites met"
else
    log_error "Prerequisites not met"
    exit 1
fi
```

### 6. Enhanced Execution System (`lib/utils/execution.sh`)

**Purpose**: Command execution with logging, suppression, and error handling

**Key Functions**:
- `execute_with_suppression(command, description)` - Execute with output control
- `helm_install_with_summary(name, chart, namespace, values_file)` - Helm installation wrapper
- `kubectl_apply_with_summary(file, namespace)` - kubectl apply wrapper
- `execute_with_retry(command, max_attempts, description)` - Retry mechanism

**Integration Example**:
```bash
# Source the execution system
source "${GOK_ROOT}/lib/utils/execution.sh"

# Execute commands with proper logging
execute_with_suppression "kubectl apply -f manifest.yaml" "Applying Kubernetes manifests"

# Helm installation with summary
helm_install_with_summary "prometheus" "prometheus-community/prometheus" "monitoring" "values.yaml"

# Command with retry logic
execute_with_retry "kubectl get nodes" 3 "Checking cluster connectivity"
```

### 7. Enhanced Component Tracking (`lib/utils/tracking.sh`)

**Purpose**: Comprehensive component lifecycle tracking and status management

**Key Functions**:
- `start_component(component, description, version, namespace)` - Begin component installation
- `complete_component(component, message, details)` - Mark installation complete
- `fail_component(component, reason)` - Handle installation failures
- `show_installation_summary()` - Display installation status overview
- `get_component_status(component)` - Get individual component status

**Integration Example**:
```bash
# Source the tracking system
source "${GOK_ROOT}/lib/utils/tracking.sh"

# Start component installation tracking
start_component "monitoring" "Prometheus and Grafana monitoring stack" "v1.0" "monitoring"

# ... perform installation steps ...

if [[ $installation_success == true ]]; then
    complete_component "monitoring" "Installation completed successfully" "All services running"
else
    fail_component "monitoring" "Helm chart installation failed"
fi

# Show overall status
show_installation_summary
```

## Integration Patterns

### Pattern 1: Basic Component Integration

```bash
#!/bin/bash
# Example component: lib/components/monitoring/prometheus.sh

# Source required utilities
source "${GOK_ROOT}/lib/utils/execution.sh"
source "${GOK_ROOT}/lib/utils/tracking.sh"
source "${GOK_ROOT}/lib/utils/validation.sh"
source "${GOK_ROOT}/lib/utils/guidance.sh"

install_prometheus() {
    # Start tracking
    start_component "prometheus" "Prometheus monitoring server" "v2.45" "monitoring"
    
    # Execute installation with proper logging
    if execute_with_suppression "helm install prometheus prometheus-community/prometheus -n monitoring" "Installing Prometheus"; then
        
        # Validate installation
        if validate_component_installation "prometheus" 300; then
            complete_component "prometheus" "Installation successful"
            
            # Provide next steps guidance
            suggest_and_install_next_module "prometheus"
        else
            fail_component "prometheus" "Validation failed"
            return 1
        fi
    else
        fail_component "prometheus" "Helm installation failed"
        return 1
    fi
}
```

### Pattern 2: Advanced Component with Full Integration

```bash
#!/bin/bash
# Example component: lib/components/security/vault.sh

# Source all utility systems
source "${GOK_ROOT}/lib/utils/execution.sh"
source "${GOK_ROOT}/lib/utils/tracking.sh"
source "${GOK_ROOT}/lib/utils/validation.sh"
source "${GOK_ROOT}/lib/utils/verification.sh"
source "${GOK_ROOT}/lib/utils/guidance.sh"
source "${GOK_ROOT}/lib/utils/repository_fix.sh"

install_vault() {
    local namespace="vault"
    
    # Start tracking with detailed info
    start_component "vault" "HashiCorp Vault secrets management" "v1.14" "$namespace"
    
    # Check and fix repository issues
    if ! helm repo list | grep -q hashicorp; then
        log_info "Adding HashiCorp Helm repository"
        if ! helm repo add hashicorp https://helm.releases.hashicorp.com; then
            log_warning "Repository add failed, attempting to fix"
            fix_helm_repository_errors
            helm repo add hashicorp https://helm.releases.hashicorp.com || {
                fail_component "vault" "Failed to add HashiCorp repository"
                return 1
            }
        fi
    fi
    
    # Create namespace
    execute_with_suppression "kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -" "Creating vault namespace"
    
    # Install with Helm wrapper
    if helm_install_with_summary "vault" "hashicorp/vault" "$namespace" "vault-values.yaml"; then
        
        # Wait for basic installation
        log_info "Waiting for Vault pods to be ready..."
        if wait_for_pods_ready "vault" 300 "$namespace"; then
            
            # Comprehensive validation
            if validate_component_installation "vault" 300; then
                
                # Enhanced verification with issue detection
                if verify_component_deployment "vault" "$namespace"; then
                    complete_component "vault" "Installation and verification successful" "Vault is ready for initialization"
                    
                    # Show component-specific guidance
                    show_component_guidance "vault"
                    
                    # Suggest next steps
                    suggest_and_install_next_module "vault"
                else
                    fail_component "vault" "Deployment verification failed"
                    return 1
                fi
            else
                fail_component "vault" "Component validation failed"
                return 1
            fi
        else
            fail_component "vault" "Pods failed to become ready"
            return 1
        fi
    else
        fail_component "vault" "Helm installation failed"
        return 1
    fi
}
```

### Pattern 3: Interactive Installation Integration

```bash
#!/bin/bash
# Example: Interactive installation workflow

install_with_interactive_mode() {
    # Source interactive system
    source "${GOK_ROOT}/lib/utils/interactive.sh"
    source "${GOK_ROOT}/lib/utils/validation.sh"
    
    # Check prerequisites first
    if ! check_prerequisites; then
        log_error "Prerequisites not met for installation"
        return 1
    fi
    
    # Launch interactive installation
    interactive_installation
}

# Custom component selection with validation
install_custom_selection() {
    local components=("$@")
    
    # Validate selection
    if validate_component_selection "${components[@]}"; then
        # Resolve dependencies
        local resolved=$(resolve_dependencies "${components[@]}")
        
        # Install with progress tracking
        execute_component_installation "$resolved"
    else
        log_error "Invalid component selection"
        return 1
    fi
}
```

## Best Practices for Component Developers

### 1. Always Use Tracking
```bash
# Start tracking at the beginning of installation
start_component "my-component" "My Component Description" "v1.0" "my-namespace"

# Complete or fail at the end
complete_component "my-component" "Installation successful"
# OR
fail_component "my-component" "Installation failed: reason"
```

### 2. Validate After Installation
```bash
# Always validate after installation
if validate_component_installation "my-component" 300; then
    log_success "Component validation passed"
else
    log_error "Component validation failed"
    return 1
fi
```

### 3. Use Execution Wrappers
```bash
# Use execution utilities for consistent logging
execute_with_suppression "command" "Description of what command does"

# Use Helm wrapper for consistent installation
helm_install_with_summary "release" "chart" "namespace" "values-file"
```

### 4. Provide Guidance
```bash
# Show component-specific guidance after installation
show_component_guidance "my-component"

# Suggest next steps
suggest_and_install_next_module "my-component"
```

### 5. Handle Repository Issues
```bash
# Check and fix repository issues before Helm operations
if ! helm repo list | grep -q my-repo; then
    log_info "Adding repository"
    if ! helm repo add my-repo https://my-repo.com; then
        fix_helm_repository_errors
        helm repo add my-repo https://my-repo.com
    fi
fi
```

### 6. Use Comprehensive Verification
```bash
# Use both validation and verification
if validate_component_installation "my-component" 300; then
    if verify_component_deployment "my-component" "my-namespace"; then
        log_success "Component is fully verified and healthy"
    else
        log_warning "Component installed but has deployment issues"
    fi
fi
```

## Error Handling Patterns

### 1. Graceful Failure Handling
```bash
install_component() {
    start_component "component" "Description" "v1.0" "namespace"
    
    # Installation step
    if ! execute_with_suppression "installation-command" "Installing component"; then
        fail_component "component" "Installation command failed"
        return 1
    fi
    
    # Validation step  
    if ! validate_component_installation "component" 300; then
        fail_component "component" "Component validation failed"
        return 1
    fi
    
    # Success
    complete_component "component" "Installation successful"
}
```

### 2. Retry Pattern with Execution System
```bash
# Use retry mechanism for unreliable operations
if ! execute_with_retry "kubectl get nodes" 3 "Checking cluster connectivity"; then
    fail_component "component" "Cluster connectivity check failed after retries"
    return 1
fi
```

### 3. Repository Issue Recovery
```bash
install_helm_component() {
    # Try normal installation first
    if ! helm install my-release my-chart; then
        log_warning "Helm installation failed, attempting repository fix"
        
        # Fix repository issues and retry
        fix_helm_repository_errors
        
        if ! helm install my-release my-chart; then
            fail_component "component" "Helm installation failed even after repository fix"
            return 1
        fi
    fi
}
```

## Conclusion

These modular utility systems provide a comprehensive foundation for building robust, user-friendly, and maintainable GOK components. By following the integration patterns and best practices outlined in this documentation, component developers can easily incorporate enterprise-grade functionality with minimal effort.

The utilities are designed to work together seamlessly, providing a complete ecosystem for component lifecycle management, validation, troubleshooting, and user guidance.