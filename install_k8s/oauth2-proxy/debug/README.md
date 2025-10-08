# OAuth2 Proxy Debugging Toolkit

This toolkit was created after extensive OAuth2 proxy troubleshooting to provide comprehensive debugging and validation capabilities for future deployments.

## 🎯 Purpose

After spending significant time debugging OAuth2 issues including:
- 502 Bad Gateway errors due to nginx buffer sizes
- Authentication callback failures  
- Missing upstream configuration
- SSL/TLS certificate problems
- Ingress routing issues

This toolkit captures the **working configuration** and provides validation tools to quickly diagnose similar issues in the future.

## 📁 Files Overview

```
debug/
├── oauth2-debug.sh              # Core debugging script (runs on cluster)
├── oauth2-remote-debug.sh       # Remote execution wrapper (uses gok)
├── README.md                    # This documentation
└── results/                     # Generated debug outputs
    └── oauth2-debug-YYYYMMDD-HHMMSS/
        ├── arguments_explained.txt    # OAuth2 args with explanations
        ├── service_explained.txt      # Service configuration analysis
        ├── ingress_explained.txt      # Ingress annotations explained
        ├── mapping_analysis.txt       # Traffic flow mapping
        ├── validation_results.txt     # Current config validation
        ├── deployment.yaml           # Full deployment configuration
        ├── service.yaml              # Service configuration
        ├── ingress.yaml              # Ingress configuration
        ├── oauth2_pod_logs.txt       # OAuth2 proxy logs
        ├── nginx_ingress_logs.txt    # Nginx ingress logs
        └── compare_future_deployment.sh  # Comparison script
```

## 🚀 Quick Start

### 1. Capture Current Working Configuration

```bash
cd install_k8s/oauth2-proxy/debug
./oauth2-remote-debug.sh capture
```

This will:
- ✅ Capture all OAuth2 proxy configuration
- ✅ Explain every argument and annotation
- ✅ Create traffic flow mapping
- ✅ Validate current setup
- ✅ Generate comparison baseline

### 2. Quick Validation Check

```bash
./oauth2-remote-debug.sh validate
```

Quick health check that tests:
- OAuth2 endpoints accessibility
- Pod readiness status
- Service endpoint availability
- Critical ingress annotations

### 3. Log Analysis Only

```bash
./oauth2-remote-debug.sh logs
```

Captures and analyzes logs from:
- OAuth2 proxy pods
- Nginx ingress controller
- Recent errors and issues

### 4. Compare with Baseline

```bash
./oauth2-remote-debug.sh compare results/oauth2-debug-20241007-123456
```

Compares current deployment against a previously captured baseline.

## 📋 What Gets Analyzed

### 1. **Deployment Arguments** with explanations:
- `--provider=oidc` → OAuth provider type
- `--standard-logging=true` → Enable request logging
- `--auth-logging=true` → Enable authentication logging  
- `--proxy-buffer-size=128k` → Buffer size for large headers
- And 30+ other arguments with detailed explanations

### 2. **Service Configuration**:
- Port mappings (80 → 4180)
- Endpoint health and readiness
- Load balancing configuration
- Service type and cluster IP

### 3. **Ingress Annotations** (Critical for avoiding 502 errors):
```yaml
nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
nginx.ingress.kubernetes.io/proxy-buffers: "4 256k"  
nginx.ingress.kubernetes.io/proxy-busy-buffers-size: "256k"
nginx.ingress.kubernetes.io/ssl-redirect: "true"
nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
```

### 4. **Traffic Flow Mapping**:
```
External Request → Ingress → Service → Endpoints → Pods → Upstream
     ↓              ↓         ↓         ↓         ↓        ↓
  SSL Termination  Routing   LB        Pod IPs   OAuth2   Dashboard
```

### 5. **ConfigMaps & Secrets**:
- OAuth2 client configuration
- OIDC issuer URLs
- Certificate authority data
- (Sensitive data redacted)

## 🔧 Key Debugging Scenarios

### Scenario 1: 502 Bad Gateway on Callback
**Symptom**: `/oauth2/callback` returns 502 error  
**Diagnosis**: Check proxy buffer annotations  
**Solution**: Ensure ingress has large buffer sizes

