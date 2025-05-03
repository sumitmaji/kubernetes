# **Steps to Create a Pipeline in Jenkins**

Follow these steps to create and configure a pipeline in Jenkins:

---

### **1. Access Jenkins**
1. Open your Jenkins instance in a web browser.
2. Log in with your credentials.

---

### **2. Create a New Pipeline Job**
1. From the Jenkins dashboard, click **"New Item"**.
2. Enter a name for your pipeline (e.g., `Kaniko-Pipeline`).
3. Select **"Pipeline"** as the project type.
4. Click **"OK"**.

---

### **3. Configure the Pipeline**
1. **General Settings**:
   - Add a description for the pipeline (optional).
   - If needed, check **"This project is parameterized"** to add parameters (e.g., `IMAGE_NAME`, `IMAGE_TAG`).

2. **Pipeline Definition**:
   - Scroll down to the **Pipeline** section.
   - Select **"Pipeline script"** if you want to define the pipeline directly in Jenkins.
   - Alternatively, select **"Pipeline script from SCM"** if your pipeline script is stored in a Git repository.

---

### **4. Add the Pipeline Script**
If you selected **"Pipeline script"**, paste the following example pipeline script into the editor:

```groovy
pipeline {
    agent {
        kubernetes {
            cloud 'gok-kubernetes'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
            """
        }
    }
    environment {
        IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
        IMAGE_TAG = "${BUILD_ID}"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                   sh """
                        /kaniko/executor \
                            --context git://github.com/scriptcamp/kubernetes-kaniko \
                            --destination ${IMAGE_NAME}:${IMAGE_TAG} \
                            --destination ${IMAGE_NAME}:latest \
                            --cache=true \
                            --insecure \
                            --skip-tls-verify
                    """
                }
            }
        }
    }
}
```

---

### **5. Save the Pipeline**
1. Click **"Save"** to save the pipeline configuration.

---

### **6. Run the Pipeline**
1. From the pipeline's dashboard, click **"Build Now"** to trigger the pipeline.
2. Monitor the build progress in the **Build History** section.
3. Click on the build number to view the console output and logs.

---

### **7. Verify the Results**
1. Check the console output to ensure the pipeline executed successfully.
2. Verify that the Docker image was built and pushed to the specified registry.

---

### **Optional: Use a Git Repository for the Pipeline Script**
If your pipeline script is stored in a Git repository:
1. Select **"Pipeline script from SCM"** in the **Pipeline** section.
2. Choose **"Git"** as the SCM.
3. Enter the repository URL and branch name.
4. Specify the path to the Jenkinsfile (e.g., `Jenkinsfile`).

---

### **Summary**
- Create a new pipeline job in Jenkins.
- Define the pipeline script directly in Jenkins or use a Git repository.
- Save and run the pipeline to build and push Docker images using Kaniko.
- Monitor the pipeline execution and verify the results.


# **Jenkins Pipeline for Kaniko Example**

```json
pipeline {
    agent {
        kubernetes {
            cloud 'gok-kubernetes'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
            """
        }
    }
    environment {
        IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
        IMAGE_TAG = "${BUILD_ID}"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                   sh """
                        /kaniko/executor \
                            --context git://github.com/scriptcamp/kubernetes-kaniko \
                            --destination ${IMAGE_NAME}:${IMAGE_TAG} \
                            --destination ${IMAGE_NAME}:latest \
                            --cache=true \
                            --insecure \
                            --skip-tls-verify
                    """
                }
            }
        }
    }
}
```

### **Pipeline Breakdown**

#### **1. `agent` Block**
```groovy
agent {
    kubernetes {
        cloud 'gok-kubernetes'
        yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
        """
    }
}
```

- **`cloud 'gok-kubernetes'`**:
  - Refers to the Kubernetes cloud configuration named `gok-kubernetes` in Jenkins.

- **`yaml`**:
  - Defines the pod template inline in the pipeline.
  - The pod has two containers:
    1. **`jnlp`**:
       - The default Jenkins agent container used to connect the pod to the Jenkins master.
       - Runs the Jenkins agent process.
    2. **`kaniko`**:
       - Runs the Kaniko executor for building and pushing Docker images.
       - Uses the `gcr.io/kaniko-project/executor:debug` image for debugging purposes.
       - The `command: ["tail"]` and `args: ["-f", "/dev/null"]` keep the container running and ready for instructions from the pipeline.

- **`volumeMounts`**:
  - Mounts the `registry-credentials` secret at `/kaniko/.docker` for Docker registry authentication.

- **`volumes`**:
  - Defines the `registry-credentials` secret as a volume.

---

