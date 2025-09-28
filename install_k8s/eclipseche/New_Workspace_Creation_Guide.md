# New Workspace Creation Guide

## Overview

This guide provides a generic step-by-step process for adding new workspace types to the DevWorkspace V2 system by analyzing the differences between existing workspaces (`python-web-project` vs `tensorflow` vs `core-java`).

## Files to Create/Modify

When adding a new workspace type, you need to create and modify the following files:

1. **Workspace Directory Structure**
2. **devworkspace.yaml** - Workspace configuration
3. **create_config.py** - ConfigMap generation script  
4. **create_devworkspace.py** - Backend mapping
5. **gok script** - Frontend integration

---

## Step 1: Create Workspace Directory Structure

### Directory Pattern
```
eclipseche/workspace/
└── <language>/
    └── <workspace-name>/
        ├── devworkspace.yaml
        ├── create_config.py
        └── [project files...]
```

### Examples
- **Python workspaces**: `workspace/python/python-web-project/`, `workspace/python/tensorflow/`
- **Java workspaces**: `workspace/java/21/core/`, `workspace/java/21/spring/web/`

### Action Required
```bash
# Create new workspace directory
mkdir -p eclipseche/workspace/<language>/<workspace-name>/
```

---

## Step 2: Create devworkspace.yaml

### Generic Template Structure
```yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-<language>-workspace  # Keep generic name
  namespace: skmaji1-che          # Keep default namespace
spec:
  routingClass: che
  started: true
  template:
    attributes:
      controller.devfile.io/devworkspace-config:
        name: devworkspace-config
        namespace: eclipse-che
      controller.devfile.io/storage-type: per-user

    components:
      - name: dev
        container:
          image: <appropriate-base-image>
          args:
            - bash
            - -lc
            - |
              # Environment setup script
              
    commands:
      # Workspace-specific commands
```

### Key Differences to Customize

#### 1. **Container Image**
- **Python workspaces**: `quay.io/devfile/universal-developer-image:latest`
- **Java workspaces**: `quay.io/devfile/universal-developer-image:latest` or `maven:3.9.9-eclipse-temurin-21`
- **Specialized**: Choose appropriate base image (e.g., `tensorflow/tensorflow:latest-jupyter` for ML)

#### 2. **Environment Setup Script**
**Python Example Pattern:**
```bash
# ===== Basic env for VS Code + caches =====
export HOME=/home/user
export USER=user
export VSCODE_AGENT_FOLDER="$HOME/.vscode-server"
: "${PIP_CACHE_DIR:=$HOME/.cache/pip}"
mkdir -p "$HOME" "$PIP_CACHE_DIR"

# ===== Wait for sources to appear =====
echo "Waiting for project contents under /projects..."
for i in {1..120}; do
  if find /projects -mindepth 1 -maxdepth 3 \( -name requirements.txt \) -print -quit | grep -q .; then
    break
  fi
  sleep 2
done

# ===== Python setup (requirements.txt) =====
PY_DIR="$(dirname "$(find /projects -mindepth 1 -maxdepth 3 -name requirements.txt -print -quit 2>/dev/null)")"
if [ -n "$PY_DIR" ]; then
  echo "Python project detected at: $PY_DIR"
  if [ ! -d "$PY_DIR/.venv" ]; then
    cd "$PY_DIR"
    python3 -m venv .venv
    . .venv/bin/activate
    pip install --upgrade pip
    if [ -f requirements.txt ]; then
      pip install -r requirements.txt
    fi
  fi
fi
```

**Java Example Pattern:**
```bash
export HOME=/home/user
export USER=user
export VSCODE_AGENT_FOLDER="$HOME/.vscode-server"
mkdir -p "$HOME" "$HOME/.m2"

# Wait for Maven project
for i in {1..120}; do
  if find /projects -mindepth 1 -maxdepth 3 -name pom.xml -print -quit | grep -q .; then
    break
  fi
  sleep 2
done

# Maven dependency setup
if [ ! -f /home/user/.m2/.offline_done ]; then
  POM_DIR="$(dirname "$(find /projects -mindepth 1 -maxdepth 3 -name pom.xml -print -quit)")"
  if [ -n "$POM_DIR" ]; then
    (cd "$POM_DIR" && mvn -B -U -Dmaven.repo.local=/home/user/.m2/repository dependency:go-offline)
    touch /home/user/.m2/.offline_done
  fi
fi
```

