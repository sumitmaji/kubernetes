# GOK-NEW "Next" Command Feature

## Overview
The `gok-new next <component>` command provides intelligent recommendations for the next component to install after completing the current component installation. It helps guide users through the optimal installation sequence for the GOK platform.

## Usage

### Basic Command
```bash
./gok-new next <component>
```

### Examples
```bash
# After installing docker
./gok-new next docker

# After installing kubernetes  
./gok-new next kubernetes

# After installing cert-manager
./gok-new next cert-manager

# After installing monitoring
./gok-new next monitoring
```

## Features

### 1. **Intelligent Recommendations**
The command uses a pre-defined dependency chain to suggest the most logical next component:
- **docker** → kubernetes
- **kubernetes** → helm
- **helm** → ingress
- **ingress** → cert-manager
- **cert-manager** → kyverno
- **kyverno** → registry
- **registry** → base
- **base** → ldap
- **ldap** → keycloak
- **keycloak** → oauth2
- **oauth2** → gok-login
- **gok-login** → rabbitmq
- **rabbitmq** → vault
- **vault** → monitoring
- **monitoring** → argocd
- **argocd** → gok-agent
- **gok-agent** → gok-controller

### 2. **Contextual Rationale**
For each recommendation, the command explains:
- **Why** the suggested component is next in the sequence
- **What** benefits it provides
- **How** it integrates with the current component

Example output for `gok-new next kubernetes`:
```
🎯 Recommended Next Step:

  Module: helm
  Purpose: Kubernetes package manager
  Command: gok-new install helm

📋 Why install helm next?
  • Kubernetes package manager for deploying applications
  • Simplifies installation of complex applications
  • Required for most GOK platform components
  • Provides version management and rollback capabilities
```

### 3. **Installation Status Check**
The command automatically detects if the suggested component is already installed:
- If installed: Shows confirmation and suggests the next component in the chain
- If not installed: Provides detailed recommendation

### 4. **Interactive Installation Prompt**
After showing the recommendation, the command prompts the user:
```
Would you like to install helm now?
(This will start the installation process)

Install helm? [y/N]:
```

- Selecting **Y/y**: Automatically starts the installation
- Selecting **N/n**: Skips installation and shows the command to run later

### 5. **Fallback Suggestions**
If no specific next component is defined (end of chain), the command shows general suggestions:
```
🎯 Suggested Next Steps:

Development Tools:
  • jenkins - CI/CD automation and pipeline management
  • argocd - GitOps continuous delivery
  • jupyter - Interactive data science and development

Observability & Monitoring:
  • monitoring - Prometheus & Grafana stack
  • fluentd - Log collection and aggregation
  • opensearch - Search and analytics engine

Service Mesh & Networking:
  • istio - Service mesh for microservices

Management & UI:
  • dashboard - Kubernetes web-based management
```

## Implementation Details

### Component Detection
The command checks if components are installed using various methods:
- **Kubernetes resources**: `kubectl get deployment/statefulset -n <namespace>`
- **System commands**: `command -v <tool>` for CLI tools
- **Service status**: For system services like Docker

### Module Information
Each component includes:
- **Name**: Component identifier
- **Description**: Brief explanation of purpose
- **Installation command**: Exact command to install
- **Rationale**: Why it's recommended next

## Supported Components

### Infrastructure
- docker, kubernetes, helm, ingress, haproxy

### Security
- cert-manager, keycloak, oauth2, vault, ldap, kyverno

### Platform
- base, registry, gok-agent, gok-controller, gok-login

### Messaging & Storage
- rabbitmq, opensearch

### Monitoring & Observability
- monitoring (Prometheus/Grafana), fluentd

### Development
- argocd, jenkins, jupyter, dashboard

### Networking
- istio

## Benefits

1. **Guided Installation Path**: No need to guess what to install next
2. **Dependency Awareness**: Ensures prerequisites are met
3. **Time Saving**: Reduces research time for optimal installation order
4. **Best Practices**: Follows recommended deployment patterns
5. **Educational**: Explains why each component is important
6. **Flexible**: Users can choose to install immediately or defer

## Integration

### Bash Completion
Tab completion is available for component names:
```bash
./gok-new next <TAB>
# Shows all supported components
```

### Post-Installation Integration
Optionally, component installations can call the next command automatically:
```bash
# At the end of a component installation
suggest_and_install_next_module "kubernetes"
```

## Help and Documentation
```bash
# Show help
./gok-new next --help
./gok-new next -h
./gok-new next help
```

## Example Workflow

```bash
# 1. Install Docker
./gok-new install docker

# 2. Check what's next
./gok-new next docker
# Output: Recommends kubernetes with explanation
# Prompt: Install kubernetes? [y/N]: y

# 3. Kubernetes is installed automatically

# 4. Check next again
./gok-new next kubernetes  
# Output: Recommends helm with explanation
# Prompt: Install helm? [y/N]: y

# 5. Continue the guided installation chain
```

## Future Enhancements

### Planned Features
1. **Auto-install mode**: `./gok-new next docker --auto` to skip prompts
2. **Show full chain**: `./gok-new next docker --show-all` to display entire remaining path
3. **Custom chains**: Allow users to define their own installation sequences
4. **Prerequisites check**: Verify all dependencies before suggesting next component
5. **Rollback support**: Ability to go back in the installation chain
6. **Multi-component suggestions**: Suggest multiple next options with rankings
7. **Platform profiles**: Pre-defined installation sequences (dev, prod, minimal, full)

## Technical Details

### Files Created/Modified
- **lib/commands/next.sh**: Main command implementation
- **lib/core/dispatcher.sh**: Added next command routing
- **lib/core/bootstrap.sh**: Added next module loading
- **gok-completion.bash**: Added tab completion support

### Key Functions
- `nextCmd()`: Main command handler
- `suggest_and_install_next_module()`: Core recommendation logic
- `check_component_installed()`: Component status detection
- `show_recommendation_rationale()`: Contextual explanations
- `show_general_next_suggestions()`: Fallback recommendations

## Troubleshooting

### Component Not Found
If a component is not recognized:
```bash
./gok-new next --help
# Shows list of supported components
```

### Installation Detection Issues
If a component shows as "not installed" but is actually installed, check:
- Namespace configuration
- Resource naming conventions
- Component deployment status with `kubectl get all -n <namespace>`

## Contributing
To add new components to the next chain:
1. Update `NEXT_MODULE_MAP` in `lib/commands/next.sh`
2. Add component description to `MODULE_DESCRIPTIONS`
3. Add installation check logic to `check_component_installed()`
4. Add rationale explanation to `show_recommendation_rationale()`
5. Update completion in `gok-completion.bash`

## Conclusion
The `gok-new next` command provides an intelligent, user-friendly way to navigate the GOK platform installation process, ensuring users follow best practices while maintaining flexibility in their deployment choices.
