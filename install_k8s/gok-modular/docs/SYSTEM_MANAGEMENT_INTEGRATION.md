# System Update & Dependency Management Integration Guide

## Overview

The GOK-New modular system includes three powerful utilities for system management that any component can easily incorporate:

1. **System Update Utility** (`lib/utils/system_update.sh`) - Smart system package repository updates with caching
2. **Dependency Manager** (`lib/utils/dependency_manager.sh`) - Comprehensive dependency installation and validation  
3. **HA Validation Utility** (`lib/utils/ha_validation.sh`) - High availability setup validation and diagnostics

These utilities are automatically loaded by the bootstrap system and provide enterprise-grade functionality that components can leverage with simple function calls.

## Integration Patterns

### 1. System Update Integration

#### Basic Usage in Components

```bash
# In any component installation function
install_my_component() {
    log_step "MyComponent" "Installing MyComponent"
    
    # Ensure system is updated before installation
    if ! ensure_system_updated "MyComponent"; then
        log_error "Failed to update system for MyComponent"
        return 1
    fi
    
    # Continue with component installation...
    log_success "MyComponent system preparation completed"
}
```

#### Advanced Usage with Options

```bash
# Component with configurable update behavior
install_kubernetes() {
    local force_update=false
    local skip_update=false
    
    # Parse component-specific arguments
    for arg in "$@"; do
        case "$arg" in
            --force-update)
                force_update=true
                ;;
            --skip-system-update)
                skip_update=true
                ;;
        esac
    done
    
    # Prepare system with options
    local update_options=()
    [[ "$force_update" == "true" ]] && update_options+=("--force-update")
    [[ "$skip_update" == "true" ]] && update_options+=("--skip-update")
    
    if ! prepare_system_for_installation "kubernetes" "${update_options[@]}"; then
        log_error "Failed to prepare system for Kubernetes"
        return 1
    fi
    
    # Continue with Kubernetes installation...
}
```

#### Cache Management

```bash
# Check cache status before deciding on update strategy
install_monitoring_stack() {
    local cache_status=$(get_system_update_cache_status)
    
    case "$cache_status" in
        "valid:"*)
            log_info "System update cache valid - proceeding with installation"
            ;;
        "expired:"*)
            log_info "System update cache expired - updating system"
            update_system_with_cache
            ;;
        "no-cache")
            log_info "No system update cache - performing fresh update"
            update_system
            ;;
    esac
    
    # Continue with monitoring installation...
}
```

### 2. Dependency Manager Integration

#### Basic Dependency Installation

```bash
# Ensure dependencies for component installation
install_vault() {
    log_step "Vault" "Installing HashiCorp Vault"
    
    # Install dependencies specific to vault
    if ! ensure_dependencies_for_component "vault"; then
        log_error "Failed to install dependencies for Vault"
        return 1
    fi
    
    # Verify critical dependencies are available
    if ! verify_critical_dependencies; then
        log_error "Critical dependencies missing for Vault"
        return 1
    fi
    
    # Continue with Vault installation...
    log_success "Vault dependencies prepared"
}
```

#### Component-Specific Dependencies

```bash
# The dependency manager automatically includes component-specific packages
install_jenkins() {
    # This will install both essential system dependencies AND
    # Jenkins-specific dependencies (like openjdk-11-jdk, maven)
    if ! ensure_dependencies_for_component "jenkins" --verbose; then
        log_error "Failed to install Jenkins dependencies"
        return 1
    fi
    
    # Validate specific dependencies for Jenkins
    if ! validate_component_dependencies "jenkins"; then
        log_error "Jenkins dependency validation failed"
        return 1
    fi
    
    # Continue with Jenkins installation...
}
```

#### Dependency Troubleshooting Integration

```bash
# Handle dependency installation failures gracefully
install_prometheus() {
    # Attempt dependency installation with error handling
    if ! install_system_dependencies --component="prometheus"; then
        log_error "Prometheus dependency installation failed"
        
        # Show troubleshooting information
        show_dependency_troubleshooting
        
        # Attempt to continue with critical dependencies only
        if verify_critical_dependencies; then
            log_warning "Continuing with minimal dependencies"
        else
            log_error "Cannot continue without critical dependencies"
            return 1
        fi
    fi
    
    # Continue with Prometheus installation...
}
```