#### 3. **Commands Section**

**Key Difference: Working Directory**
- Replace `/projects/<workspace-name>` with your actual workspace directory name
- **python-web-project**: `workingDir: /projects/python-web-project`
- **tensorflow**: `workingDir: /projects/tensorflow`  
- **core-java**: `workingDir: /projects/core-java` (would be the pattern)

**Common Command Types:**
```yaml
commands:
  - id: test-<framework>
    exec:
      component: dev
      workingDir: /projects/<workspace-name>
      commandLine: |
        <test-command>
      group:
        kind: test
        isDefault: true

  - id: run-app
    exec:
      component: dev  
      workingDir: /projects/<workspace-name>
      commandLine: |
        <run-command>
      group:
        kind: run
        isDefault: true
```

### Template Customization Checklist
- [ ] **Change working directories** in all commands from `/projects/<old-name>` to `/projects/<new-workspace-name>`
- [ ] **Update container image** to appropriate base image for your technology stack
- [ ] **Modify environment setup** script for your language/framework requirements
- [ ] **Customize commands** for your specific build/run/test workflow
- [ ] **Add framework-specific** dependency detection patterns (requirements.txt, pom.xml, package.json, etc.)

---

## Step 3: Create create_config.py

### Generic Template
```python
import os
import sys
from kubernetes import client, config

def create_configmap(namespace, configmap_name, file_list):
    config.load_kube_config()
    v1 = client.CoreV1Api()

    # Check if ConfigMap exists
    try:
        v1.read_namespaced_config_map(configmap_name, namespace)
        print(f"ConfigMap '{configmap_name}' already exists in namespace '{namespace}'. Skipping creation.")
        return
    except client.exceptions.ApiException as e:
        if e.status != 404:
            print(f"Error checking ConfigMap '{configmap_name}': {e}")
            return

    data = {}
    for filename in file_list:
        with open(filename, 'r') as f:
            key = os.path.basename(filename)
            data[key] = f.read()

    labels = {
        "controller.devfile.io/mount-to-devworkspace": "true",
        "controller.devfile.io/watch-configmap": "true"
    }
    
    # CRITICAL: Update mount path for your workspace
    file_path = list(file_list)[0]
    relative_path = os.path.relpath(file_path, '.')
    mount_path = f"/tmp/projects/<WORKSPACE-NAME>/{os.path.dirname(relative_path)}" if os.path.dirname(relative_path) != '.' else "/tmp/projects"
    
    base_annotations = {
        "controller.devfile.io/mount-as": "subpath",
        "controller.devfile.io/mount-path": mount_path
    }
    
    configmap = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(name=configmap_name, labels=labels, annotations=base_annotations),
        data=data
    )

    v1.create_namespaced_config_map(namespace=namespace, body=configmap)
    print(f"ConfigMap '{configmap_name}' created in namespace '{namespace}'.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python create_config.py <namespace>")
        sys.exit(1)

    namespace = sys.argv[1]
    files = []
    for root, dirs, filenames in os.walk('.'):
        for filename in filenames:
            if filename not in ['create_config.py', 'devworkspace.yaml']:
                files.append(os.path.join(root, filename))
    
    for filepath in files:
        filename = os.path.basename(filepath)
        # Enhanced sanitization (use tensorflow version)
        configmap_name = filename.replace('.', '-').replace('_', '-').lower()
        configmap_name = configmap_name.strip('-.')
        if configmap_name and not configmap_name[0].isalnum():
            configmap_name = 'file-' + configmap_name
        if configmap_name and not configmap_name[-1].isalnum():
            configmap_name = configmap_name + '-file'
        if not configmap_name or not configmap_name[0].isalnum():
            configmap_name = 'config-' + str(hash(filepath))[:8]
        create_configmap(namespace, configmap_name, [filepath])
```

### Key Customization Point
**CRITICAL CHANGE**: Update the mount path to match your workspace name:

**Before (template):**
```python
mount_path = f"/tmp/projects/<WORKSPACE-NAME>/{os.path.dirname(relative_path)}"
```

**After (examples):**
- **python-web-project**: `mount_path = f"/tmp/projects/python-web-project/{os.path.dirname(relative_path)}"`
- **tensorflow**: `mount_path = f"/tmp/projects/tensorflow/{os.path.dirname(relative_path)}"`
- **your-workspace**: `mount_path = f"/tmp/projects/your-workspace/{os.path.dirname(relative_path)}"`

