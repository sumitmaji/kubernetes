# GOK Modular - Kubernetes Operations Toolkit

## Overview

GOK Modular is a restructured, maintainable version of the original GOK (Kubernetes Operations Toolkit). This modular architecture breaks down the massive monolithic script into focused, reusable modules for better maintainability, testability, and collaboration.

## 🏗️ Architecture

### Directory Structure

```
gok-modular/
├── gok-new                          # Main entry script
├── lib/                            # Core library modules
│   ├── core/                      # Core functionality
│   │   ├── bootstrap.sh           # System initialization
│   │   ├── constants.sh           # Global constants
│   │   ├── environment.sh         # Environment management
│   │   ├── logging.sh             # Enhanced logging system
│   │   └── dispatcher.sh          # Command routing
│   ├── commands/                  # Command implementations
│   │   ├── install.sh             # Installation orchestration
│   │   ├── reset.sh               # Component removal
│   │   ├── help.sh                # Documentation system
│   │   └── ...                    # Other commands
│   ├── components/                # Component installers
│   │   ├── infrastructure/        # Core infrastructure
│   │   ├── security/              # Security components
│   │   ├── monitoring/            # Monitoring stack
│   │   ├── development/           # Dev environments
│   │   ├── cicd/                  # CI/CD tools
│   │   └── ...                    # Other categories
│   ├── utils/                     # Utility functions
│   │   ├── helm.sh                # Helm operations
│   │   ├── kubectl.sh             # Kubernetes utilities
│   │   └── ...                    # Other utilities
│   └── validation/                # Validation & diagnostics
├── config/                        # Configuration files
│   ├── default.conf               # Default settings
│   └── environments/              # Environment-specific configs
├── templates/                     # Template files
└── docs/                          # Documentation
    └── README.md                  # This file
```

## 🚀 Getting Started

### Prerequisites

- Linux-based operating system (Ubuntu/Debian recommended)
- Bash 4.0 or later
- Internet connectivity for component downloads
- Sudo privileges for system-level installations

### Installation

1. **Clone or copy the modular structure**:
   ```bash
   # The gok-modular directory should be in your install_k8s folder
   cd /path/to/kubernetes/install_k8s/gok-modular
   ```

2. **Make the main script executable**:
   ```bash
   chmod +x gok-new
   ```

3. **Test the installation**:
   ```bash
   ./gok-new --help
   ```

4. **Optional: Create a symlink for system-wide access**:
   ```bash
   sudo ln -s $(pwd)/gok-new /usr/local/bin/gok-new
   ```

## 📖 Usage

### Basic Commands

```bash
# Show help
./gok-new help

# Install components
./gok-new install kubernetes
./gok-new install monitoring --verbose

# Reset/uninstall components
./gok-new reset keycloak

# Check status
./gok-new status

# View component documentation
./gok-new help components
```

### Component Categories

#### Infrastructure
- **docker**: Container runtime
- **kubernetes**: K8s master node
- **kubernetes-worker**: K8s worker node
- **helm**: Package manager
- **calico**: Network plugin
- **ingress**: Traffic routing

#### Security
- **cert-manager**: Certificate management
- **keycloak**: Identity & access management
- **oauth2**: Authentication proxy
- **vault**: Secrets management
- **ldap**: Directory services

#### Monitoring
- **monitoring**: Full stack (Prometheus + Grafana)
- **prometheus**: Metrics collection
- **grafana**: Visualization
- **fluentd**: Log aggregation
- **opensearch**: Search & analytics

#### Development
- **jupyter**: Development environment
- **console**: Web management interface
- **cloudshell**: Cloud development shell

#### CI/CD
- **argocd**: GitOps delivery
- **jenkins**: CI/CD automation
- **registry**: Container registry

## 🔧 Configuration

### Environment Configuration

Edit `config/default.conf` to customize your installation:

```bash
# Domain configuration
ROOT_DOMAIN="your-domain.com"
KEYCLOAK_SUBDOMAIN="auth"
REGISTRY_SUBDOMAIN="registry"

# Identity provider
IDENTITY_PROVIDER="keycloak"

# Certificate settings
CERTMANAGER_CHALLENGE_TYPE="http01"
CERTMANAGER_EMAIL="admin@your-domain.com"
```

### Environment-Specific Configs

Create environment-specific configurations in `config/environments/`:

```bash
# config/environments/production.conf
ENVIRONMENT="production"
LOG_LEVEL="WARN"
DEFAULT_TIMEOUT="600"
```

## 🎯 Key Features

### Modular Architecture
- **Separation of Concerns**: Each module has a single responsibility
- **Reusability**: Modules can be used across different commands
- **Maintainability**: Easy to locate, understand, and modify code
- **Testability**: Individual modules can be tested in isolation

### Enhanced Logging
- **Structured Output**: Consistent, colored, and informative logs
- **Progress Tracking**: Real-time installation progress
- **Error Diagnostics**: Detailed error information and troubleshooting tips
- **Verbose Mode**: Optional detailed output for debugging