### 3. HA Validation Integration

#### Basic HA Validation

```bash
# Validate HA setup before Kubernetes installation
install_kubernetes() {
    log_step "Kubernetes" "Installing Kubernetes with HA support"
    
    # Validate HA dependencies for Kubernetes
    if ! validate_ha_setup_for_component "kubernetes"; then
        log_error "HA validation failed for Kubernetes"
        return 1
    fi
    
    # Continue with HA Kubernetes installation...
    log_success "HA validation passed for Kubernetes"
}
```

#### Detailed HA Validation with Diagnostics

```bash
# Comprehensive HA validation with troubleshooting
setup_ha_kubernetes() {
    local verbose_mode=false
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_mode=true
                ;;
        esac
    done
    
    # Perform comprehensive HA validation
    log_info "Performing comprehensive HA validation for Kubernetes"
    
    if ! validate_ha_dependency_for_kubernetes --verbose="$verbose_mode"; then
        log_error "HA dependency validation failed"
        
        # Show detailed diagnostics
        show_ha_proxy_diagnostics "$verbose_mode"
        
        # Provide quick status check
        if check_ha_status; then
            log_warning "HA proxy appears functional despite validation failure"
        else
            log_error "HA proxy is not functional"
            return 1
        fi
    fi
    
    # Continue with HA setup...
}
```

#### HA Proxy Validation Integration

```bash
# Validate HA proxy before load balancer setup
setup_load_balancer() {
    # Quick HA status check
    if ! check_ha_status; then
        log_warning "HA proxy status check failed - performing detailed validation"
        
        if ! validate_ha_proxy_installation --verbose; then
            log_error "HA proxy validation failed"
            show_ha_troubleshooting_recommendations
            return 1
        fi
    fi
    
    # Continue with load balancer configuration...
    log_success "HA proxy validation completed"
}
```

## Complete Integration Example

Here's a complete example showing how a component can integrate all three utilities:

```bash
#!/bin/bash
# Example: Complete integration in lib/components/monitoring/prometheus.sh

install_prometheus() {
    local verbose_mode=false
    local force_update=false
    local skip_deps=false
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_mode=true
                ;;
            --force-update)
                force_update=true
                ;;
            --skip-deps)
                skip_deps=true
                ;;
        esac
    done
    
    log_step "Prometheus" "Installing Prometheus monitoring system"
    
    # 1. SYSTEM UPDATE INTEGRATION
    log_substep "Preparing system for Prometheus installation"
    
    local update_options=()
    [[ "$verbose_mode" == "true" ]] && update_options+=("--verbose")
    [[ "$force_update" == "true" ]] && update_options+=("--force-update")
    
    if ! prepare_system_for_installation "prometheus" "${update_options[@]}"; then
        log_error "Failed to prepare system for Prometheus installation"
        return 1
    fi
    
    # 2. DEPENDENCY MANAGER INTEGRATION  
    log_substep "Installing Prometheus dependencies"
    
    local dep_options=()
    [[ "$verbose_mode" == "true" ]] && dep_options+=("--verbose")
    [[ "$skip_deps" == "true" ]] && dep_options+=("--skip-deps")
    
    if ! ensure_dependencies_for_component "prometheus" "${dep_options[@]}"; then
        log_error "Failed to install dependencies for Prometheus"
        return 1
    fi
    
    # Verify monitoring-specific dependencies
    if ! validate_component_dependencies "monitoring"; then
        log_error "Monitoring dependency validation failed"
        return 1
    fi
    
    # 3. HA VALIDATION INTEGRATION (if HA is configured)
    if [[ -n "${API_SERVERS:-}" ]] || [[ -n "${HA_PROXY_PORT:-}" ]]; then
        log_substep "Validating HA configuration for Prometheus"
        
        local ha_options=()
        [[ "$verbose_mode" == "true" ]] && ha_options+=("--verbose")
        
        if ! validate_ha_setup_for_component "monitoring" "${ha_options[@]}"; then
            log_warning "HA validation failed - continuing with single-node setup"
        else
            log_success "HA validation passed - enabling HA features"
        fi
    fi
    
    # 4. COMPONENT INSTALLATION
    log_substep "Installing Prometheus components"
    
    # Start component tracking
    start_component "prometheus"
    
    # Use execution utility for Helm installation
    if ! helm_install_with_summary "prometheus" "prometheus-community/prometheus" "monitoring" "values.yaml"; then
        fail_component "prometheus" "Helm installation failed"
        return 1
    fi
    
    # Use validation utility to verify installation
    if ! validate_component_installation "prometheus"; then
        fail_component "prometheus" "Installation validation failed"
        return 1
    fi
    
    # Complete component installation
    complete_component "prometheus"
    
    # 5. POST-INSTALLATION GUIDANCE
    show_component_guidance "prometheus"
    
    log_success "Prometheus installation completed successfully"
    return 0
}

# Component-specific status function
prometheus_status() {
    # Use validation utility for status checking
    validate_component_installation "prometheus"
    
    # Use HA validation if configured
    if [[ -n "${HA_PROXY_PORT:-}" ]]; then
        check_ha_status
    fi
}
```

