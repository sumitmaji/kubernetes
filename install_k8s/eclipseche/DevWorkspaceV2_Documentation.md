# Eclipse Che DevWorkspace V2 Functions Documentation

## Overview

The `createDevWorkspaceV2` and `deleteDevWorkspaceV2` functions are enhanced versions of the original DevWorkspace management functions, designed to provide a streamlined, type-based approach to creating and managing Eclipse Che workspaces in Kubernetes environments.

## Key Differences from V1

| Feature | V1 Functions | V2 Functions |
|---------|--------------|--------------|
| **Workspace Selection** | Manual file path input | Pre-defined workspace types with interactive selection |
| **Configuration** | Requires manifest file path | Automatic workspace type mapping |
| **Python Script** | Uses `apply_devworkspace.py` | Uses `create_devworkspace.py` |
| **Workspace Mapping** | Manual workspace naming | Intelligent workspace name mapping |
| **User Experience** | More manual configuration | Simplified type-based selection |

---

## Function: `createDevWorkspaceV2`

### Purpose
Creates a new Eclipse Che DevWorkspace using a predefined workspace type system, automatically handling workspace configuration, dependencies, and ConfigMap generation.

### Usage
```bash
# Call from gok script
createDevWorkspaceV2

# Or directly via function call (if gok is sourced)
source gok
createDevWorkspaceV2
```

### Interactive Flow

#### 1. User Input Collection
```bash
Enter username (user1): [INPUT]  # Default: user1
```

#### 2. Workspace Type Selection
```
Select workspace type:
1 => core-java
2 => springboot-web
3 => python-web
4 => springboot-backend
5 => tensorflow
6 => microservice-study
7 => javaparser
8 => nlp
9 => kubeauthentication

Enter workspace type index (1): [INPUT]  # Default: 1
```

### Workspace Type Mapping

| Index | Workspace Type | Internal Name | Directory Path |
|-------|----------------|---------------|----------------|
| 1 | `core-java` | `java` | `workspace/java/21/core` |
| 2 | `springboot-web` | `spring` | `workspace/java/21/spring/web` |
| 3 | `python-web` | `python` | `workspace/python/python-web-project` |
| 4 | `springboot-backend` | `spring` | `workspace/java/21/spring/springboot-backend-project` |
| 5 | `tensorflow` | `tensorflow` | `workspace/python/tensorflow` |
| 6 | `microservice-study` | `microservice-study` | `workspace/java/microservice-study` |
| 7 | `javaparser` | `javaparser` | `workspace/java/21/javaparser` |
| 8 | `nlp` | `nlp` | `workspace/python/nlp` |
| 9 | `kubeauthentication` | `kubeauthentication` | `workspace/java/kubeauthentication` |

### Environment Variables Set

```bash
CHE_USER_NAMESPACE="$USERNAME"     # Kubernetes namespace (same as username)
CHE_USER_NAME="$USERNAME"          # Eclipse Che username
CHE_WORKSPACE_NAME="$WORKSPACE"    # Mapped workspace name
WORKSPACE_TYPE="$WORKSPACE_TYPE"   # Selected workspace type
DW_DELETE="false"                  # Create mode flag
```

### Dependencies Installed

The function automatically installs required Python packages:
- `python3-kubernetes` - Kubernetes Python client library
- `python3-yaml` - YAML processing library

### Execution Process

1. **Input Collection**: Prompts for username and workspace type
2. **Type Mapping**: Maps workspace type index to internal names and directory paths
3. **Environment Setup**: Sets required environment variables
4. **Dependency Check**: Installs missing Python dependencies
5. **Script Execution**: Runs `create_devworkspace.py` with configured environment
6. **ConfigMap Generation**: Automatically creates ConfigMaps for workspace files

### Example Usage

```bash
# Example session
=== Create Che DevWorkspace ===
Enter username (user1): myuser
Select workspace type:
1 => core-java
2 => springboot-web
...
Enter workspace type index (1): 2

# Results in:
# - Namespace: myuser
# - Workspace Type: springboot-web
# - Workspace Name: spring
# - Directory: workspace/java/21/spring/web
```

---

## Function: `deleteDevWorkspaceV2`

### Purpose
Deletes an existing Eclipse Che DevWorkspace and performs comprehensive cleanup including PVC release and namespace deletion.

### Usage
```bash
# Call from gok script
deleteDevWorkspaceV2

# Or directly via function call (if gok is sourced)
source gok
deleteDevWorkspaceV2
```

### Interactive Flow

#### 1. User Input Collection
```bash
Enter username (user1): [INPUT]  # Default: user1
```

#### 2. Workspace Type Selection
```
Select workspace type:
1 => core-java
2 => springboot-web
3 => python-web
4 => springboot-backend
5 => tensorflow
6 => microservice-study
7 => javaparser
8 => nlp
9 => kubeauthentication

Enter workspace type index (1): [INPUT]  # Default: 1
```

### Environment Variables Set

