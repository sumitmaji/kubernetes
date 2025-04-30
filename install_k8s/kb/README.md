# Steps to install kubectl client

### The error **`spawn kubectl ENOENT`** indicates that the `kubectl` command is not found in the system's `PATH`. This typically happens if `kubectl` is not installed or not properly configured in your environment.


### Steps to Resolve

#### 1. **Verify if `kubectl` is Installed**
Run the following command to check if `kubectl` is installed:
```bash
kubectl version --client
```

- If the command is not found, proceed to install `kubectl`.

---

#### 2. **Install `kubectl`**
Follow the steps below to install `kubectl`:

##### On Linux:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

##### On macOS:
```bash
brew install kubectl
```

##### On Windows:
Download the binary from [Kubernetes releases](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and add it to your `PATH`.

---

#### 3. **Ensure `kubectl` is in the PATH**
Verify that `kubectl` is in your system's `PATH`:
```bash
echo $PATH
```

If `kubectl` is not in the `PATH`, add it. For example:

- **Linux/macOS**:
  Add the directory containing `kubectl` to your `~/.bashrc` or `~/.zshrc`:
  ```bash
  export PATH=$PATH:/usr/local/bin
  source ~/.bashrc
  ```

- **Windows**:
  Add the directory containing `kubectl.exe` to the system's `Environment Variables > PATH`.

---

#### 4. **Verify Kubernetes Context**
Ensure that `kubectl` is configured to connect to your Kubernetes cluster:
```bash
kubectl config get-contexts
```

If no contexts are listed, configure `kubectl` with your cluster's kubeconfig file:
```bash
export KUBECONFIG=/path/to/kubeconfig
```

---

#### 5. **Restart VS Code**
After ensuring `kubectl` is installed and in the `PATH`, restart Visual Studio Code to reload the environment variables.

---

#### 6. **Test the Setup**
Run the command that caused the error again (e.g., connecting to Eclipse Che). The error should no longer occur.

---

### Summary
- Install `kubectl` if it is missing.
- Ensure `kubectl` is in the system's `PATH`.
- Configure `kubectl` with the correct Kubernetes context.
- Restart VS Code to apply the changes.

This should resolve the **`spawn kubectl ENOENT`** error.



# To add the user `sumit` to the `docker` group


### Steps to Add `sumit` to the Docker Group

1. **Add the User to the Docker Group**:
   Run the following command:
   ```bash
   sudo usermod -aG docker sumit
   ```

2. **Verify the User is Added to the Group**:
   Check if `sumit` is now part of the `docker` group:
   ```bash
   groups sumit
   ```

   You should see `docker` listed in the output.

3. **Log Out and Log Back In**:
   For the changes to take effect, log out and log back in as the `sumit` user.

4. **Test Docker Access**:
   Switch to the `sumit` user and test Docker access without `sudo`:
   ```bash
   docker ps
   ```

   If it works without requiring `sudo`, the setup is complete.

---

### Summary
- Use `sudo usermod -aG docker sumit` to add `sumit` to the `docker` group.
- Log out and log back in for the changes to take effect.
- Test Docker access to ensure it works without `sudo`.


# Steps to Make the PV Available Again

#### 1. **Delete the Bound PVC**
Ensure that the PVC (`claim-devworkspace`) associated with the PV is deleted. Run the following command to delete the PVC:
```bash
kubectl delete pvc claim-devworkspace -n skmaji1-outlook-com-che-x4x051
```

---

#### 2. **Edit the PV to Reset Its State**
Manually edit the PV to reset its state from `Released` to `Available`:

1. Open the PV for editing:
   ```bash
   kubectl edit pv eclipse-che-pv
   ```

2. Find the `claimRef` section in the YAML file and remove it. For example:
   ```yaml
   spec:
     claimRef:
       apiVersion: v1
       kind: PersistentVolumeClaim
       name: claim-devworkspace
       namespace: skmaji1-outlook-com-che-x4x051
   ```

   After removing the `claimRef`, the `spec` section should look like this:
   ```yaml
   spec:
     capacity:
       storage: 10Gi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: eclipse-che-storage
     local:
       path: /data/volumes/eclipse-che
     nodeAffinity:
       required:
         nodeSelectorTerms:
           - matchExpressions:
               - key: kubernetes.io/hostname
                 operator: In
                 values:
                   - master.cloud.com
   ```

3. Save and close the editor.

---

#### 3. **Verify the PV State**
Check the state of the PV to ensure it is now `Available`:
```bash
kubectl get pv eclipse-che-pv
```

You should see output like this:
```plaintext
NAME             CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS          REASON   AGE
eclipse-che-pv   10Gi       RWO            Retain           Available           eclipse-che-storage           10m
```

---

#### 4. **Rebind the PV to a New PVC**
If you need to reuse the PV, create a new PVC that matches the PV's `storageClassName` and `capacity`. For example:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: new-claim-devworkspace
  namespace: skmaji1-outlook-com-che-x4x051
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: eclipse-che-storage
```

Apply the PVC:
```bash
kubectl apply -f pvc.yaml
```

---

#### 5. **Verify the Binding**
Check if the PV is now bound to the new PVC:
```bash
kubectl get pv
kubectl get pvc -n skmaji1-outlook-com-che-x4x051
```

You should see the PV in the `Bound` state and associated with the new PVC.

---

### Summary
- Delete the old PVC (`claim-devworkspace`).
- Edit the PV to remove the `claimRef` and reset its state to `Available`.
- Create a new PVC to bind the PV if needed.
- Verify that the PV is now in the `Available` or `Bound` state.

This process ensures that the PV can be reused for new workloads.
