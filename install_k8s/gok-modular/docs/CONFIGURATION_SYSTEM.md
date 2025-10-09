# GOK-New Configuration System Guide

## Overview

The GOK-New configuration system provides comprehensive configuration management that replicates and enhances the functionality from lines 1-88 of the original GOK file. It offers a modular, hierarchical approach to configuration loading with validation, debugging, and component integration capabilities.

## Original GOK Configuration (Lines 1-88)

The original GOK system performed these configuration tasks:

1. **Set default paths** (`MOUNT_PATH`, `WORKING_DIR`)
2. **Source config files** with basic error handling
3. **Load identity provider configurations** (OAuth0, Keycloak)
4. **Generate root_config** with certificate and service settings
5. **Source root_config** for final configuration

## GOK-New Configuration Enhancements

The modular system provides all original functionality plus:

### 🎯 **Multi-Layered Configuration Loading**
```bash
Configuration Priority (highest to lowest):
1. Runtime environment variables
2. Root configuration (generated)
3. User configuration (~/.gok/config)
4. Project configuration (install_k8s/config)
5. System configuration (/etc/gok/config)
6. VM configuration (install_cluster/vm_config)
```

### 🔧 **Enhanced Features**

| Feature | Original GOK | GOK-New | Benefits |
|---------|--------------|---------|----------|
| Configuration Loading | Single file | Multi-layered hierarchy | More flexible, overrides |
| Identity Provider Support | OAuth0, Keycloak | OAuth0, Keycloak + extensible | Same support + expandable |
| Error Handling | Basic warnings | Comprehensive validation | Better reliability |
| Component Integration | Manual sourcing | Automatic loading | Easier component development |
| Debugging | None | Detailed logging | Better troubleshooting |
| Configuration Reload | Not supported | Runtime reload | Dynamic configuration |

## Configuration File Structure

### 1. VM Configuration (`install_cluster/vm_config`)
```bash
# Cluster-level settings
export MASTER_HOST_IP=192.168.1.100
export CLUSTER_NAME=cloud.com
export DNS_DOMAIN=cloud.uat
```

### 2. Project Configuration (`install_k8s/config`)
```bash
# Project-specific settings
source $MOUNT_PATH/kubernetes/install_cluster/vm_config
export NUMBER_OF_HOSTS=1
export CLUSTER_NAME=cloud.com
export CERTIFICATE_PATH=/etc/kubernetes/pki
export SERVER_DNS=master.cloud.com,kubernetes.default.svc,localhost
export SERVER_IP="192.168.1.100,127.0.0.1"
export HA_PROXY_PORT=6643
export IDENTITY_PROVIDER=keycloak
export GOK_ROOT_DOMAIN=gokcloud.com
```

### 3. Identity Provider Configurations

#### Keycloak (`keycloak/config`)
```bash
# OAuth/OIDC Configuration for Keycloak
export OIDC_ISSUE_URL=https://keycloak.gokcloud.com/realms/GokDevelopers
export OIDC_CLIENT_ID=gok-developers-client
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=groups
export REALM=GokDevelopers
export AUTH0_DOMAIN=keycloak.gokcloud.com
export APP_HOST=kube.gokcloud.com
export JWKS_URL=$OIDC_ISSUE_URL/protocol/openid-connect/certs
```

#### OAuth0 (Built-in)
```bash
# OAuth0 configuration is built into the system
export OIDC_ISSUE_URL=https://skmaji.auth0.com/
export OIDC_CLIENT_ID=C3UHISO3z60iF1JLG8L7VPUSWOASrJfO
export OIDC_USERNAME_CLAIM=sub
export OIDC_GROUPS_CLAIM=http://localhost:8080/claims/groups
export AUTH0_DOMAIN=skmaji.auth0.com
export APP_HOST=kube.gokcloud.com
export JWKS_URL=$OIDC_ISSUE_URL/.well-known/jwks.json
```

### 4. User Configuration (`~/.gok/config`)
```bash
# User-specific settings
export GOK_DEBUG=true
export GOK_VERBOSE=true
export PREFERRED_IDENTITY_PROVIDER=keycloak
```

