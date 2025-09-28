# DevWorkspace V2 Quick Reference

## Quick Start Commands

### Create Workspace
```bash
# From gok script
./gok
> createDevWorkspaceV2

# Direct execution (if gok is sourced)
source gok && createDevWorkspaceV2
```

### Delete Workspace
```bash
# From gok script
./gok
> deleteDevWorkspaceV2

# Direct execution (if gok is sourced)
source gok && deleteDevWorkspaceV2
```

---

## Workspace Types Quick Reference

| Index | Type | Description | Use Case |
|-------|------|-------------|----------|
| 1 | `core-java` | Basic Java development | Learning Java, simple projects |
| 2 | `springboot-web` | Spring Boot web applications | Web development, REST APIs |
| 3 | `python-web` | Python web development | Flask/Django applications |
| 4 | `springboot-backend` | Spring Boot backend services | Microservices, API development |
| 5 | `tensorflow` | Machine learning with TensorFlow | AI/ML development, data science |
| 6 | `microservice-study` | Microservices architecture | Distributed systems learning |
| 7 | `javaparser` | Java code analysis | Code parsing, AST manipulation |
| 8 | `nlp` | Natural Language Processing | Text analysis, language models |
| 9 | `kubeauthentication` | Kubernetes authentication | K8s security, auth development |

---

## Common Usage Patterns

### Standard Development Workflow

1. **Create Workspace**
   ```bash
   createDevWorkspaceV2
   # Enter: myuser
   # Select: 2 (springboot-web)
   ```

2. **Access Workspace**
   - Navigate to Eclipse Che dashboard
   - Find workspace: `spring` in namespace `myuser`
   - Click to open workspace

3. **Develop and Test**
   - Use integrated IDE features
   - Run/debug applications
   - Access via exposed endpoints

4. **Cleanup When Done**
   ```bash
   deleteDevWorkspaceV2
   # Enter: myuser  
   # Select: 2 (springboot-web)
   ```

### Team Development Setup

```bash
# Create workspaces for team members
for user in developer1 developer2 developer3; do
    echo -e "$user\n2" | createDevWorkspaceV2  # Spring Boot web
done
```

### Automated Testing Environment

```bash
# Create test environment
export CHE_USER_NAME="test-env-$(date +%s)"
export WORKSPACE_TYPE="springboot-web"
echo -e "$CHE_USER_NAME\n2" | createDevWorkspaceV2

# Run tests...

# Cleanup
echo -e "$CHE_USER_NAME\n2" | deleteDevWorkspaceV2
```

---

## Troubleshooting Quick Fixes

### Workspace Won't Start
```bash
# Check status
kubectl get devworkspace -n <username>
kubectl describe devworkspace <workspace-name> -n <username>

# Check pods
kubectl get pods -n <username>
kubectl logs -n <username> <pod-name>
```

### PVC Issues
```bash
# Check PVC
kubectl get pvc -n <username>

# Check available PVs
kubectl get pv | grep Available

# Manual PV release
kubectl patch pv <pv-name> -p '{"spec":{"claimRef":null}}'
```

### ConfigMap Problems
```bash
# List ConfigMaps
kubectl get configmap -n <username>

# Recreate ConfigMaps manually
cd eclipseche/workspace/<type>
python3 create_config.py <username>
```

### Permission Errors
```bash
# Check permissions
kubectl auth can-i create devworkspace --as=system:serviceaccount:<username>:default

# Check namespace
kubectl get ns <username>
```

---

## Environment Variables Override

### Skip Prompts
```bash
# Set before calling function
export CHE_USER_NAME="developer"
export WORKSPACE_TYPE="springboot-web"

# These will skip interactive prompts
createDevWorkspaceV2
```

### Custom Timeout
```bash
export DW_TIMEOUT_SECONDS="1800"  # 30 minutes
createDevWorkspaceV2
```

### Debug Mode
```bash
# Enable verbose output
export DEBUG="true"
createDevWorkspaceV2
```

---

## Workspace Access URLs

After creation, workspaces are typically accessible at:
```
https://<workspace-name>-<username>.che.<domain>
```

Example:
```
https://spring-myuser.che.gokcloud.com
```

---

## Resource Requirements

### Minimum Cluster Resources
- **CPU**: 4 cores minimum for decent performance
- **Memory**: 8GB RAM minimum 
- **Storage**: 20GB available PV space
- **Network**: Ingress controller with TLS support

### Per-Workspace Resources
| Workspace Type | CPU Request | Memory Request | Storage |
|----------------|-------------|----------------|---------|
| core-java | 100m | 2Gi | 1Gi |
| springboot-web | 200m | 4Gi | 2Gi |
| python-web | 100m | 3Gi | 1Gi |
| tensorflow | 500m | 6Gi | 5Gi |

---

## File Locations

```
kubernetes/install_k8s/
├── gok                              # Main script with V2 functions
├── eclipseche/
│   ├── DevWorkspaceV2_Documentation.md  # This documentation
│   ├── create_devworkspace.py           # V2 Python backend
│   ├── apply_devworkspace.py            # V1 Python backend  
│   └── workspace/                       # Workspace templates
│       ├── java/21/
│       │   ├── core/devworkspace.yaml
│       │   ├── spring/web/devworkspace.yaml
│       │   └── javaparser/devworkspace.yaml
│       ├── python/
│       │   ├── python-web-project/devworkspace.yaml
│       │   ├── tensorflow/devworkspace.yaml
│       │   └── nlp/devworkspace.yaml
│       └── java/
│           └── microservice-study/devworkspace.yaml
```

---

## Migration Checklist

- [ ] Review current V1 usage patterns
- [ ] Map existing manifests to V2 workspace types
- [ ] Test V2 functions in development environment
- [ ] Update automation scripts for new prompt format
- [ ] Train team members on new workflow
- [ ] Migrate existing workspaces gradually
- [ ] Update documentation and procedures

---

## Support and Resources

### Getting Help
1. Check this documentation first
2. Review logs: `kubectl logs` and `kubectl describe`
3. Verify prerequisites and permissions
4. Test with minimal configuration
5. Check Eclipse Che operator logs if needed

### Useful Commands
```bash
# List all DevWorkspaces across namespaces
kubectl get devworkspace -A

# Monitor workspace events
kubectl get events -n <username> --watch

# Check Eclipse Che operator status
kubectl get pods -n eclipse-che

# Verify DevWorkspace operator
kubectl get pods -n devworkspace-controller-manager
```