To install Oracle VirtualBox on Ubuntu using the command line, follow these steps:

1. **Update your system**:
   ```sh
   sudo apt-get update
   ```

2. **Install required dependencies**:
   ```sh
   sudo apt-get install -y software-properties-common
   ```

3. **Add the Oracle VirtualBox repository**:
   ```sh
   sudo add-apt-repository "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
   ```

4. **Add the Oracle public key**:
   ```sh
   wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
   wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
   ```

5. **Update your package list again**:
   ```sh
   sudo apt-get update
   ```

6. **Install VirtualBox**:
   ```sh
   sudo apt-get install -y virtualbox-6.1
   ```

This will install Oracle VirtualBox on your Ubuntu system. You can verify the installation by running:

```sh
virtualbox --help
```

Here are steps to check and clean up images for different container runtimes:

1. **Check the Container Runtime**:
   ```sh
   kubectl get nodes -o wide
   ```

   Look for the `CONTAINER-RUNTIME` column to see which runtime is being used (e.g., `docker`, `containerd`, `cri-o`).

2. **If Using Docker**:
   - **List Docker Images**:
     ```sh
     sudo docker images
     ```
   - **Remove Unused Docker Images**:
     ```sh
     sudo docker image prune -a
     ```

3. **If Using Containerd**:
   - **List Containerd Images**:
     ```sh
     sudo ctr images ls
     ```
   - **Remove Unused Containerd Images**:
     ```sh
     sudo ctr images prune
     ```

4. **If Using CRI-O**:
   - **List CRI-O Images**:
     ```sh
     sudo crictl images
     ```
   - **Remove Unused CRI-O Images**:
     ```sh
     sudo crictl rmi --prune
     ```

By following these steps, you can determine the container runtime being used by Kubernetes and clean up the images accordingly.