### 5. Generated Root Configuration (`root_config`)
```bash
# Auto-generated configuration combining all sources
export LETS_ENCRYPT_PROD_URL=https://acme-v02.api.letsencrypt.org/directory
export LETS_ENCRYPT_STAGING_URL=https://acme-staging-v02.api.letsencrypt.org/directory
export CERTMANAGER_CHALANGE_TYPE=selfsigned
export LETS_ENCRYPT_ENV=staging

# Component service names
export REGISTRY=registry
export KEYCLOAK=keycloak
export SPINNAKER=spinnaker
export VAULT=vault
export JUPYTERHUB=jupyterhub
export ARGOCD=argocd

# Domain configuration
export DEFAULT_SUBDOMAIN=kube
export GROUP_NAME=gokcloud.com
export AUTHENTICATION_METHOD=oidc
export IDENTITY_PROVIDER=keycloak

# Identity provider specific configuration (auto-generated)
export OIDC_ISSUE_URL=https://keycloak.gokcloud.com/realms/GokDevelopers
export OIDC_CLIENT_ID=gok-developers-client
# ... (additional OIDC settings)
```

## Usage in GOK-New

### Automatic Loading (Preferred Method)

The configuration system is automatically initialized by the bootstrap process:

```bash
#!/bin/bash
# Component installation function - configuration is already loaded

install_kubernetes() {
    # Configuration is automatically available
    log_info "Installing Kubernetes for cluster: $CLUSTER_NAME"
    log_info "Using identity provider: $IDENTITY_PROVIDER"
    log_info "App host: $APP_HOST"
    
    # Use configuration variables directly
    kubectl_config_setup
}
```

### Manual Configuration Loading

If you need to explicitly load configuration:

```bash
# Load configuration system
source_gok_module "config"

# Initialize and load all configuration
init_gok_configuration

# Or ensure configuration for specific component
ensure_configuration_for_component "vault"
```

### Component-Specific Configuration

Components can have their own configuration files:

```bash
# Load component-specific configuration
get_component_config "monitoring"

# This will source any of these files (if they exist):
# - install_k8s/monitoring/config
# - install_k8s/monitoring/configuration  
# - install_k8s/monitoring/.env
```

## Configuration Management Functions

### Core Functions

| Function | Description | Usage |
|----------|-------------|--------|
| `init_gok_configuration` | Initialize configuration system | `init_gok_configuration` |
| `load_gok_configuration [--force-reload]` | Load all configuration sources | `load_gok_configuration` |
| `generate_root_configuration` | Generate root config file | `generate_root_configuration` |
| `reload_configuration` | Reload all configuration | `reload_configuration` |
| `show_configuration_status` | Display configuration info | `show_configuration_status` |

### Identity Provider Functions

| Function | Description | Usage |
|----------|-------------|--------|
| `getOAuth0Config` | Get OAuth0 configuration | `config=$(getOAuth0Config)` |
| `getKeycloakConfig` | Get Keycloak configuration | `config=$(getKeycloakConfig)` |
| `get_identity_provider_config` | Get config based on IDENTITY_PROVIDER | `get_identity_provider_config` |

### Component Integration Functions

| Function | Description | Usage |
|----------|-------------|--------|
| `ensure_configuration_for_component <component>` | Ensure config loaded for component | `ensure_configuration_for_component "kubernetes"` |
| `get_component_config <component>` | Load component-specific config | `get_component_config "monitoring"` |
| `get_config_value <var> [default]` | Get config value with fallback | `get_config_value "CLUSTER_NAME" "default.com"` |
| `set_config_value <var> <value>` | Set configuration variable | `set_config_value "DEBUG_MODE" "true"` |

## Configuration Validation

The system includes comprehensive validation:

### Required Variables Check
```bash
# These variables are validated as required:
- MOUNT_PATH
- WORKING_DIR  
- IDENTITY_PROVIDER
- AUTHENTICATION_METHOD
```

### Path Validation
```bash
# These paths are validated to exist:
- $MOUNT_PATH (repository root)
- $WORKING_DIR (install_k8s directory)
```

### Identity Provider Validation
```bash
# Keycloak validation checks:
- OIDC_ISSUE_URL
- OIDC_CLIENT_ID  
- REALM

# OAuth0 validation checks:
- OIDC_ISSUE_URL
- OIDC_CLIENT_ID
- AUTH0_DOMAIN
```