#### **2. `environment` Block**
```groovy
environment {
    IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
    IMAGE_TAG = "${BUILD_ID}"
}
```
- **`IMAGE_NAME`**:
  - Specifies the name of the Docker image to be built and pushed.
- **`IMAGE_TAG`**:
  - Uses the Jenkins `BUILD_ID` environment variable to tag the image with a unique identifier.

---

#### **3. `stages` Block**
The pipeline has one stage: **Build and Push Docker Image**.

---

#### **4. `container('kaniko')`**
```groovy
container('kaniko') {
   sh """
        /kaniko/executor \
            --context git://github.com/scriptcamp/kubernetes-kaniko \
            --destination ${IMAGE_NAME}:${IMAGE_TAG} \
            --destination ${IMAGE_NAME}:latest \
            --cache=true \
            --insecure \
            --skip-tls-verify
    """
}
```
- **`container('kaniko')`**:
  - Specifies that the steps inside this block will run in the `kaniko` container.

- **Kaniko Command**:
  - **`/kaniko/executor`**: Runs the Kaniko executor to build and push the Docker image.
  - **`--context git://github.com/scriptcamp/kubernetes-kaniko`**:
    - Specifies the build context as a Git repository.
  - **`--destination ${IMAGE_NAME}:${IMAGE_TAG}`**:
    - Pushes the image with a unique tag based on the Jenkins `BUILD_ID`.
  - **`--destination ${IMAGE_NAME}:latest`**:
    - Pushes the image with the `latest` tag.
  - **`--cache=true`**:
    - Enables caching to speed up subsequent builds.
  - **`--insecure`** and **`--skip-tls-verify`**:
    - Allow insecure connections and skip TLS verification for the Docker registry.

---

### **How It Works**
1. **Pod Provisioning**:
   - Jenkins dynamically provisions a Kubernetes pod using the inline YAML definition.
   - The pod includes two containers: `jnlp` (Jenkins agent) and `kaniko` (Kaniko executor).

2. **Stage Execution**:
   - The pipeline enters the **Build and Push Docker Image** stage.
   - The `kaniko` container runs the Kaniko executor command to build and push the Docker image.

3. **Pod Cleanup**:
   - After the pipeline completes, the Kubernetes pod is automatically deleted.

---

### **Key Features**
1. **Dynamic Pod Provisioning**:
   - The pod is created on-demand and deleted after the pipeline completes.

2. **Kaniko Integration**:
   - Uses Kaniko to build and push Docker images without requiring Docker-in-Docker (DinD).

3. **Secure Authentication**:
   - Uses the `registry-credentials` secret for Docker registry authentication.

4. **Caching**:
   - Enables caching to improve build performance.

5. **Environment Variables**:
   - Dynamically generates image tags using Jenkins environment variables.

---

### **Use Case**
This pipeline is ideal for:
- Automating Docker image builds and pushes in a Kubernetes-native environment.
- Leveraging Kaniko for secure, efficient, and scalable container builds.

---

### **Summary**
- The Jenkinsfile dynamically provisions a Kubernetes pod with a `kaniko` container.
- The Kaniko executor builds and pushes a Docker image using a Git repository as the build context.
- The pipeline is flexible, secure, and optimized for CI/CD workflows in Kubernetes environments.


# **Automate Jenkins Pipeline Creation**

### **1. Automate Using Jenkins Job DSL**
The Jenkins Job DSL allows you to programmatically create and configure Jenkins jobs.

#### **DSL Script**
Save the following script as `create-kaniko-pipeline.groovy`:

```groovy
pipelineJob('Kaniko-Pipeline') {
    definition {
        cps {
            script("""
pipeline {
    agent {
        kubernetes {
            cloud 'gok-kubernetes'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
            """
        }
    }
    environment {
        IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
        IMAGE_TAG = "\${BUILD_ID}"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                   sh """
                        /kaniko/executor \\
                            --context git://github.com/scriptcamp/kubernetes-kaniko \\
                            --destination \${IMAGE_NAME}:\${IMAGE_TAG} \\
                            --destination \${IMAGE_NAME}:latest \\
                            --cache=true \\
                            --insecure \\
                            --skip-tls-verify
                    """
                }
            }
        }
    }
}
"""
            sandbox()
        }
    }
}
```

#### **Steps to Apply the DSL Script**
1. Go to **Manage Jenkins > Manage Plugins** and ensure the **Job DSL Plugin** is installed.
2. Create a new **Freestyle Job** in Jenkins.
3. Add a **Build Step**: **Process Job DSLs**.
4. Paste the above DSL script into the editor or point to the file containing the script.
5. Save and build the job to create the pipeline.

---