## Utility Function Reference

### System Update Utility Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `update_system [options]` | Main system update with caching | `update_system --verbose --force-update` |
| `update_system_with_cache` | Update with cache checking | `update_system_with_cache` |
| `force_system_update` | Bypass cache, force update | `force_system_update` |
| `ensure_system_updated <component>` | Wrapper for components | `ensure_system_updated "kubernetes"` |
| `is_system_update_cache_valid` | Check cache validity | `if is_system_update_cache_valid; then...` |
| `get_system_update_cache_status` | Get cache status info | `status=$(get_system_update_cache_status)` |
| `show_system_update_status` | Display status info | `show_system_update_status` |

### Dependency Manager Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `install_system_dependencies [options]` | Install dependencies with progress | `install_system_dependencies --component=k8s` |
| `ensure_dependencies_for_component <component>` | Component wrapper | `ensure_dependencies_for_component "vault"` |
| `verify_critical_dependencies` | Check critical deps | `verify_critical_dependencies` |
| `validate_component_dependencies <component>` | Validate specific deps | `validate_component_dependencies "monitoring"` |
| `is_dependencies_cache_valid` | Check deps cache | `if is_dependencies_cache_valid; then...` |
| `show_dependency_troubleshooting` | Show troubleshooting | Called automatically on failures |

### HA Validation Functions

| Function | Description | Usage |
|----------|-------------|-------|
| `validate_ha_proxy_installation [options]` | Validate HA proxy | `validate_ha_proxy_installation --verbose` |
| `validate_ha_dependency_for_kubernetes [options]` | K8s HA validation | `validate_ha_dependency_for_kubernetes` |
| `validate_ha_setup_for_component <component>` | Component wrapper | `validate_ha_setup_for_component "kubernetes"` |
| `check_ha_status` | Quick status check | `check_ha_status` |
| `show_ha_proxy_diagnostics` | Show diagnostics | Called automatically on failures |

## Configuration Variables

### System Update Configuration

```bash
# Cache timeout (hours)
export GOK_UPDATE_CACHE_HOURS=6

# Cache directory
export GOK_CACHE_DIR="/tmp/gok-cache"

# Verbose mode
export GOK_VERBOSE=true

# Show progress bars
export GOK_SHOW_PROGRESS=true
```

### Dependency Manager Configuration

```bash
# Dependency cache timeout (inherits from system update)
export GOK_DEPS_CACHE_HOURS=6

# Cache directory (shared with system update)
export GOK_CACHE_DIR="/tmp/gok-cache"
```

### HA Validation Configuration

```bash
# HA proxy settings
export HA_PROXY_PORT=6643
export HA_PROXY_HOSTNAME=localhost
export HA_PROXY_CONFIG_PATH="/opt/haproxy.cfg"
export HA_PROXY_CONTAINER_NAME="master-proxy"

# API servers for Kubernetes HA
export API_SERVERS="192.168.1.10:master1,192.168.1.11:master2"
```

## Error Handling Patterns

### Graceful Degradation

