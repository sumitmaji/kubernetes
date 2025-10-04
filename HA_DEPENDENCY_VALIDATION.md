# HA Dependency Validation for Kubernetes Installation

## Overview
Enhanced GOK platform with comprehensive High Availability (HA) dependency validation that prevents Kubernetes installation failures by validating HA proxy requirements before proceeding.

## Key Features

### 1. Intelligent HA Requirement Detection
The system automatically detects when HA is required using multiple methods:

#### Method 1: API_SERVERS Configuration
- **Multi-master**: `API_SERVERS="11.0.0.1:master1,11.0.0.2:master2"` → HA required
- **Single-master**: `API_SERVERS="11.0.0.1:master.cloud.com"` → HA not required
- **Malformed**: `API_SERVERS="invalid-format"` → Installation fails with clear error

#### Method 2: Kubeadm Configuration Analysis
- Scans kubeadm config.yaml for `controlPlaneEndpoint` or `loadBalancerDNS`
- Extracts HA endpoint patterns like `IP:PORT`

#### Method 3: HA Proxy Port Configuration
- Default port 6443 → Single-node setup
- Custom port (e.g., 6643) → HA setup required

#### Method 4: System Resource Analysis
- High-spec systems (>8GB RAM, >4 cores, >2 network interfaces) trigger HA warnings
- Helps identify misconfigurations in enterprise environments

### 2. Comprehensive HA Proxy Validation

#### Container Status Validation
```bash
# Checks for master-proxy container
docker ps --filter "name=master-proxy"
- Running → ✅ Pass
- Stopped → ❌ Fail with container status details
- Missing → ❌ Fail with installation instructions
```

#### Network Connectivity Testing
```bash
# Tests HA proxy port accessibility
nc -z localhost:6643  # Using netcat
timeout 5 bash -c "</dev/tcp/localhost/6643"  # Fallback method
```

#### Configuration File Verification
- Checks for `/opt/haproxy.cfg` existence
- Displays configuration summary in verbose mode
- Shows bind addresses and server endpoints

### 3. Detailed Failure Diagnostics

When HA validation fails, the system provides comprehensive diagnostics:

```
🔧 HA PROXY DIAGNOSTICS:
• Container status: [docker ps output]
• Docker containers: [running containers]
• Network connectivity: Testing IP:PORT...
• Port bindings: [netstat output for HA port]
```

### 4. Clear Resolution Steps

Installation is blocked with actionable resolution steps:

```
❌ KUBERNETES INSTALLATION BLOCKED
High Availability setup is required but not properly configured.

🔧 RESOLUTION STEPS:
1. Install HA proxy first: gok install haproxy
2. Verify HA proxy is running: docker ps | grep master-proxy
3. Check HA proxy logs: docker logs master-proxy
4. Ensure API_SERVERS is correctly configured
5. Retry Kubernetes installation after HA proxy is working

💡 QUICK FIX:
Run this command to install HA proxy first:
  gok install haproxy
```

## Usage Examples

### Multi-Master Setup (HA Required)
```bash
export API_SERVERS="11.0.0.1:master1,11.0.0.2:master2"
gok install kubernetes --verbose
# → Will validate HA proxy before proceeding
# → Fails with diagnostics if HA proxy missing
# → Provides resolution steps
```

### Single-Master Setup (HA Not Required)
```bash
export API_SERVERS="11.0.0.1:master.cloud.com"
gok install kubernetes --verbose
# → Detects single-node setup
# → Skips HA validation
# → Proceeds with installation
```

### Custom HA Port Setup
```bash
export API_SERVERS="11.0.0.1:master.cloud.com"
export HA_PROXY_PORT="6643"
gok install kubernetes --verbose
# → Detects custom HA port
# → Requires HA proxy validation
# → Fails if HA proxy not configured for port 6643
```

## Verbose Mode Analysis

With `--verbose` flag, the system shows detailed analysis:

```
ℹ️ HA dependency analysis:
  • API_SERVERS: 11.0.0.1:master.cloud.com,11.0.0.2:master2.cloud.com
  • HA_PROXY_PORT: 6643
  • System resources: 7GB RAM, 8 cores
  • Network interfaces: 1
  • HA required: true
  • Reason: Multiple API servers configured
```

## Implementation Details

### Functions Added
1. `validate_ha_dependency_for_kubernetes()` - Main validation logic
2. `validate_ha_proxy_installation()` - Comprehensive HA proxy checking
3. Enhanced `installCmd()` - Strict dependency enforcement

### Integration Points
- **Before Kubernetes Installation**: Mandatory HA validation step
- **Verbose Mode Support**: Detailed analysis and diagnostics
- **Error Handling**: Clear failure messages with resolution steps
- **Docker Integration**: Container status and connectivity testing

### Validation Flow
```
Kubernetes Installation Request
    ↓
Analyze HA Requirements (4 methods)
    ↓
HA Required? → No → Proceed with Installation
    ↓ Yes
Validate HA Proxy Installation
    ↓
HA Proxy OK? → Yes → Proceed with Installation
    ↓ No
Block Installation + Show Diagnostics + Resolution Steps
```

## Benefits

1. **Prevents Installation Failures**: Catches HA issues before Kubernetes installation
2. **Clear Root Cause Analysis**: Detailed diagnostics show exactly what's wrong
3. **Actionable Resolution**: Step-by-step instructions to fix issues
4. **Intelligent Detection**: Multiple methods to detect HA requirements
5. **Comprehensive Validation**: Container, network, and configuration checks
6. **Verbose Support**: Detailed analysis for troubleshooting

## Testing Scenarios

### ✅ Validated Scenarios
- Multi-master with working HA proxy → ✅ Installation proceeds
- Multi-master with missing HA proxy → ❌ Blocked with clear diagnostics
- Single-master setup → ✅ Installation proceeds (no HA validation)
- Custom HA port with working proxy → ✅ Installation proceeds
- Custom HA port with missing proxy → ❌ Blocked with clear diagnostics
- Malformed API_SERVERS configuration → ❌ Blocked with configuration error

This comprehensive validation ensures reliable Kubernetes installations by preventing common HA-related failures.
