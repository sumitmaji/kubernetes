To create an Eclipse Che workspace using `kubectl` command with a devfile when Che is protected by OAuth2 proxy, you need to create a `DevWorkspace` custom resource. Here's how to do it:

## **Method 1: Create DevWorkspace directly with kubectl**

### 1. **Create a DevWorkspace YAML file**

```yaml
# devworkspace-example.yaml
# devworkspace-example.yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-java-workspace
  namespace: skmaji1-che  # or your user namespace
  annotations:
    che.eclipse.org/devfile-source: |
      url: https://github.com/sumitmaji/workspace.git
spec:
  started: true
  routingClass: che
  template:
    components:
      - name: tools
        container:
          image: quay.io/devfile/universal-developer-image:ubi8-latest
          memoryLimit: 3Gi
          mountSources: true
          volumeMounts:
            - name: m2
              path: /home/user/.m2
          env:
            - name: DEBUG_PORT
              value: "5858"
      - name: m2
        volume:
          size: 1Gi
    commands:
      - id: build
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: mvn clean -Dmaven.repo.local=/home/user/.m2/repository package -Dmaven.test.skip=true
          group:
            kind: build
            isDefault: true
      - id: run
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: mvn -Dmaven.repo.local=/home/user/.m2/repository spring-boot:run
          group:
            kind: run
            isDefault: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/workspace.git
```

### 2. **Apply the DevWorkspace**

```bash
# Apply the DevWorkspace
kubectl apply -f devworkspace-example.yaml

# Check the workspace status
kubectl get devworkspace -n <your-username>-che

# Watch workspace creation
kubectl get devworkspace my-java-workspace -n <your-username>-che -w
```

## **Method 2: Use existing devfile from Git repository**

```yaml
# devworkspace-from-git.yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: workspace-from-git
  namespace: skmaji1-che
  annotations:
    che.eclipse.org/devfile-source: |
      url: https://github.com/sumitmaji/workspace.git
      devfilePath: devfile.yaml
spec:
  started: true
  routingClass: che
  template:
    # Reference to external devfile
    parent:
      uri: https://raw.githubusercontent.com/sumitmaji/workspace/main/devfile.yaml
```

## **Method 3: Create namespace and workspace together**

```bash
# 1. Create user namespace (if it doesn't exist)
kubectl create namespace <your-username>-che

# 2. Apply RBAC (if needed)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <your-username>-che-workspace
  namespace: <your-username>-che
subjects:
- kind: User
  name: <your-username>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: devworkspace-operator-workspace-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 3. Create the workspace
kubectl apply -f devworkspace-example.yaml
```

## **Method 4: One-liner with kubectl and heredoc**

```bash
kubectl apply -f - <<EOF
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: quick-java-workspace
  namespace: eclipse-che
spec:
  started: true
  routingClass: che
  template:
    schemaVersion: 2.2.2
    metadata:
      name: java-maven-quick
    components:
      - name: tools
        container:
          image: quay.io/devfile/universal-developer-image:ubi8-latest
          memoryLimit: 2Gi
          mountSources: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/workspace.git
EOF
```

## **Method 5: Using your existing devfile**

Based on your [`install_k8s/eclipseche/devworkspace.yaml`](install_k8s/eclipseche/devworkspace.yaml ), create a DevWorkspace:

```bash
# Convert your devfile to DevWorkspace
cat > my-devworkspace.yaml <<EOF
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: spring-boot-workspace
  namespace: eclipse-che
spec:
  started: true
  routingClass: che
  template:
$(cat install_k8s/eclipseche/devworkspace.yaml | sed 's/^/    /')
EOF

# Apply it
kubectl apply -f my-devworkspace.yaml
```

## **Useful kubectl commands for workspace management**

```bash
# List all workspaces
kubectl get devworkspace -A

# Get workspace details
kubectl describe devworkspace <workspace-name> -n <namespace>

# Get workspace status
kubectl get devworkspace <workspace-name> -n <namespace> -o jsonpath='{.status.phase}'

# Delete workspace
kubectl delete devworkspace <workspace-name> -n <namespace>

# Get workspace URL
kubectl get devworkspace <workspace-name> -n <namespace> -o jsonpath='{.status.mainUrl}'

# Watch workspace events
kubectl get events -n <namespace> --field-selector involvedObject.name=<workspace-name>

# Get workspace pods
kubectl get pods -n <namespace> -l controller.devfile.io/devworkspace_name=<workspace-name>
```

## **Troubleshooting**

```bash
# Check DevWorkspace operator logs
kubectl logs -n devworkspace-controller deployment/devworkspace-controller-manager -f

# Check workspace controller logs
kubectl logs -n eclipse-che deployment/che-operator -f

# Check if DevWorkspace CRDs are installed
kubectl get crd | grep devworkspace

# Check namespace permissions
kubectl auth can-i create devworkspace --namespace=<your-namespace>
```

## **Key Points:**

1. **Namespace**: Workspaces are typically created in user-specific namespaces (e.g., `<username>-che`)
2. **OAuth2 Protection**: Since you're using kubectl directly, it bypasses the OAuth2 proxy
3. **DevWorkspace API**: Modern Che uses DevWorkspace API instead of the legacy workspace API
4. **routingClass**: Set to `che` for Eclipse Che routing
5. **started**: Set to `true` to automatically start the workspace

The workspace will be accessible through your Che dashboard at `https://che.gokcloud.com` once created and started.