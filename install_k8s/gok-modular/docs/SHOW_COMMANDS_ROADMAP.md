# --show-commands Feature: Complete Implementation Guide

## ✅ COMPLETED WORK

### 1. Core Infrastructure
- ✅ Created `show_command()` helper function
- ✅ Created `show_command_with_secrets()` helper function for masking sensitive data
- ✅ Updated `lib/utils/execution.sh` with new functions
- ✅ Exported functions for use across all components

### 2. LDAP Component (Reference Implementation)
- ✅ Updated docker build to show command with masked password
- ✅ Updated docker tag to show command
- ✅ Updated docker push to show command
- ✅ Updated helm deployment to show command with 4 masked secrets
- ✅ Fully tested and working

### 3. Documentation
- ✅ `docs/SHOW_COMMANDS_FEATURE.md` - User-facing feature documentation
- ✅ `docs/DEVELOPER_GUIDE_SHOW_COMMANDS.md` - Comprehensive developer guide
- ✅ `docs/IMPLEMENTATION_SUMMARY_SHOW_COMMANDS.md` - Implementation details
- ✅ `examples/show-commands-examples.sh` - Quick reference examples

### 4. Tools
- ✅ `scripts/audit-show-commands.sh` - Automated audit script to identify components needing updates

## 🔄 REMAINING WORK (30 commands across 8 components)

### High Priority Components

#### 1. security/ldap.sh (3 commands)
```bash
# Lines that still need wrapping (false positives from audit):
# These are background commands already wrapped with show_command_with_secrets
# Status: ✅ Actually complete - audit detected background process syntax
```

#### 2. security/keycloak.sh (5 commands)
```bash
# Line 216: helm upgrade --install
show_command_with_secrets \
    "helm upgrade --install keycloak ..." \
    "$ADMIN_PASS" "***"

# Lines 118, 130: kubectl create secret
show_command_with_secrets \
    "kubectl create secret generic keycloak-secrets ..." \
    "$SECRET" "***"

# Line 834: kubectl delete secret
show_command "kubectl delete secret oauth-secrets -n kube-system"
```

#### 3. infrastructure/kubernetes.sh (8 commands)
```bash
# Lines 903-907: helm repo commands
show_command "helm repo add \"$name\" \"$url\""
show_command "helm repo update"

# Lines 804-806: kubectl get commands (diagnostic)
show_command "kubectl get nodes"
show_command "kubectl get pods -n kube-system"

# Line 1165: kubectl apply (Calico)
show_command "kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml"
```

#### 4. base/base.sh (2 commands)
```bash
# Line 125: docker build
show_command_with_secrets \
    "docker build ..." \
    "$BUILD_ARG_VALUE" "***"

# Line 205: docker push (background)
show_command "docker push \"$full_image_url\""
```

### Medium Priority Components

#### 5. security/authentication.sh (3 commands)
```bash
# Line 31: kubectl create secret with API key
show_command_with_secrets \
    "kubectl create secret generic godaddy-api-key-secret --from-literal=api-key=$API_KEY ..." \
    "$API_KEY" "***"

# Lines 42-43: kubectl delete commands
show_command "kubectl delete -f https://..."
show_command "kubectl delete secret godaddy-api-key-secret -n cert-manager"
```

#### 6. platform/gok-services.sh (5 commands)
```bash
# Diagnostic/example commands - lower priority
# Lines 262, 265, 268: kubectl exec commands
show_command "kubectl get pods -n gok-debug -o wide"
show_command "kubectl exec -it -n gok-debug ds/gok-debug-toolkit -- bash"
show_command "kubectl exec -n gok-debug ds/gok-debug-toolkit -- netstat -tuln"
```

### Low Priority Components

#### 7. monitoring/prometheus.sh (1 command)
```bash
# Line 314: kubectl wait
show_command "kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system"
```

#### 8. networking/servicemesh.sh (3 commands)
```bash
# Lines 84, 413, 548: kubectl label and wait commands
show_command "kubectl label namespace \"$gateway_namespace\" istio-injection=enabled --overwrite"
show_command "kubectl wait --for=condition=available --timeout=300s deployment/calico-kube-controllers -n calico-system"
show_command "kubectl wait --namespace metallb-system ..."
```

## 📋 Work Priority Matrix

### Priority 1 (Critical - User-Facing)
1. **Kubernetes Installation** (8 commands)
   - Most important component
   - Shows cluster setup commands
   - Estimated time: 30 minutes

2. **Keycloak** (5 commands)
   - Security component
   - Has sensitive data
   - Estimated time: 20 minutes

3. **Base Platform** (2 commands)
   - Core infrastructure
   - Docker operations
   - Estimated time: 15 minutes

### Priority 2 (Important - Security)
4. **Authentication** (3 commands)
   - API keys need masking
   - Estimated time: 15 minutes