```bash
CHE_USER_NAMESPACE="$USERNAME"     # Target namespace for deletion
CHE_USER_NAME="$USERNAME"          # Eclipse Che username
CHE_WORKSPACE_NAME="$WORKSPACE"    # Mapped workspace name
WORKSPACE_TYPE="$WORKSPACE_TYPE"   # Selected workspace type
DW_DELETE="true"                   # Delete mode flag
```

### Cleanup Operations

The deletion process performs comprehensive cleanup:

1. **DevWorkspace Deletion**: Removes the DevWorkspace custom resource
2. **PVC Cleanup**: Deletes associated PersistentVolumeClaims
3. **PV Release**: Releases bound PersistentVolumes for reuse
4. **Namespace Deletion**: Removes the user namespace
5. **ConfigMap Cleanup**: Removes generated ConfigMaps

---

## Backend Implementation

### Python Script: `create_devworkspace.py`

The V2 functions use the enhanced `create_devworkspace.py` script which provides:

#### Automatic Workspace Detection
```python
workspace_map = {
    "core-java": "workspace/java/21/core",
    "springboot-web": "workspace/java/21/spring/web",
    "python-web": "workspace/python/python-web-project",
    # ... other mappings
}
```

#### ConfigMap Generation
- Automatically runs `create_config.py` in workspace directories
- Generates ConfigMaps for all files in the workspace
- Handles volume mounting and path configuration

#### Comprehensive Error Handling
- Validates workspace directories exist
- Provides detailed error messages
- Handles Kubernetes API exceptions gracefully

---

## Prerequisites

### System Requirements
- Kubernetes cluster with Eclipse Che installed
- DevWorkspace Operator deployed
- kubectl configured with cluster access
- Python 3 with kubernetes and yaml libraries

### Eclipse Che Configuration
- Eclipse Che dashboard accessible
- User authentication configured (OAuth2 proxy supported)
- DevWorkspace CRDs installed
- Appropriate RBAC permissions for workspace creation

### Workspace Directory Structure
```
eclipseche/
├── workspace/
│   ├── java/
│   │   ├── 21/
│   │   │   ├── core/
│   │   │   │   ├── devworkspace.yaml
│   │   │   │   └── create_config.py
│   │   │   ├── spring/
│   │   │   │   └── web/
│   │   │   │       ├── devworkspace.yaml
│   │   │   │       └── create_config.py
│   │   │   └── javaparser/
│   │   └── microservice-study/
│   └── python/
│       ├── python-web-project/
│       ├── tensorflow/
│       └── nlp/
└── create_devworkspace.py
```

---

## Workspace Templates

### Java Core Development (core-java)
- **Image**: `quay.io/devfile/universal-developer-image:latest`
- **Memory**: 4Gi
- **Features**: Maven, OpenJDK 21, Git
- **Volume Mounts**: Maven repository (`/home/user/.m2`)
- **Commands**: Build, Run, Debug

### Spring Boot Web (springboot-web)
- **Image**: `quay.io/devfile/universal-developer-image:latest`
- **Memory**: 4Gi
- **Features**: Spring Boot, Maven, Hot reload
- **Ports**: 8080 (HTTP), 5005 (Debug)
- **Commands**: Spring Boot run, Maven build

### Python Web Project (python-web)
- **Image**: `quay.io/devfile/universal-developer-image:latest`
- **Memory**: 3Gi
- **Features**: Python 3, pip, Flask/Django support
- **Volume Mounts**: pip cache
- **Commands**: Run server, Install dependencies

### TensorFlow Development (tensorflow)
- **Image**: `tensorflow/tensorflow:latest-jupyter`
- **Memory**: 6Gi
- **Features**: TensorFlow, Jupyter, NumPy, Pandas
- **GPU**: Optional GPU support configuration
- **Commands**: Jupyter start, Training scripts

---

## Troubleshooting

### Common Issues

#### 1. Workspace Creation Fails
```bash
# Check DevWorkspace status
kubectl get devworkspace -n <username>
kubectl describe devworkspace <workspace-name> -n <username>

# Check pod logs
kubectl logs -n <username> -l controller.devfile.io/devworkspace_name=<workspace-name>
```

#### 2. PVC Issues
```bash
# Check PVC status
kubectl get pvc -n <username>

# Check PV availability
kubectl get pv | grep Available
```

#### 3. ConfigMap Generation Fails
```bash
# Check if create_config.py exists
ls -la workspace/<type>/create_config.py

# Run manually for debugging
cd workspace/<type>
python3 create_config.py <username>
```

### Error Resolution

#### Permission Denied
```bash
# Ensure proper RBAC permissions
kubectl auth can-i create devworkspace --as=<username>
kubectl auth can-i create configmap --as=<username>
```

#### Namespace Issues
```bash
# Check namespace existence and permissions
kubectl get ns <username>
kubectl describe ns <username>
```

#### Python Dependencies
```bash
# Manual installation if automatic fails
apt-get update
apt-get install -y python3-kubernetes python3-yaml
```

---