```bash
./oauth2-remote-debug.sh validate
# Look for: "⚠ Proxy buffer: NOT SET (may cause 502 errors)"
```

### Scenario 2: Authentication Works But 404 After Login
**Symptom**: Auth succeeds but redirects to 404 page  
**Diagnosis**: Missing or incorrect upstream configuration  
**Solution**: Check `--upstream` argument in deployment

### Scenario 3: SSL/Certificate Issues
**Symptom**: SSL handshake failures  
**Diagnosis**: Check certificate annotations and TLS configuration  
**Solution**: Verify cert-manager issuer and TLS secrets

### Scenario 4: No Endpoints Available
**Symptom**: Service has no endpoints  
**Diagnosis**: Pods not ready or selector mismatch  
**Solution**: Check pod status and service selectors

## 🎯 Argument Reference

The toolkit explains all OAuth2 proxy arguments. Key ones for troubleshooting:

| Argument | Purpose | Troubleshooting |
|----------|---------|-----------------|
| `--upstream` | Where to redirect after auth | Missing = 404 after login |
| `--provider=oidc` | Authentication provider | Wrong = auth failures |
| `--oidc-issuer-url` | Keycloak realm URL | Wrong = token validation fails |
| `--cookie-domain` | Cookie scope | Wrong = auth loop |
| `--standard-logging=true` | Request logging | Enable for debugging |
| `--show-debug-on-error=true` | Error details | Shows helpful error info |

## 🔍 Ingress Annotation Reference  

Critical annotations and their impact:

| Annotation | Value | Impact |
|------------|-------|--------|
| `proxy-buffer-size` | `128k` | Prevents 502 on large cookies |
| `proxy-buffers` | `4 256k` | Handles OAuth response headers |  
| `ssl-redirect` | `true` | Forces HTTPS |
| `backend-protocol` | `HTTP` | OAuth2 proxy internal protocol |

## 📊 Validation Checklist

The toolkit checks:
- ✅ Deployment exists and ready
- ✅ Service has endpoints  
- ✅ Ingress configured with proper annotations
- ✅ ConfigMaps and Secrets present
- ✅ OAuth2 endpoints responding (200/302)
- ✅ Critical buffer sizes configured
- ✅ Pod logs show no errors

## 🚨 Common Issues Detected

1. **502 Bad Gateway**: Missing proxy buffer annotations
2. **404 After Auth**: Missing `--upstream` argument  
3. **Auth Loops**: Incorrect cookie domain
4. **SSL Errors**: Wrong certificate configuration
5. **No Endpoints**: Pod readiness issues
6. **Token Validation**: Wrong OIDC URLs

## 💡 Best Practices

1. **Always capture baseline** after successful deployment
2. **Run validation** before and after changes
3. **Check logs** for authentication flow details  
4. **Compare configurations** when issues arise
5. **Use quick validate** for rapid health checks

## 🔄 Workflow for New Deployments

1. Deploy OAuth2 proxy
2. Run `./oauth2-remote-debug.sh capture` to create baseline
3. For future issues: Run `./oauth2-remote-debug.sh validate`
4. If problems: Compare with baseline using `compare` command
5. Analyze logs with `logs` command

## 📝 Example Output

```bash
$ ./oauth2-remote-debug.sh validate

OAuth2 Proxy Remote Debugging Tool
Running quick OAuth2 validation...

Testing OAuth2 endpoints:
✓ OAuth2 start endpoint: OK
✓ OAuth2 ping endpoint: OK

Checking cluster resources:
✓ Deployment: Ready (1/1)
✓ Service endpoints: 1 available
✓ Ingress: EXISTS
✓ Proxy buffer: 128k
```

## 🎉 Success Indicators

When everything is working correctly:
- All validation checks show ✓ green checkmarks
- OAuth2 start returns 302 redirect to Keycloak
- Callback processing completes without 502 errors
- Authentication flow redirects to configured upstream
- Logs show `[AuthSuccess]` messages
- No errors in ingress controller logs

This toolkit ensures you can quickly diagnose and resolve OAuth2 issues using the proven working configuration as a reference point.