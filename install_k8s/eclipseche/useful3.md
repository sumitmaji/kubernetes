To make your DevWorkspace use the existing `eclipse-pv` PersistentVolume, you have several options:

## **Solution 1: Create a PVC that binds to your existing PV**

First, check your existing PV details:

```bash
# Check your existing PV
kubectl get pv eclipse-pv -o yaml
```

Then create a PVC that specifically binds to it:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eclipse-workspace-storage
  namespace: skmaji1-che
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi  # Match your PV size
  volumeName: eclipse-che-pv  
  storageClassName: ""    
EOF
```

## **Solution 2: Modify your DevWorkspace to use the PVC**

Update your DevWorkspace to reference the PVC:

```yaml
# devworkspace-with-existing-pv.yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-java-workspace
  namespace: skmaji1-che
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
            - name: workspace-storage
              path: /projects
            - name: m2-cache
              path: /home/user/.m2
          env:
            - name: DEBUG_PORT
              value: "5858"
      - name: workspace-storage
        volume:
          persistentVolumeClaim:
            claimName: eclipse-workspace-storage
      - name: m2-cache
        volume:
          emptyDir: {}  # For Maven cache, can be ephemeral
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

## **Solution 3: One-liner to create everything**

```bash
# Create PVC and DevWorkspace together
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eclipse-workspace-storage
  namespace: skmaji1-che
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  volumeName: eclipse-pv
  storageClassName: ""
---
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-java-workspace
  namespace: skmaji1-che
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
            - name: workspace-storage
              path: /projects
          env:
            - name: DEBUG_PORT
              value: "5858"
      - name: workspace-storage
        volume:
          persistentVolumeClaim:
            claimName: eclipse-workspace-storage
    commands:
      - id: build
        exec:
          component: tools
          workingDir: \${PROJECT_SOURCE}
          commandLine: mvn clean package -Dmaven.test.skip=true
          group:
            kind: build
            isDefault: true
      - id: run
        exec:
          component: tools
          workingDir: \${PROJECT_SOURCE}
          commandLine: mvn spring-boot:run
          group:
            kind: run
            isDefault: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/workspace.git
EOF
```

## **Solution 4: Check and use existing storage class from your gok setup**

If your `eclipse-pv` was created by your gok script, check the storage class:

```bash
# Check your PV details
kubectl describe pv eclipse-pv

# Check if you have a storage class that can provision volumes
kubectl get storageclass

# If you have a storage class, create a simpler DevWorkspace
# Remove volumeName and storageClassName from PVC spec to use dynamic provisioning
```

## **Solution 5: Use your gok script's storage configuration**

Since you created `eclipse-pv`, you might want to use your gok script's storage setup:

```bash
# Check what storage classes your gok script created
gok all sc

# Check existing PVs created by gok
gok all pv

# Use the appropriate storage class in your DevWorkspace
```

## **Quick verification steps:**

```bash
# Delete the failed workspace first
kubectl delete devworkspace my-java-workspace -n skmaji1-che

# Check your PV status
kubectl get pv eclipse-pv

# Create the PVC and DevWorkspace
kubectl apply -f - <<EOF
# (Use the YAML from Solution 3 above)
EOF

# Monitor the workspace creation
kubectl get devworkspace my-java-workspace -n skmaji1-che -w

# Check PVC binding
kubectl get pvc -n skmaji1-che
```

The key points:
1. **volumeName: eclipse-pv** - This tells the PVC to bind to your specific PV
2. **storageClassName: ""** - Empty string prevents dynamic provisioning and forces static binding
3. **persistentVolumeClaim** in the DevWorkspace component references your PVC

After applying this, your DevWorkspace should successfully bind to your existing `eclipse-pv` and start running.