```bash
install_component_with_graceful_degradation() {
    local component_name="$1"
    
    # Try full system preparation
    if ! ensure_system_updated "$component_name"; then
        log_warning "System update failed - attempting with cached packages"
        
        # Continue if cache is reasonably fresh (within 24 hours)
        local cache_status=$(get_system_update_cache_status)
        if [[ "$cache_status" =~ valid:([0-9]+)h: ]] && [[ ${BASH_REMATCH[1]} -lt 24 ]]; then
            log_info "Using cached system state (${BASH_REMATCH[1]}h old)"
        else
            log_error "System update required but failed"
            return 1
        fi
    fi
    
    # Try dependency installation with fallback
    if ! ensure_dependencies_for_component "$component_name"; then
        log_warning "Full dependency installation failed - checking critical deps"
        
        if verify_critical_dependencies; then
            log_info "Critical dependencies available - continuing with reduced functionality"
        else
            log_error "Critical dependencies missing - cannot continue"
            return 1
        fi
    fi
    
    # Continue with component installation...
}
```

### Retry Logic

```bash
install_component_with_retry() {
    local component_name="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "Attempting $component_name installation (attempt $((retry_count + 1))/$max_retries)"
        
        # Try system update
        if ensure_system_updated "$component_name"; then
            # Try dependency installation
            if ensure_dependencies_for_component "$component_name"; then
                log_success "$component_name system preparation completed"
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_warning "Preparation failed - retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    log_error "$component_name system preparation failed after $max_retries attempts"
    return 1
}
```

## Best Practices

### 1. Always Check Requirements First

```bash
install_component() {
    # Check system update requirements
    if ! check_system_update_requirements; then
        log_error "System update requirements not met"
        return 1
    fi
    
    # Check dependency requirements  
    if ! check_dependency_requirements; then
        log_error "Dependency installation requirements not met"
        return 1
    fi
    
    # Continue with installation...
}
```

### 2. Use Appropriate Verbosity

```bash
install_component() {
    local verbose_mode="${GOK_VERBOSE:-false}"
    
    # Pass verbosity to utility functions
    ensure_system_updated "component" ${verbose_mode:+--verbose}
    ensure_dependencies_for_component "component" ${verbose_mode:+--verbose}
}
```

### 3. Leverage Caching Intelligently

```bash
install_multiple_components() {
    # Update system once for all components
    if ! update_system_with_cache; then
        log_error "System update failed"
        return 1
    fi
    
    # Install dependencies once for all components  
    if ! install_system_dependencies; then
        log_error "Dependency installation failed"
        return 1
    fi
    
    # Now install individual components without redundant system prep
    for component in "$@"; do
        install_single_component "$component" --skip-system-prep
    done
}
```

### 4. Provide Clear User Feedback

```bash
install_component() {
    local component_name="$1"
    
    # Show what's happening
    log_info "Preparing system for $component_name installation..."
    
    # Show cache status for transparency
    show_system_update_status
    
    # Perform installations with progress feedback
    prepare_system_for_installation "$component_name" --verbose
}
```

## Integration Checklist

When integrating these utilities into a component:

- [ ] **System Update Integration**
  - [ ] Call `ensure_system_updated` or `prepare_system_for_installation`
  - [ ] Handle force update and skip update options
  - [ ] Check cache status when appropriate

- [ ] **Dependency Manager Integration**
  - [ ] Call `ensure_dependencies_for_component` with component name
  - [ ] Verify critical dependencies with `verify_critical_dependencies`
  - [ ] Handle dependency installation failures gracefully

- [ ] **HA Validation Integration** (if component supports HA)
  - [ ] Call `validate_ha_setup_for_component` when HA is configured  
  - [ ] Handle HA validation failures appropriately
  - [ ] Provide HA-specific troubleshooting when needed

- [ ] **Error Handling**
  - [ ] Implement graceful degradation for non-critical failures
  - [ ] Provide clear error messages and troubleshooting guidance
  - [ ] Use retry logic when appropriate

- [ ] **User Experience**  
  - [ ] Respect verbose mode flags
  - [ ] Provide progress feedback for long-running operations
  - [ ] Show cache status and system information when helpful

This integration guide ensures that all components can leverage the enterprise-grade system management utilities consistently and effectively.