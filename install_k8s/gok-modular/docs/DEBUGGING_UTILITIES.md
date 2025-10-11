# GOK Kubernetes Debugging Utilities

This document describes the enhanced Kubernetes debugging utilities available in the GOK modular system, based on the original `install_k8s/util` helpers but significantly enhanced with modern debugging capabilities.

## Overview

The GOK debugging utilities provide a comprehensive set of tools for troubleshooting, monitoring, and managing Kubernetes clusters. These tools are designed to be intuitive, interactive, and provide rich context to help diagnose issues quickly.

## Quick Start

```bash
# Initialize debugging session
gok debug init

# Get cluster overview
gok debug summary

# Troubleshoot cluster issues
gok debug troubleshoot

# Interactive debugging dashboard
gok debug dashboard
```

## Available Commands

### Session Management

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug init` | Initialize debugging session | Sets up context and environment |
| `gok debug context` | Show current context and namespace | Display active cluster info |
| `gok debug ns [name]` | Change namespace or list all | `gok debug ns kube-system` |

### Pod Operations

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug shell` | Interactive pod shell access | Opens shell with pod/container selection |
| `gok debug logs [pod] [container]` | Enhanced log viewer | Multiple viewing options |
| `gok debug tail [--all]` | Tail logs in real-time | `gok debug tail --all` |
| `gok debug describe [type]` | Enhanced resource description | Interactive resource selection |

### Resource Monitoring

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug watch [resource]` | Watch resource changes | `gok debug watch events` |
| `gok debug resources [type]` | Resource usage monitoring | CPU/Memory analysis |
| `gok debug pods [action]` | Advanced pod management | `gok debug pods failed` |
| `gok debug services [action]` | Service operations | Testing and analysis |

### Network & Connectivity

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug network dns` | Test DNS resolution | Comprehensive DNS testing |
| `gok debug network connectivity` | Test network connectivity | Internal/external tests |
| `gok debug forward [svc]` | Port forwarding | Interactive service selection |
| `gok debug ingress test` | Test ingress resources | Automated connectivity tests |

### Security & Configuration

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug decode` | Interactive secret decoder | Certificate and data decoding |
| `gok debug cert view` | Certificate analysis | Expiration and details |
| `gok debug config list` | ConfigMap and Secret management | Resource management |

### Cluster Analysis

| Command | Description | Example |
|---------|-------------|---------|
| `gok debug cluster status` | Cluster health overview | Complete cluster analysis |
| `gok debug troubleshoot` | Automated issue detection | Find problematic resources |
| `gok debug performance` | Performance monitoring | Resource usage analysis |
| `gok debug events` | Recent cluster events | Event timeline |

## Detailed Features

### Enhanced Pod Operations

#### Interactive Shell Access (`gbash`)
- **Automatic pod and container detection**
- **Multiple shell support** (bash, sh, zsh, custom)
- **Container type identification** (init vs main containers)
- **Error handling and fallback shells**

```bash
# Example usage
gok debug shell
# Shows interactive pod/container selection:
# 1>> nginx-deployment-abc123 main(1) init(2)
# 2>> redis-pod-def456 redis(1)
# Enter pod index: 1
# Enter container index: 1
```

#### Advanced Log Viewing (`glogs`)
- **Multiple viewing modes**:
  - Recent logs (last 100 lines)
  - Follow logs (real-time)
  - Previous container logs
  - Logs with timestamps
  - Logs since specific time
  - All logs
- **Automatic container detection**
- **Support for init containers**

#### Log Tailing (`gtail`)
- **Single pod tailing**
- **Multi-pod tailing with `--all` flag**
- **Colored output for better readability**
- **Real-time updates**

### Network Debugging

#### DNS Testing (`gnetwork dns`)
- **Internal DNS resolution testing**
- **External DNS connectivity**
- **Service discovery validation**
- **Automatic test pod creation**

#### Connectivity Testing (`gnetwork connectivity`)
- **Kubernetes API reachability**
- **External internet connectivity**
- **Service-to-service communication**
- **Temporary test pod deployment**

#### Service Testing (`gservice test`)
- **Port connectivity validation**
- **DNS resolution testing**
- **Service endpoint verification**
- **Interactive service selection**

### Security Analysis

#### Certificate Management (`gcert`)
- **Certificate listing and analysis**
- **Expiration date checking**
- **Certificate chain validation**
- **TLS secret inspection**

#### Secret Decoding (`gdecode`)
- **Interactive secret selection**
- **Automatic certificate detection**
- **Base64 decoding**
- **Certificate detail extraction**

### Troubleshooting Tools

#### Automated Issue Detection (`gtroubleshoot`)
- **Failed pod detection**
- **Pending pod analysis**
- **High restart count identification**
- **Node condition checking**
- **Storage issue detection**

#### Performance Monitoring (`gperf`)
- **CPU usage analysis**
- **Memory consumption tracking**
- **Node resource monitoring**
- **Top resource consumers**

### Interactive Dashboard (`debug dashboard`)

The debugging dashboard provides a real-time, text-based interface for cluster monitoring:

```
🐛 GOK Kubernetes Debugging Dashboard
========================================

🏥 Cluster Health
  Kubernetes master is running at https://k8s-api:6443

📍 Current Context
  Context: kubernetes-admin@kubernetes
  Namespace: default

🖥️  Nodes
  Total: 3 | Ready: 3

🔍 Pods in default
  Total: 15 | Running: 14 | Failed: 1

📰 Recent Events (Last 5)
  [Recent cluster events displayed]