### **2. Automate Using Jenkins Configuration as Code (JCasC)**
Jenkins Configuration as Code (JCasC) allows you to define Jenkins jobs and configurations in YAML files.

#### **JCasC YAML**
Save the following YAML as `jenkins-casc.yaml`:

```yaml
jobs:
  - script: >
      pipelineJob('Kaniko-Pipeline') {
          definition {
              cps {
                  script("""
pipeline {
    agent {
        kubernetes {
            cloud 'gok-kubernetes'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
            """
        }
    }
    environment {
        IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
        IMAGE_TAG = "\${BUILD_ID}"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                   sh """
                        /kaniko/executor \\
                            --context git://github.com/scriptcamp/kubernetes-kaniko \\
                            --destination \${IMAGE_NAME}:\${IMAGE_TAG} \\
                            --destination \${IMAGE_NAME}:latest \\
                            --cache=true \\
                            --insecure \\
                            --skip-tls-verify
                    """
                }
            }
        }
    }
}
"""
                  sandbox()
              }
          }
      }
```

#### **Steps to Apply the JCasC YAML**
1. Go to **Manage Jenkins > Configuration as Code**.
2. Upload the `jenkins-casc.yaml` file or point to its location in your repository.
3. Apply the configuration to create the pipeline.

---

### **3. Automate Using Jenkins REST API**
You can also use the Jenkins REST API to create the pipeline programmatically.

#### **cURL Command**
```bash
curl -X POST "http://<jenkins-url>/createItem?name=Kaniko-Pipeline" \
     -u "<username>:<api-token>" \
     -H "Content-Type: application/xml" \
     --data-binary @pipeline-config.xml
```

#### **XML Configuration**
Save the pipeline configuration as `pipeline-config.xml`:
```xml
<flow-definition plugin="workflow-job">
  <description>Kaniko Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent {
        kubernetes {
            cloud 'gok-kubernetes'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    tty: true
    resources:
       requests:
          memory: "1Gi"
          cpu: "1"
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["tail"]
    args: ["-f", "/dev/null"]
    tty: true
    resources:
        requests:
            memory: "1Gi"
            cpu: "1"
    volumeMounts:
      - name: docker-credentials
        mountPath: /kaniko/.docker
  volumes:
    - name: docker-credentials
      secret:
        secretName: registry-credentials
            """
        }
    }
    environment {
        IMAGE_NAME = 'registry.gokcloud.com/kaniko-demo-image'
        IMAGE_TAG = "${BUILD_ID}"
    }
    stages {
        stage('Build and Push Docker Image') {
            steps {
                container('kaniko') {
                   sh """
                        /kaniko/executor \\
                            --context git://github.com/scriptcamp/kubernetes-kaniko \\
                            --destination ${IMAGE_NAME}:${IMAGE_TAG} \\
                            --destination ${IMAGE_NAME}:latest \\
                            --cache=true \\
                            --insecure \\
                            --skip-tls-verify
                    """
                }
            }
        }
    }
}
</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
</flow-definition>
```

---

### **Summary**
- Use **Job DSL** for programmatic pipeline creation within Jenkins.
- Use **JCasC** for declarative configuration of Jenkins pipelines and settings.
- Use the **REST API** for external automation of pipeline creation.

Choose the method that best fits your automation requirements!

# **To get the **API token** for Jenkins, follow these steps:**

---

### **1. Access Jenkins**
1. Open your Jenkins instance in a web browser.
2. Log in with your credentials.

---

### **2. Navigate to Your User Profile**
1. Click on your username in the top-right corner of the Jenkins dashboard.
2. Select **"Configure"** from the dropdown menu.

---

### **3. Generate an API Token**
1. Scroll down to the **API Token** section.
2. Click **"Add new Token"**.
3. Enter a name for the token (e.g., `Kaniko-Pipeline`).
4. Click **"Generate"**.

---

### **4. Copy the API Token**
1. Copy the generated token and save it securely.
   - **Note**: You will not be able to view the token again after leaving the page.
2. Use this token for authentication in API requests or automation scripts.

---

### **5. Use the API Token**
You can use the API token in place of your password for Jenkins REST API requests or CLI commands. For example:

#### **cURL Example**
```bash
curl -X POST "http://<jenkins-url>/createItem?name=Kaniko-Pipeline" \
     -u "<username>:<api-token>" \
     -H "Content-Type: application/xml" \
     --data-binary @pipeline-config.xml
```

---

### **6. Verify the Token**
Test the token by making an API request or using the Jenkins CLI to ensure it works as expected.

---

### **Important Notes**
- Keep the API token secure, as it provides access to your Jenkins account.
- If the token is compromised, revoke it from your user profile and generate a new one.