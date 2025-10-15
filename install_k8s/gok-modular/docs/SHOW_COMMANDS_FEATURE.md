# GOK Show Commands Feature

## Overview
The `--show-commands` feature allows users to see the actual commands being executed during install and reset operations, providing transparency and debugging capabilities.

## Implementation Status
✅ **FULLY IMPLEMENTED** - The feature is already working across the GOK modular system.

## How It Works

### 1. Command Line Flag Parsing
Both `install.sh` and `reset.sh` parse the `--show-commands` flag:

```bash
--show-commands)
    export GOK_SHOW_COMMANDS="true"
    log_info "Command execution display enabled"
    ;;
```

### 2. Execution Layer Integration
The `execute_with_suppression()` function in `lib/utils/execution.sh` checks the flag and displays commands:

```bash
if [[ "$GOK_SHOW_COMMANDS" == "true" ]]; then
    log_info "Executing: $command_display"
fi
```

### 3. Automatic Activation with Verbose Mode
The feature also auto-activates when using `--verbose` flag:

```bash
update_command_display_setting() {
    if is_verbose || is_debug || [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
        export GOK_SHOW_COMMANDS="true"
    fi
}
```

## Usage Examples

### Install Commands
```bash
# Show commands during Docker installation
./gok-new install docker --show-commands

# Show commands with verbose output
./gok-new install kubernetes --verbose

# Show commands with quiet mode (only commands, no verbose logs)
./gok-new install helm --show-commands --quiet

# Use environment variable
GOK_SHOW_COMMANDS=true ./gok-new install cert-manager
```

### Reset Commands
```bash
# Show commands during cleanup
./gok-new reset ldap --show-commands

# Show commands with verbose output
./gok-new reset monitoring --verbose

# Use environment variable
GOK_SHOW_COMMANDS=true ./gok-new reset keycloak
```

## What Gets Displayed

When `--show-commands` is enabled, you'll see:

```
ℹ Executing: kubectl apply -f /path/to/manifest.yaml
ℹ Executing: helm install prometheus prometheus-community/prometheus
ℹ Executing: docker build -t myimage:latest .
ℹ Executing: systemctl restart docker
```

## Components Using This Feature

All components that use `execute_with_suppression()` automatically support this feature:

- **Infrastructure**: Docker, Kubernetes, Helm, Calico, Ingress, HAProxy
- **Security**: Cert-Manager, Keycloak, OAuth2, Vault, LDAP
- **Monitoring**: Prometheus, Grafana, Fluentd, OpenSearch
- **Development**: Dashboard, Jupyter, Che, TTY, CloudShell, Console
- **CI/CD**: ArgoCD, Jenkins, Spinnaker, Registry
- **Platform**: GOK Agent, GOK Controller, GOK Login

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GOK_SHOW_COMMANDS` | `false` | Enable command display globally |
| `GOK_VERBOSE` | `false` | Auto-enables show-commands when true |
| `GOK_DEBUG` | `false` | Auto-enables show-commands when true |

## Help Documentation

### Install Help
```bash
./gok-new install --help
```

Shows:
```
Options:
  --show-commands    Show commands being executed during installation

Examples:
  gok-new install base --show-commands       # Show commands being executed
```

### Reset Help
```bash
./gok-new reset --help
```

Shows:
```
Options:
  --show-commands    Show commands being executed during reset
```

## Technical Details

### Execution Flow
1. User runs command with `--show-commands` flag
2. Flag parser sets `GOK_SHOW_COMMANDS=true`
3. Component installation/reset begins
4. Each command execution calls `execute_with_suppression()`
5. Function checks `GOK_SHOW_COMMANDS` and logs command before execution
6. Command executes with proper error handling
7. Output continues until completion

### Error Handling
Even with `--show-commands`, error output is properly formatted:

```
❌ Command failed: kubectl apply -f manifest.yaml
Exit code: 1
Error output:
  Error from server (NotFound): namespace "test" not found
```

### Integration with Other Flags
The feature works seamlessly with other flags:

```bash
# Combine multiple flags
./gok-new install prometheus --show-commands --skip-update --force-deps
./gok-new reset keycloak --show-commands --verbose
```

## Benefits

1. **Transparency**: See exactly what commands are being executed
2. **Debugging**: Identify which command is causing issues
3. **Learning**: Understand how GOK performs installations
4. **Auditing**: Track what commands were run during installation
5. **Reproducibility**: Manually reproduce installation steps if needed

## Future Enhancements

Potential improvements:
- [ ] Add command timing information
- [ ] Save commands to a log file for replay
- [ ] Add dry-run mode (show commands without executing)
- [ ] Export commands as shell script for manual execution

## Testing

To verify the feature is working:

```bash
# Test with simple component
./gok-new install docker --show-commands 2>&1 | grep "Executing:"

# Should see multiple lines like:
# ℹ Executing: apt-get update
# ℹ Executing: apt-get install -y docker-ce
```

## Conclusion

The `--show-commands` feature is **fully functional** and integrated throughout the GOK modular system. It provides excellent transparency and debugging capabilities for both installation and reset operations.
