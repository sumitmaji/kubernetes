To use **Eclipse Che** as a development environment for running and compiling Java code from **Visual Studio Code (VS Code)**, follow these steps:

---

### 1. **Set Up Eclipse Che**
Ensure that Eclipse Che is installed and running in your Kubernetes cluster. If not, follow these steps:

1. Deploy Eclipse Che using `chectl`:
   ```bash
   chectl server:deploy --platform=k8s --domain=<your-domain> --che-operator-cr-patch-yaml=che-patch.yaml
   ```

2. Access Eclipse Che at the URL (e.g., `https://che.<your-domain>`).

---

### 2. **Create a Workspace in Eclipse Che**
1. Log in to the Eclipse Che dashboard.
2. Create a new workspace using a **Devfile**. Use the following Devfile for Java development:

   ```yaml
    schemaVersion: 2.2.2
    metadata:
      name: java-springboot
      displayName: Spring Boot®
      description: Java application using Spring Boot® and OpenJDK 17
      icon: https://raw.githubusercontent.com/devfile-samples/devfile-stack-icons/main/spring.svg
      tags:
        - Java
        - Spring
        - Maven
      projectType: springboot
      language: Java
      version: 1.4.0
      globalMemoryLimit: 2674Mi
      # attributes:  
      # .vscode/extensions.json: |  
      #   {  
      #     "recommendations": [  
      #       "redhat.java",
      #       "vscjava.vscode-java-debug",
      #       "vscjava.vscode-spring-boot-dashboard",
      #       "vscjava.vscode-java-debug",
      #       "vscjava.vscode-java-pack"
      #     ]  
      #   }
    components:
      - name: spring-boot
        container:
          image: quay.io/devfile/universal-developer-image:latest
          command:
            - tail
            - '-f'
            - /dev/null
          memoryLimit: 4Gi
          cpuLimit: 3000m
          mountSources: true
          endpoints:
            - name: https-springbt
              targetPort: 8080
              protocol: https
            - exposure: none
              name: debug
              targetPort: 5858
          volumeMounts:
            - name: m2
              path: /home/user/.m2
          env:
            - name: DEBUG_PORT
              value: '5858'
      - name: m2
        volume:
          size: 3Gi
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
      - id: debug
        exec:
          component: tools
          workingDir: ${PROJECT_SOURCE}
          commandLine: java -Xdebug -Xrunjdwp:server=y,transport=dt_socket,address=${DEBUG_PORT},suspend=n -jar target/*.jar
          group:
            kind: debug
            isDefault: true
    starterProjects:
      - name: springbootproject
        git:
          remotes:
            origin: https://github.com/sumitmaji/springboot-example.git
   ```

3. Start the workspace.

---

### 3. **Install the VS Code Remote Development Extension**
To connect VS Code to Eclipse Che, install the **Remote - Containers** extension:

1. Open VS Code.
2. Go to the Extensions view (`Ctrl+Shift+X` or `Cmd+Shift+X` on macOS).
3. Search for and install the **Remote - Containers** extension by Microsoft.

---

### 4. **Install kubectl**
To connect with Eclipse Che running in kubernetes, `kubectl` should be installed

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```
Copy the .kube/config file to connect with kubernetes cluster

Change namespace to one where workspace is running.


### 4. **Connect VS Code to Eclipse Che**
1. Open the Command Palette in VS Code (`Ctrl+Shift+P` or `Cmd+Shift+P` on macOS).
2. Search for **"Remote-Containers: Attach to Running Kubernetes Container"**.
3. Select the container running in your Eclipse Che workspace. The container name will match the workspace name (e.g., `java17-workspace`).

---

### 5. **Run and Compile Java Code**
Once connected to the Eclipse Che workspace container:
1. Open the project directory (e.g., `/projects/java-sample`).
2. Use the integrated terminal in VS Code to run Maven commands:
   - Build the project:
     ```bash
     mvn clean install
     ```
   - Run the application:
     ```bash
     mvn spring-boot:run
     ```

3. Use the VS Code editor to write and edit Java code. The changes will be reflected in the Eclipse Che workspace.

---

### 6. **Debug Java Code**
To debug Java code:
1. Install the **Debugger for Java** extension in VS Code.
2. Add a debug configuration in VS Code (`Run and Debug` > `Add Configuration`).
3. Start the application in debug mode:
   ```bash
   mvn spring-boot:run -Dspring-boot.run.fork=false
   ```
4. Attach the VS Code debugger to the running application.

---

### Summary
- Set up Eclipse Che and create a workspace with a Java Devfile.
- Use the **Remote - Containers** extension in VS Code to connect to the Eclipse Che workspace.
- Run and compile Java code using Maven commands in the VS Code terminal.
- Debug Java code using the **Debugger for Java** extension.

This setup allows you to leverage Eclipse Che's cloud-based development environment while using VS Code as your local IDE.