### Improved Error Handling
- **Graceful Failures**: Better error recovery and reporting
- **Troubleshooting**: Automatic suggestions for common issues
- **Validation**: Pre and post-installation checks

### Backward Compatibility
- **Same Interface**: Existing scripts and workflows continue to work
- **Legacy Support**: Original function names are preserved
- **Migration Path**: Gradual migration from monolithic to modular

## 🔄 Migration from Original GOK

### Comparison

| Aspect | Original GOK | Modular GOK |
|--------|-------------|-------------|
| **File Size** | 21,365 lines | Distributed across modules |
| **Maintainability** | Difficult | Easy |
| **Testing** | Monolithic | Module-based |
| **Debugging** | Complex | Targeted |
| **Collaboration** | Challenging | Straightforward |
| **Performance** | All functions loaded | Lazy loading |

### Migration Steps

1. **Parallel Installation**: Keep both versions during transition
2. **Feature Testing**: Verify functionality with new version
3. **Script Updates**: Update automation scripts to use new version
4. **Training**: Familiarize team with new structure
5. **Full Migration**: Replace original with modular version

## 🛠️ Development

### Adding New Components

1. **Create component module**:
   ```bash
   # Create new component in appropriate category
   vim lib/components/category/new-component.sh
   ```

2. **Implement installation function**:
   ```bash
   newComponentInst() {
       log_component_start "new-component" "Installing new component"
       
       # Installation logic here
       
       log_component_success "new-component"
   }
   ```

3. **Add to install command**:
   ```bash
   # Edit lib/commands/install.sh
   "new-component")
       newComponentInst
       ;;
   ```

4. **Add reset function** (if needed):
   ```bash
   # Create reset function and add to lib/commands/reset.sh
   newComponentReset() {
       helm_component_reset "new-component" "namespace"
   }
   ```

### Adding New Commands

1. **Create command module**:
   ```bash
   vim lib/commands/new-command.sh
   ```

2. **Implement command handler**:
   ```bash
   newCommandCmd() {
       local arg="$1"
       # Command logic here
   }
   ```

3. **Register in dispatcher**:
   ```bash
   # Edit lib/core/dispatcher.sh
   "new-command")
       newCommandCmd "$@"
       ;;
   ```

### Testing

```bash
# Test specific module
bash -n lib/components/infrastructure/kubernetes.sh

# Test complete system
./gok-new help

# Verbose testing
./gok-new install --help --verbose
```

## 🐛 Troubleshooting

### Common Issues

1. **Module Not Found**:
   ```bash
   # Ensure all modules are present
   find lib/ -name "*.sh" -exec bash -n {} \;
   ```

2. **Permission Denied**:
   ```bash
   # Make script executable
   chmod +x gok-new
   ```

3. **Function Not Available**:
   ```bash
   # Check if module is properly loaded
   ./gok-new --verbose help
   ```

### Debug Mode

```bash
# Enable verbose logging
export GOK_VERBOSE=true
./gok-new install kubernetes

# Enable bash debugging
bash -x ./gok-new install kubernetes
```

## 📚 Documentation

### Module Documentation
- Each module includes inline documentation
- Function descriptions and usage examples
- Parameter explanations and return values

### Command Help
```bash
./gok-new help                    # General help
./gok-new help install           # Install command help
./gok-new help components        # Component reference
./gok-new install kubernetes --help  # Component-specific help
```

## 🤝 Contributing

### Code Style
- Use consistent indentation (2 spaces)
- Include function documentation
- Follow bash best practices
- Add error handling for all operations

### Pull Requests
1. Test your changes thoroughly
2. Update documentation as needed
3. Ensure backward compatibility
4. Add appropriate logging

## 📄 License

This project maintains the same license as the original GOK toolkit.

## 🔗 Links

- **Original Repository**: https://github.com/sumitmaji/kubernetes
- **Documentation**: See docs/ directory
- **Issues**: Report via original repository

---

## 📈 Benefits of Modular Architecture

### For Developers
- **Easier Maintenance**: Locate and fix issues quickly
- **Better Testing**: Test individual components
- **Cleaner Code**: Focused, single-purpose modules
- **Collaboration**: Multiple developers can work simultaneously

### For Users
- **Faster Loading**: Only load required modules
- **Better Error Messages**: More specific and helpful
- **Improved Performance**: Optimized module loading
- **Enhanced Logging**: Better visibility into operations

### For Operations
- **Easier Debugging**: Isolate issues to specific modules
- **Better Monitoring**: Track component-specific metrics
- **Simplified Updates**: Update individual components
- **Reduced Risk**: Changes are contained within modules

This modular architecture transforms the complex, monolithic GOK script into a maintainable, scalable, and user-friendly toolkit while preserving all original functionality and maintaining backward compatibility.