## Advanced Usage

### Custom Environment Variables

You can override default behavior by setting environment variables before calling the functions:

```bash
# Custom timeout for workspace startup
export DW_TIMEOUT_SECONDS="1200"  # 20 minutes

# Custom workspace type (bypass interactive selection)
export WORKSPACE_TYPE="springboot-web"

# Custom username (bypass prompt)
export CHE_USER_NAME="developer"

# Call function with custom settings
createDevWorkspaceV2
```

### Batch Operations

For automation scenarios:

```bash
#!/bin/bash
# Batch workspace creation script

users=("user1" "user2" "user3")
workspace_types=("core-java" "springboot-web" "python-web")

for i in "${!users[@]}"; do
    export CHE_USER_NAME="${users[$i]}"
    export WORKSPACE_TYPE="${workspace_types[$i]}"
    
    # Auto-answer prompts with expect or similar
    echo -e "${users[$i]}\n$((i+1))" | createDevWorkspaceV2
done
```

### Integration with CI/CD

```yaml
# GitLab CI example
create-dev-environment:
  stage: setup
  script:
    - source /path/to/gok
    - export CHE_USER_NAME="$CI_COMMIT_REF_SLUG"
    - export WORKSPACE_TYPE="springboot-web"
    - echo -e "$CI_COMMIT_REF_SLUG\n2" | createDevWorkspaceV2
  only:
    - branches
```

---

## API Reference

### Function Signatures

```bash
# Create DevWorkspace V2
createDevWorkspaceV2()
# Parameters: None (interactive prompts)
# Returns: 0 on success, 1 on failure
# Environment: Sets CHE_* variables

# Delete DevWorkspace V2  
deleteDevWorkspaceV2()
# Parameters: None (interactive prompts)
# Returns: 0 on success, 1 on failure
# Environment: Sets CHE_* variables with DW_DELETE=true
```

### Environment Variables Reference

| Variable | Purpose | Default | V1/V2 |
|----------|---------|---------|-------|
| `CHE_USER_NAMESPACE` | Kubernetes namespace | `che-user` (V1), `$USERNAME` (V2) | Both |
| `CHE_USER_NAME` | Eclipse Che username | Prompted | Both |
| `CHE_WORKSPACE_NAME` | Workspace name | Prompted (V1), Mapped (V2) | Both |
| `WORKSPACE_TYPE` | Workspace type identifier | N/A (V1), Selected (V2) | V2 Only |
| `DW_DELETE` | Delete mode flag | `false`/`true` | Both |
| `DW_FILE` | Manifest file path | `devworkspace.yaml` | V1 Only |
| `DW_TIMEOUT_SECONDS` | Startup timeout | `900` (15 min) | Both |

---

## Best Practices

### 1. Workspace Naming
- Use meaningful usernames that match your organization's naming conventions
- Avoid special characters in usernames (use alphanumeric and hyphens only)
- Keep usernames short and descriptive

### 2. Resource Management
- Monitor workspace resource usage regularly
- Delete unused workspaces to free up cluster resources
- Set appropriate memory limits for workspace types

### 3. Configuration Management
- Version control your workspace configurations
- Use ConfigMaps for environment-specific settings
- Implement backup strategies for persistent volumes

### 4. Security Considerations
- Regularly update base images
- Implement proper RBAC policies
- Monitor workspace access and usage

### 5. Performance Optimization
- Use local storage for better I/O performance when possible
- Configure appropriate resource requests and limits
- Implement node affinity for workspace placement

---

## Migration Guide

### From V1 to V2

If you're currently using V1 functions, here's how to migrate:

#### V1 Usage:
```bash
createDevWorkspace
# Prompts for: namespace, username, workspace name, manifest file

deleteDevWorkspace  
# Prompts for: namespace, username, workspace name, manifest file
```

#### V2 Usage:
```bash
createDevWorkspaceV2
# Prompts for: username, workspace type (from menu)

deleteDevWorkspaceV2
# Prompts for: username, workspace type (from menu)
```

#### Key Changes:
1. **Namespace**: Now automatically set to username
2. **Workspace Name**: Automatically mapped from workspace type
3. **Manifest File**: No longer required (automatically determined)
4. **Workspace Type**: New concept with predefined options
5. **ConfigMap Generation**: Automatic in V2

#### Migration Steps:
1. Identify your current workspace types and map them to V2 options
2. Update any automation scripts to use the new prompt format
3. Test V2 functions in a development environment
4. Gradually migrate existing workspaces to V2 structure

---

## Conclusion

The `createDevWorkspaceV2` and `deleteDevWorkspaceV2` functions provide a significantly improved user experience for managing Eclipse Che workspaces in Kubernetes environments. By abstracting away the complexity of manifest file management and providing predefined workspace types, these functions make it easier for developers to create and manage their development environments.

The automatic ConfigMap generation, comprehensive cleanup procedures, and intelligent workspace mapping make these functions suitable for both individual developers and team environments where standardized workspace configurations are beneficial.