### Naming Convention Differences
- **python-web-project**: Uses basic sanitization `filename.replace('.', '-').lower()`
- **tensorflow**: Uses enhanced sanitization with validation and fallbacks
- **Recommendation**: Use tensorflow version for better ConfigMap name compliance

---

## Step 4: Update create_devworkspace.py

### Location to Modify
File: `/home/sumit/Documents/repository/kubernetes/install_k8s/eclipseche/create_devworkspace.py`

### Changes Required
Add your workspace mapping to the `workspace_map` dictionary:

```python
workspace_map = {
    "core-java": "workspace/java/21/core",
    "springboot-web": "workspace/java/21/spring/web", 
    "python-web": "workspace/python/python-web-project",
    "springboot-backend": "workspace/java/21/spring/springboot-backend-project",
    "tensorflow": "workspace/python/tensorflow",
    "microservice-study": "workspace/java/microservice-study",
    "javaparser": "workspace/java/21/javaparser",
    "nlp": "workspace/python/nlp",
    "kubeauthentication": "workspace/java/kubeauthentication",
    # ADD YOUR NEW WORKSPACE HERE:
    "<your-workspace-type>": "workspace/<language>/<workspace-name>"
}
```

### Example Additions
```python
# Examples of new workspace additions:
"django-web": "workspace/python/django-web-project",
"react-frontend": "workspace/javascript/react-frontend", 
"golang-api": "workspace/go/golang-api-service",
"rust-cli": "workspace/rust/rust-cli-tools"
```

---

## Step 5: Update gok Script

### Location to Modify
File: `/home/sumit/Documents/repository/kubernetes/install_k8s/gok`

### Changes Required in createDevWorkspaceV2()

#### 1. Add Menu Option
```bash
echo "Select workspace type:"
echo "1 => core-java"
echo "2 => spring-web"
echo "3 => python-web"
echo "4 => springboot-backend"
echo "5 => tensorflow"
echo "6 => microservice-study"
echo "7 => javaparser"
echo "8 => nlp"
echo "9 => kubeauthentication"
# ADD NEW LINE HERE:
echo "10 => <your-workspace-type>"
```

#### 2. Add Index Mapping
```bash
case "$WORKSPACE_TYPE_INDEX" in
  1) WORKSPACE_TYPE="core-java" ;;
  2) WORKSPACE_TYPE="springboot-web" ;;
  3) WORKSPACE_TYPE="python-web" ;;
  4) WORKSPACE_TYPE="springboot-backend" ;;
  5) WORKSPACE_TYPE="tensorflow" ;;
  6) WORKSPACE_TYPE="microservice-study" ;;
  7) WORKSPACE_TYPE="javaparser" ;;
  8) WORKSPACE_TYPE="nlp" ;;
  9) WORKSPACE_TYPE="kubeauthentication";;
  # ADD NEW LINE HERE:
  10) WORKSPACE_TYPE="<your-workspace-type>" ;;
  *) WORKSPACE_TYPE="core-java" ;;
esac
```

#### 3. Add Workspace Name Mapping
```bash
case "$WORKSPACE_TYPE" in
  core-java) WORKSPACE="java" ;;
  springboot-web) WORKSPACE="spring" ;;
  python-web) WORKSPACE="python" ;;
  springboot-backend) WORKSPACE="spring" ;;
  tensorflow) WORKSPACE="tensorflow" ;;
  microservice-study) WORKSPACE="microservice-study" ;;
  javaparser) WORKSPACE="javaparser" ;;
  nlp) WORKSPACE="nlp" ;;
  kubeauthentication) WORKSPACE="kubeauthentication" ;;
  # ADD NEW LINE HERE:
  <your-workspace-type>) WORKSPACE="<workspace-display-name>" ;;
  *) WORKSPACE="java" ;;
esac
```

### Update deleteDevWorkspaceV2() Similarly
Make the same three changes in the `deleteDevWorkspaceV2()` function.

---

## Complete Example: Adding "django-web" Workspace

### Step 1: Create Directory
```bash
mkdir -p eclipseche/workspace/python/django-web-project/
```