🎮 Quick Actions:
  1. Pod shell access       6. Network debugging
  2. View logs             7. Troubleshoot issues
  3. Watch resources       8. Performance monitoring
  4. Describe resources    9. Change namespace
  5. Port forward          0. Exit dashboard
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEBUG_NAMESPACE` | Current debugging namespace | auto-detected |
| `DEBUG_CONTEXT` | Current kubectl context | auto-detected |
| `GOK_VERBOSE` | Enable verbose output | `false` |
| `DEBUG_SELECTED_POD` | Last selected pod | - |
| `DEBUG_SELECTED_CONTAINER` | Last selected container | - |

### Aliases and Shortcuts

The debugging utilities include helpful kubectl aliases:

```bash
# Basic operations
k          = kubectl
kgp        = kubectl get pods
kgs        = kubectl get services
kgd        = kubectl get deployments
kgi        = kubectl get ingress
kgn        = kubectl get nodes

# Resource operations
kd         = kubectl describe
ke         = kubectl edit
kl         = kubectl logs
kx         = kubectl exec -it

# File operations
kaf        = kubectl apply -f
kdf        = kubectl delete -f
```

## Advanced Features

### OAuth Integration

The utilities support OAuth authentication when available:

```bash
# Uses OAuth token if configured
gkctl get pods
```

### Multi-Resource Operations

Many commands support batch operations:

```bash
# Watch multiple resource types
gok debug watch all

# Show resources across namespaces
gpods failed  # Shows failed pods across all namespaces
```

### Enhanced Resource Filtering

Advanced filtering capabilities:

```bash
# Filter by pod status
gpods pending   # Show pending pods
gpods restart   # Show pods with high restart count
gpods resources # Show resource usage
```

### Network Analysis

Comprehensive network debugging:

```bash
# Test all ingress endpoints
gok debug ingress test

# Validate service connectivity
gok debug service test <service-name>

# Complete network analysis
gok debug network
```

## Integration with Original Utilities

The new debugging utilities maintain compatibility with the original `install_k8s/util` functions while providing enhanced capabilities:

### Migration from Original Functions

| Original | New Enhanced Version | Notes |
|----------|---------------------|-------|
| `bash()` | `gbash()` | Enhanced shell selection and error handling |
| `logs()` | `glogs()` | Multiple viewing modes and better interface |
| `ktail()` | `gtail()` | Multi-pod support and improved output |
| `desc()` | `gdesc()` | Enhanced resource selection and formatting |
| `decode()` | `gdecode()` | Certificate detection and better interface |
| `kcd()` | `gcd()` | Improved namespace switching with validation |

### Preserved Functionality

All original utility functions remain available and are enhanced:

- **Namespace switching** - More robust with validation
- **Pod selection** - Better interface with status indication
- **Log viewing** - Multiple modes and options
- **Resource description** - Enhanced formatting and selection
- **Secret decoding** - Automatic certificate detection

## Usage Examples

### Basic Troubleshooting Workflow

```bash
# 1. Initialize debugging session
gok debug init

# 2. Get cluster overview
gok debug summary

# 3. Check for issues
gok debug troubleshoot

# 4. If pods are failing, investigate
gok debug pods failed

# 5. View logs from failed pod
gok debug logs

# 6. Check network connectivity
gok debug network dns
```

### Performance Analysis Workflow

```bash
# 1. Check overall performance
gok debug performance summary

# 2. Identify resource-heavy pods
gok debug performance memory

# 3. Monitor specific namespace
gok debug ns monitoring
gok debug resources pods

# 4. Watch resource changes
gok debug watch pods
```

### Network Debugging Workflow

```bash
# 1. Test DNS resolution
gok debug network dns

# 2. Check service connectivity
gok debug service test

# 3. Validate ingress endpoints
gok debug ingress test

# 4. Test external connectivity
gok debug network connectivity
```

## Tips and Best Practices

### Effective Debugging

1. **Start with overview**: Use `gok debug summary` to get a complete picture
2. **Use interactive mode**: Most commands provide selection interfaces
3. **Leverage filtering**: Use specific actions like `gpods failed` for targeted analysis
4. **Monitor in real-time**: Use `watch` and `tail` commands for live monitoring
5. **Combine tools**: Use multiple debugging commands together for comprehensive analysis

### Performance Optimization

1. **Use namespace scoping**: Switch to specific namespaces to reduce output
2. **Filter resources**: Use specific resource types instead of `all`
3. **Limit output**: Many commands support limiting results for performance

### Security Considerations

1. **Verify contexts**: Always check current context with `gcurrent`
2. **Namespace isolation**: Be aware of which namespace you're debugging
3. **Certificate validation**: Use `gcert check` to monitor certificate expiration

## Extending the Utilities

The debugging utilities are designed to be extensible. You can add custom functions by:

1. Adding functions to existing utility files
2. Creating new utility modules in `lib/utils/`
3. Extending the dispatcher for new commands

### Custom Function Example

```bash
# Add to lib/utils/debug.sh
my_custom_debug() {
    log_info "🔧 Custom debugging function"
    # Your custom logic here
}

# Export for use
export -f my_custom_debug
```

## Troubleshooting the Debugging Tools

If the debugging utilities aren't working:

1. **Check initialization**: Run `gok debug init`
2. **Verify kubectl access**: Test `kubectl cluster-info`
3. **Check environment**: Verify `DEBUG_NAMESPACE` and `DEBUG_CONTEXT`
4. **Enable verbose mode**: Use `--verbose` flag for detailed output

## Support and Contributions

The debugging utilities are part of the GOK modular system. For issues or feature requests:

1. Check the existing functionality with `gok debug help`
2. Use verbose mode to get detailed error information
3. Verify cluster connectivity and permissions

The utilities are designed to be self-documenting - each command provides help when called without arguments or with `help` as an argument.