### Priority 3 (Nice to Have - Diagnostics)
5. **GOK Services** (5 commands)
   - Mostly diagnostic commands
   - Estimated time: 20 minutes

6. **Prometheus** (1 command)
   - Single wait command
   - Estimated time: 5 minutes

7. **Service Mesh** (3 commands)
   - Network operations
   - Estimated time: 15 minutes

### Total Estimated Time: ~2 hours

## 🚀 Quick Start Guide for Updates

### Step 1: Source the Helper Functions
Already available - no action needed! Functions are exported from `lib/utils/execution.sh`

### Step 2: Update a Component File

```bash
# Open the file
vim lib/components/security/keycloak.sh

# Find the command (e.g., line 216)
helm upgrade --install keycloak codecentric/keycloakx \
    --set postgresql.auth.password="$DB_PASSWORD"

# Add show_command_with_secrets before it
show_command_with_secrets \
    "helm upgrade --install keycloak codecentric/keycloakx --set postgresql.auth.password=\"$DB_PASSWORD\"" \
    "$DB_PASSWORD" "***"

helm upgrade --install keycloak codecentric/keycloakx \
    --set postgresql.auth.password="$DB_PASSWORD"
```

### Step 3: Test the Changes

```bash
# Test with --show-commands flag
./gok-new install keycloak --show-commands

# Verify output shows:
# ℹ Executing: helm upgrade --install keycloak ... --set postgresql.auth.password="***"
```

### Step 4: Run Audit Again

```bash
./scripts/audit-show-commands.sh | grep keycloak
# Should show: ✅ security/keycloak.sh - No issues found
```

## 📊 Progress Tracking

Use this checklist to track progress:

```
Infrastructure Components:
[ ] kubernetes.sh (8 commands) - Priority 1
[ ] base.sh (2 commands) - Priority 1

Security Components:
[ ] keycloak.sh (5 commands) - Priority 1
[ ] authentication.sh (3 commands) - Priority 2
[✅] ldap.sh - COMPLETE

Platform Components:
[ ] gok-services.sh (5 commands) - Priority 3

Monitoring Components:
[ ] prometheus.sh (1 command) - Priority 3

Networking Components:
[ ] servicemesh.sh (3 commands) - Priority 3

Total: 27 commands remaining across 7 components
```

## 🎯 Success Criteria

A component is considered complete when:

1. ✅ All direct commands have `show_command` or `show_command_with_secrets` wrapper
2. ✅ All sensitive data is properly masked with `***`
3. ✅ Audit script shows no issues for that component
4. ✅ Manual test with `--show-commands` displays all commands
5. ✅ No sensitive data visible in output

## 📚 Reference Documentation

- **User Guide**: `docs/SHOW_COMMANDS_FEATURE.md`
- **Developer Guide**: `docs/DEVELOPER_GUIDE_SHOW_COMMANDS.md`
- **Implementation Details**: `docs/IMPLEMENTATION_SUMMARY_SHOW_COMMANDS.md`
- **Examples**: `examples/show-commands-examples.sh`

## 🧪 Testing Commands

```bash
# Test individual component
./gok-new install kubernetes --show-commands

# Test with verbose (auto-enables show-commands)
./gok-new install keycloak --verbose

# Test with environment variable
GOK_SHOW_COMMANDS=true ./gok-new install base

# Run audit to verify
./scripts/audit-show-commands.sh
```

## ✨ Benefits Summary

### For Users
- 🔍 See exactly what's being installed
- 🐛 Debug issues faster
- 📚 Learn Docker/Kubernetes commands
- 🔐 Verify no credential exposure

### For Developers
- 🧪 Easier testing and verification
- 📝 Commands serve as documentation
- 🔧 Faster troubleshooting
- 🚀 Better development experience

## 🎉 Current Status

**✅ Core Feature: 100% Complete**
- Helper functions implemented
- LDAP reference implementation complete
- Comprehensive documentation created
- Audit tools available

**🔄 Component Coverage: ~10% Complete**
- 1 out of 8 flagged components updated (LDAP)
- 27 commands remaining across 7 components
- Clear roadmap for remaining work

**📈 Next Milestone**
Update Priority 1 components:
1. Kubernetes (8 commands)
2. Keycloak (5 commands)
3. Base (2 commands)

This will bring coverage to ~55% and cover the most critical user-facing components.

---

## 🚀 Ready to Start?

1. Read the developer guide: `cat docs/DEVELOPER_GUIDE_SHOW_COMMANDS.md`
2. Pick a component from Priority 1
3. Follow the pattern from LDAP implementation
4. Test with `--show-commands` flag
5. Run audit script to verify
6. Mark as complete in this document

**Let's make GOK installations transparent and debuggable! 🎯**
