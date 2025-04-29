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