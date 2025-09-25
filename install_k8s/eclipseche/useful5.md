You're absolutely right! In the `devworkspace-with-storageclass.yaml` example I provided, **there is no storage class actually mentioned**. The YAML only has storage-related annotations but doesn't specify which storage class to use.

Here are the corrected ways to actually specify a storage class:

## **Method 1: Specify storage class in DevWorkspaceOperatorConfig**

```yaml
apiVersion: controller.devfile.io/v1alpha1
kind: DevWorkspaceOperatorConfig
metadata:
  name: devworkspace-operator-config
  namespace: devworkspace-controller
spec:
  config:
    workspace:
      defaultStorageSize: "5Gi"
      storageClassName: "eclipse-che-storage"  # Your storage class here
```

## **Method 2: Use annotations to specify storage class**

```yaml
# devworkspace-with-specific-storageclass.yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-java-workspace
  namespace: skmaji1-che
  annotations:
    che.eclipse.org/devfile-source: |
      url: https://github.com/sumitmaji/workspace.git
    controller.devfile.io/storage-type: per-user
    controller.devfile.io/storage-class: "eclipse-che-storage"  # Specify your storage class
spec:
  started: true
  routingClass: che
  template:
    attributes:
      controller.devfile.io/storage-type: per-user
    components:
      - name: tools
        container:
          image: quay.io/devfile/universal-developer-image:ubi8-latest
          memoryLimit: 3Gi
          mountSources: true
          env:
            - name: DEBUG_PORT
              value: "5858"
    commands:
      - id: build
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: mvn clean package -Dmaven.test.skip=true
          group:
            kind: build
            isDefault: true
      - id: run
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: mvn spring-boot:run
          group:
            kind: run
            isDefault: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/workspace.git
```

## **Method 3: Create storage class first, then use default**

```bash
# First create your storage class and make it default
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: eclipse-che-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# Then your DevWorkspace will automatically use the default storage class
# (The original YAML without explicit storage class reference)
```

## **Method 4: Specify storage class in volume component**

```yaml
# devworkspace-volume-with-storageclass.yaml
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: my-java-workspace
  namespace: skmaji1-che
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
            - name: m2-cache
              path: /home/user/.m2
          env:
            - name: DEBUG_PORT
              value: "5858"
      - name: m2-cache
        volume:
          size: 1Gi
          storageClass: "eclipse-che-storage"  # Specify storage class here
    commands:
      - id: build
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: mvn clean package -Dmaven.test.skip=true
          group:
            kind: build
            isDefault: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/workspace.git
```

## **To use your existing eclipse-pv:**

```bash
# Create a storage class that can use your existing PV
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: eclipse-che-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Then use Method 2 or 4 above with storageClassName: "eclipse-che-storage"
```

You're correct to point out that the storage class wasn't actually specified in my previous example. Thank you for catching that!