## Environment Variables

### Configuration Control

| Variable | Default | Description |
|----------|---------|-------------|
| `MOUNT_PATH` | `/home/sumit/Documents/repository` | Repository root path |
| `WORKING_DIR` | `$MOUNT_PATH/kubernetes/install_k8s` | Working directory |
| `IDENTITY_PROVIDER` | `keycloak` | Identity provider (keycloak, auth0, oauth0) |
| `AUTHENTICATION_METHOD` | `oidc` | Authentication method |
| `GOK_ROOT_DOMAIN` | `gokcloud.com` | Root domain for services |
| `DEFAULT_SUBDOMAIN` | `kube` | Default subdomain |

### Debugging and Control

| Variable | Default | Description |
|----------|---------|-------------|
| `GOK_CONFIG_DEBUG` | `false` | Enable configuration debugging |
| `GOK_CONFIG_STRICT` | `false` | Enable strict validation mode |
| `GOK_CONFIG_DIR` | `$HOME/.gok` | User configuration directory |

## Migration from Original GOK

### What Stays the Same

✅ **Configuration file formats** - No changes needed  
✅ **Identity provider support** - OAuth0 and Keycloak work identically  
✅ **Variable names** - All original variables are preserved  
✅ **File locations** - Same paths and file names  
✅ **root_config generation** - Same format and content  

### What's Enhanced

🚀 **Multi-layered loading** - More configuration sources  
🚀 **Error handling** - Better validation and error messages  
🚀 **Component integration** - Easier for components to use  
🚀 **Debugging** - Detailed logging and status information  
🚀 **Runtime reload** - Can reload configuration without restart  

### Migration Steps

1. **No changes needed** - Existing configuration files work as-is
2. **Optional enhancements** - Add user configuration if desired
3. **Component updates** - Components can use new helper functions
4. **Debugging** - Enable `GOK_CONFIG_DEBUG=true` for troubleshooting

## Troubleshooting

### Common Issues

**Configuration not loading:**
```bash
# Check configuration status
show_configuration_status

# Enable debug mode
export GOK_CONFIG_DEBUG=true
init_gok_configuration
```

**Missing identity provider configuration:**
```bash
# Verify identity provider setting
echo "Identity Provider: $IDENTITY_PROVIDER"

# Check if config file exists
ls -la $WORKING_DIR/keycloak/config
```

**Path issues:**
```bash
# Verify paths are correct
echo "MOUNT_PATH: $MOUNT_PATH"
echo "WORKING_DIR: $WORKING_DIR"

# Check if directories exist
ls -la $MOUNT_PATH
ls -la $WORKING_DIR
```

### Debug Mode

Enable detailed logging:
```bash
export GOK_CONFIG_DEBUG=true
export GOK_DEBUG=true
init_gok_configuration
```

### Validation Errors

Enable strict mode for detailed validation:
```bash
export GOK_CONFIG_STRICT=true
load_gok_configuration
```

## Examples

### Basic Usage
```bash
# Initialize configuration (done automatically by bootstrap)
init_gok_configuration

# Use configuration in component
install_my_component() {
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Domain: $GOK_ROOT_DOMAIN"
    log_info "Identity Provider: $IDENTITY_PROVIDER"
}
```

### Advanced Usage
```bash
# Component with configuration validation
install_secure_component() {
    # Ensure configuration is loaded
    ensure_configuration_for_component "security"
    
    # Validate required settings
    if [[ -z "$OIDC_ISSUE_URL" ]]; then
        log_error "OIDC configuration missing"
        return 1
    fi
    
    # Load component-specific config
    get_component_config "vault"
    
    # Continue with installation
    setup_vault_with_oidc
}
```

### Dynamic Configuration
```bash
# Reload configuration at runtime
reload_configuration

# Change identity provider
set_config_value "IDENTITY_PROVIDER" "auth0"
generate_root_configuration

# Show current status
show_configuration_status
```

The GOK-New configuration system provides a robust, backward-compatible replacement for the original GOK configuration loading while adding powerful new capabilities for component integration and system management.