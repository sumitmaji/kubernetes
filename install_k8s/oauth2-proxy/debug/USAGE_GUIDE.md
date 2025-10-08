# OAuth2 Debugging Toolkit - Usage Guide

## How to Use for Change Detection

The toolkit captures complete snapshots of your OAuth2 configuration and can compare them to detect any changes you make.

### **Step 1: Create Baseline Before Changes**
```bash
./oauth2-remote-debug.sh capture
```
**Output**: Creates `results/oauth2-debug-TIMESTAMP/` with complete configuration snapshot

### **Step 2: Make Your Changes** 
Examples of changes you might make:
- Modify OAuth2 proxy arguments in gok file
- Change ingress annotations 
- Update image version
- Modify cookie settings
- Change buffer sizes

### **Step 3: Capture After Changes**
```bash
./oauth2-remote-debug.sh capture
```
**Output**: Creates new `results/oauth2-debug-TIMESTAMP2/` directory

### **Step 4: Compare the Changes**
```bash
./oauth2-remote-debug.sh compare results/oauth2-debug-TIMESTAMP/
```

**OR use the generated comparison script:**
```bash
results/oauth2-debug-TIMESTAMP2/compare_future_deployment.sh results/oauth2-debug-TIMESTAMP/
```

## **What Changes Does It Detect?**

### ✅ **Deployment Changes**
- **OAuth2 Arguments**: Any added, removed, or modified `--argument=value`
- **Environment Variables**: Changes to CLIENT_ID, CLIENT_SECRET, COOKIE_SECRET
- **Image Version**: Detects OAuth2 proxy version upgrades/downgrades
- **Resource Limits**: CPU/memory limit changes
- **Replica Count**: Scaling up/down

### ✅ **Service Changes** 
- **Port Mappings**: Changes to service ports (80→4180, metrics ports)
- **Service Type**: ClusterIP, NodePort, LoadBalancer changes
- **Endpoints**: Pod IP changes, health status changes
- **Labels/Annotations**: Service metadata modifications

### ✅ **Ingress Changes**
- **Annotations**: Buffer sizes, SSL settings, backend protocols
- **Rules**: Host changes, path modifications, backend services
- **TLS Configuration**: Certificate changes, SSL settings
- **Load Balancer**: Ingress controller changes

### ✅ **ConfigMap/Secret Changes**
- **OAuth2 Config**: Any configuration file modifications
- **Certificates**: CA cert updates, TLS cert rotations  
- **Secret Values**: Detection of secret metadata changes (not values)

### ✅ **Connectivity Changes**
- **Endpoint Status**: OAuth2 /start, /ping endpoint availability
- **Response Codes**: HTTP status code changes (200→502→200)
- **SSL/TLS**: Certificate validation, HTTPS redirect behavior

## **Example Change Detection Scenarios**

### Scenario 1: Modify Buffer Size
**Before**: `nginx.ingress.kubernetes.io/proxy-buffer-size: 128k`
**Change**: Update to `256k` in gok file
**Detection**: Toolkit will show:
```
INGRESS ANNOTATION CHANGE:
- proxy-buffer-size: 128k → 256k
```

### Scenario 2: Add New OAuth2 Argument  
**Before**: 38 arguments configured
**Change**: Add `--skip-auth-strip-headers=true`
**Detection**: Toolkit will show:
```
DEPLOYMENT ARGUMENT ADDED:
+ --skip-auth-strip-headers=true
  Explanation: Strip auth headers before passing to upstream
```

### Scenario 3: Version Upgrade
**Before**: OAuth2 Proxy v7.12.0
**Change**: Upgrade to v7.13.0
**Detection**: Toolkit will show:
```
IMAGE VERSION CHANGE:
- quay.io/oauth2-proxy/oauth2-proxy:v7.12.0
+ quay.io/oauth2-proxy/oauth2-proxy:v7.13.0
```

### Scenario 4: Service Endpoint Changes
**Before**: 1 endpoint (192.168.21.101:4180)
**Change**: Scale to 3 replicas  
**Detection**: Toolkit will show:
```
SERVICE ENDPOINTS CHANGE:
- Endpoints: 1 (192.168.21.101:4180)
+ Endpoints: 3 (192.168.21.101:4180, 192.168.21.102:4180, 192.168.21.103:4180)
```

## **Comparison Output Format**

The comparison generates detailed diff reports:

```bash
=== OAUTH2 CONFIGURATION COMPARISON ===
Baseline: results/oauth2-debug-20251007-200535/
Current:  results/oauth2-debug-20251007-200850/

DEPLOYMENT CHANGES:
✓ No changes detected

INGRESS CHANGES:  
! proxy-buffer-size: 128k → 256k

SERVICE CHANGES:
✓ No changes detected

CONNECTIVITY CHANGES:
✓ OAuth2 endpoints still responding
✓ All validation checks passed
```

## **Quick Reference Commands**

| Purpose | Command | Output |
|---------|---------|---------|
| **Baseline Capture** | `./oauth2-remote-debug.sh capture` | Complete config snapshot |
| **Quick Health Check** | `./oauth2-remote-debug.sh validate` | Fast status validation |
| **View Recent Logs** | `./oauth2-remote-debug.sh logs` | OAuth2 + nginx logs |
| **Compare Changes** | `./oauth2-remote-debug.sh compare DIR/` | Detailed diff report |
| **List Captures** | `ls -lt results/` | Show all captured snapshots |

## **Best Practices**

### ✅ **Before Making Changes**
1. **Always capture baseline first**: `./oauth2-remote-debug.sh capture`
2. **Note the timestamp** for easy reference later
3. **Document what you plan to change**

### ✅ **After Making Changes** 
1. **Capture immediately**: `./oauth2-remote-debug.sh capture`
2. **Run comparison**: Compare with previous baseline
3. **Validate functionality**: Check that OAuth2 still works
4. **Keep successful configs** as new baselines

### ✅ **Troubleshooting Failed Changes**
1. **Compare with last known good**: Use comparison tool
2. **Check validation results**: Look for failed checks
3. **Review logs**: Use logs function to see errors
4. **Rollback if needed**: Use baseline to restore config

## **File Structure**

Each capture creates:
```
results/oauth2-debug-TIMESTAMP/
├── arguments_explained.txt     # OAuth2 arguments with explanations  
├── deployment.yaml            # Full deployment configuration
├── service.yaml              # Service configuration
├── ingress.yaml              # Ingress configuration  
├── ingress_explained.txt     # Ingress annotations explained
├── validation_results.txt    # Health check results
├── oauth2_pod_logs.txt       # Application logs
├── nginx_ingress_logs.txt    # Ingress controller logs
├── mapping_analysis.txt      # Traffic flow analysis
└── compare_future_deployment.sh  # Comparison script
```

The toolkit provides **complete change visibility** - you'll see exactly what changed, when it changed, and how it affects your OAuth2 authentication flow! 🔍✨