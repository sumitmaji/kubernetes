# **Steps to Connect to JupyterHub Server from VS Code**

#### **1. Install Required Extensions**
Install the following VS Code extensions to enable Jupyter and JupyterHub support:
1. **Jupyter**:
   - Provides support for Jupyter Notebooks in VS Code.
   - Install it from the Extensions view (`Ctrl+Shift+X` or `Cmd+Shift+X` on macOS).
2. **Python**:
   - Required for Python development and Jupyter integration.
3. **JupyterHub**:
   - Adds support for connecting to JupyterHub servers from VS Code.
   - Install it from the Extensions view.

---

#### **2. Obtain JupyterHub Server Details**
You need the following details:
1. **JupyterHub URL**: The URL of the JupyterHub server (e.g., `https://<jupyterhub-server>/hub`).
2. **Authentication Credentials**: Your username and password or token to log in to the JupyterHub server.

---

#### **3. Skip SSL Certificate Verification (Optional)**
If the JupyterHub server uses a self-signed SSL certificate or has certificate issues, you can skip SSL verification by setting the `NODE_TLS_REJECT_UNAUTHORIZED` environment variable.

1. Open a terminal in your system.
2. Run the following command to disable SSL verification:
   ```bash
   export NODE_TLS_REJECT_UNAUTHORIZED=0
   ```
   - This tells Node.js (used internally by VS Code) to ignore SSL certificate errors.

3. Start VS Code from the same terminal:
   ```bash
   code
   ```
   - This ensures the environment variable is applied to VS Code.

---

#### **4. Configure VS Code to Connect to JupyterHub**
1. Open VS Code.
2. Open the Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P` on macOS).
3. Search for **"Python: Specify Jupyter Server URI"** and select it.
4. Enter the JupyterHub server URL:
   - If you have a token, append it to the URL:
     ```plaintext
     https://<jupyterhub-server>/user/<username>?token=<your-token>
     ```
   - If you don't have a token, VS Code will prompt you to log in.

---

#### **5. Test the Connection**
1. Open a new or existing Jupyter Notebook (`.ipynb`) file in VS Code.
2. Check the top-right corner of the notebook editor to ensure the Jupyter server is connected.
   - It should display the JupyterHub server URL.
3. Run a cell in the notebook to verify the connection.

---

#### **6. Enable SSH Tunneling (If Required)**
If the JupyterHub server is behind a firewall or accessible only via SSH:
1. Set up an SSH tunnel to forward the JupyterHub port to your local machine:
   ```bash
   ssh -L 8888:<jupyterhub-server>:<port> <username>@<remote-server>
   ```
2. Use `http://localhost:8888` as the Jupyter server URI in VS Code.

---

#### **7. Install Required Python Packages**
Ensure the required Python packages are installed on the JupyterHub server:
- `ipykernel`
- `notebook`
- Any additional libraries required for your project.

If you have access to the JupyterHub terminal, you can install these packages using:
```bash
pip install ipykernel notebook
```

---

#### **8. Troubleshooting**
- **SSL Issues**:
  - If skipping SSL verification (`NODE_TLS_REJECT_UNAUTHORIZED=0`) resolves the issue, consider fixing the server's SSL certificate for a more secure setup.
- **Connection Issues**:
  - Ensure the JupyterHub server is running and accessible.
  - Verify your credentials or token.
- **Kernel Not Found**:
  - Ensure the kernel is installed on the JupyterHub server.
  - Restart the JupyterHub server if necessary.

---

### **Summary**
- Install the **Jupyter**, **Python**, and **JupyterHub** extensions in VS Code.
- Obtain the JupyterHub server URL and credentials.
- Set `NODE_TLS_REJECT_UNAUTHORIZED=0` to skip SSL verification if needed.
- Configure the Jupyter server URI in VS Code.
- Optionally, set up SSH tunneling if the server is behind a firewall.

This setup ensures you can connect to a JupyterHub server from VS Code, even if there are SSL certificate issues. However, skipping SSL verification should only be used as a temporary workaround in non-production environments.