### Step 2: Create devworkspace.yaml
```yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-python-workspace
  namespace: skmaji1-che
spec:
  routingClass: che
  started: true
  template:
    # ... (same structure as python-web-project)
    components:
      - name: dev
        container:
          image: quay.io/devfile/universal-developer-image:latest
          # ... same environment setup ...
    
    commands:
      - id: run-django
        exec:
          component: dev
          workingDir: /projects/django-web-project  # Updated path
          commandLine: |
            . .venv/bin/activate && python manage.py runserver 0.0.0.0:8000
          group:
            kind: run
            isDefault: true
      
      - id: migrate
        exec:
          component: dev
          workingDir: /projects/django-web-project  # Updated path  
          commandLine: |
            . .venv/bin/activate && python manage.py migrate
```

### Step 3: Create create_config.py
```python
# ... same template ...
mount_path = f"/tmp/projects/django-web-project/{os.path.dirname(relative_path)}" # Updated path
# ... rest same ...
```

### Step 4: Update create_devworkspace.py
```python
workspace_map = {
    # ... existing entries ...
    "django-web": "workspace/python/django-web-project"  # Added line
}
```

### Step 5: Update gok Script
```bash
# Menu:
echo "10 => django-web"

# Index mapping:
10) WORKSPACE_TYPE="django-web" ;;

# Workspace name mapping:  
django-web) WORKSPACE="django" ;;
```

---

## Workspace Type Naming Conventions

### Established Patterns
- **Language-framework**: `python-web`, `springboot-web`, `springboot-backend`
- **Technology-specific**: `tensorflow`, `javaparser`
- **Purpose-based**: `microservice-study`, `kubeauthentication`
- **Language-core**: `core-java`, `nlp`

### Recommended Naming
- Use lowercase with hyphens: `django-web`, `react-frontend`
- Be specific but concise: `golang-api` not `golang-api-service-development`
- Include primary technology: `vue-frontend`, `flask-api`, `spring-microservice`

---

## Testing Your New Workspace

### 1. Directory Structure Verification
```bash
ls -la eclipseche/workspace/<language>/<workspace-name>/
# Should show: devworkspace.yaml, create_config.py, [project files]
```

### 2. Test ConfigMap Generation
```bash
cd eclipseche/workspace/<language>/<workspace-name>/
python3 create_config.py test-namespace
```

### 3. Test Workspace Creation
```bash
./gok
> createDevWorkspaceV2
# Select your new workspace type
```

### 4. Verify Resources
```bash
kubectl get devworkspace -n <username>
kubectl get configmap -n <username>
kubectl describe devworkspace <workspace-name> -n <username>
```

---

## Common Customization Patterns

### Resource Requirements
```yaml
components:
  - name: dev
    container:
      # Heavy workloads (ML/Big Data)
      memoryLimit: 8Gi
      cpuLimit: "4"
      
      # Standard development  
      memoryLimit: 4Gi
      cpuLimit: "2"
      
      # Lightweight
      memoryLimit: 2Gi  
      cpuLimit: "1"
```

### Port Exposure
```yaml
components:
  - name: dev
    container:
      endpoints:
        - name: web-app
          targetPort: 8080
          exposure: public
          protocol: https
        - name: debug
          targetPort: 5005
          exposure: internal
```

### Volume Mounts
```yaml
components:
  - name: dev
    container:
      volumeMounts:
        - name: cache
          path: /home/user/.cache
        - name: config
          path: /home/user/.config
          
  # Add corresponding volumes
  - name: cache
    volume:
      size: 1Gi
  - name: config  
    volume:
      size: 100Mi
```

### Environment Variables
```yaml
components:
  - name: dev
    container:
      env:
        - name: NODE_ENV
          value: development
        - name: DEBUG
          value: "true"
        - name: DATABASE_URL
          value: sqlite:///workspace.db
```

---

## Validation Checklist

Before submitting your new workspace:

- [ ] **Directory structure** matches pattern: `workspace/<language>/<workspace-name>/`
- [ ] **devworkspace.yaml** has updated working directories in all commands
- [ ] **devworkspace.yaml** uses appropriate base image for technology stack  
- [ ] **create_config.py** has correct mount path with workspace name
- [ ] **create_devworkspace.py** has new workspace mapping entry
- [ ] **gok script** has three updates: menu option, index mapping, workspace name mapping
- [ ] **deleteDevWorkspaceV2()** also updated in gok script
- [ ] **ConfigMap generation** tested successfully
- [ ] **Workspace creation** tested end-to-end
- [ ] **Resource cleanup** (deleteDevWorkspaceV2) tested
- [ ] **Documentation** updated if needed

This completes the comprehensive guide for adding new workspace types to the DevWorkspace V2 system!