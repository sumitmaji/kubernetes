# Spinnaker

## Installation

Before installation make sure [`keycloak`](../keycloak/README.md) is installed.
```shell
./gok install spinnaker
```

## UnInstallation
```shell
./gok reset spinnaker
```

## Documentation
https://www.opsmx.com/blog/how-to-install-spinnaker-into-kubernetes-using-helm-charts/
https://github.com/OpsMx/spinnaker-helm
https://artifacthub.io/packages/helm/opsmx/spinnaker
https://asherl.com/how-to-install-spinnaker-in-a-kubernetes-cluster
https://medium.com/velotio-perspectives/know-everything-about-spinnaker-how-to-deploy-using-kubernetes-engine-57090881c78f
https://github.com/justmeandopensource/kubernetes/blob/master/docs/setup-spinnaker.md
https://www.youtube.com/watch?v=9EUyMjR6jSc


Step 2.1: Set up LDAP/AD authentication
https://aws.amazon.com/blogs/opensource/deployment-pipeline-spinnaker-kubernetes/

Step 3: Expose Spinnaker – set up ingress controller
https://aws.amazon.com/blogs/opensource/deployment-pipeline-spinnaker-kubernetes/

Keycloak
https://faun.pub/spinnaker-authentication-with-keycloak-84db39f1123b
https://gist.github.com/keaz/d13a10acdf37a1a13058cbf6caaf5fd0
https://deesprinter.github.io/spinnaker.github.io/setup/security/authentication/oauth/
https://spinnaker.io/docs/reference/halyard/commands/#hal-config-security-authn-oauth2-edit
https://spinnaker.io/docs/setup/other_config/security/authentication/oauth/config/
https://spinnaker.io/docs/setup/other_config/security/authentication/oauth/
https://www.opsmx.com/blog/how-to-install-spinnaker-into-kubernetes-using-helm-charts/
https://www.digitalocean.com/community/tutorials/how-to-set-up-a-cd-pipeline-with-spinnaker-on-digitalocean-kubernetes
https://stackoverflow.com/questions/78087469/how-to-apply-custom-profiles-setting-to-spinnaker-to-make-it-deploy-with-one-com
https://github.com/spinnaker/spinnaker/issues/6498
https://spinnaker.io/docs/reference/halyard/custom/


## Create a sample application and run pipeline
https://www.digitalocean.com/community/tutorials/how-to-set-up-a-cd-pipeline-with-spinnaker-on-digitalocean-kubernetes#step-4-creating-an-application-and-running-a-pipeline


# **To configure a Spinnaker pipeline that triggers a Jenkins pipeline and deploys a Helm chart after the Jenkins build is completed, follow these steps:**

---

### **1. Prerequisites**
Ensure the following are set up:
1. **Spinnaker**:
   - Installed and running.
   - Configured with Kubernetes as a provider.
   - Jenkins integration enabled.
2. **Jenkins**:
   - Installed and running.
   - A Jenkins pipeline is created and accessible.
3. **Helm Chart**:
   - A Helm chart is available for deployment.

---

### **2. Configure Jenkins in Spinnaker**
1. **Enable Jenkins in Spinnaker**:
   Run the following commands in the Halyard container:
   ```bash
   hal config ci jenkins enable
   hal config ci jenkins master add my-jenkins-master \
       --address http://<jenkins-url> \
       --username <jenkins-username> \
       --password <jenkins-password>
   hal deploy apply
   ```

2. **Verify Jenkins Integration**:
   - Go to the Spinnaker UI.
   - Navigate to **"Configuration" > "Jenkins"**.
   - Ensure your Jenkins master is listed.

---

### **3. Create a Spinnaker Pipeline**
1. **Create a New Pipeline**:
   - Go to the Spinnaker UI.
   - Navigate to **"Applications" > "Pipelines"**.
   - Click **"Create Pipeline"** and give it a name.

2. **Add a Jenkins Trigger**:
   - In the pipeline configuration, click **"Add Trigger"**.
   - Select **"Jenkins"** as the trigger type.
   - Configure the following:
     - **Master**: Select your Jenkins master.
     - **Job**: Select the Jenkins pipeline job.
     - **Property File** (optional): Specify if you want to pass properties from Jenkins to Spinnaker.

3. **Add a Jenkins Stage**:
   - Click **"Add Stage"**.
   - Select **"Jenkins"** as the stage type.
   - Configure the following:
     - **Master**: Select your Jenkins master.
     - **Job**: Select the Jenkins pipeline job.
     - **Wait for Completion**: Enable this to wait for the Jenkins job to complete before proceeding.

4. **Add a Helm Deployment Stage**:
   - Click **"Add Stage"**.
   - Select **"Deploy (Manifest)"** as the stage type.
   - Configure the following:
     - **Account**: Select your Kubernetes account.
     - **Manifest Source**: Select **"Artifact"**.
     - **Artifact**: Specify the Helm chart artifact (e.g., from a Helm repository or Git).

---

### **4. Example Pipeline Configuration**
Here’s an example pipeline configuration:
1. **Trigger**:
   - Type: Jenkins
   - Master: `my-jenkins-master`
   - Job: `my-jenkins-job`

2. **Stages**:
   - **Stage 1**: Jenkins
     - Master: `my-jenkins-master`
     - Job: `my-jenkins-job`
     - Wait for Completion: Enabled.
   - **Stage 2**: Deploy (Manifest)
     - Account: `my-kubernetes-account`
     - Manifest Source: Artifact
     - Artifact: `my-helm-chart`

---

### **5. Save and Test the Pipeline**
1. Save the pipeline.
2. Trigger the pipeline manually or wait for the Jenkins job to trigger it.
3. Verify that:
   - The Jenkins job runs successfully.
   - The Helm chart is deployed to the Kubernetes cluster.

---

### **6. Automate Helm Chart Artifact Creation**
If the Helm chart is built as part of the Jenkins pipeline, ensure the chart is published to a Helm repository or stored as an artifact accessible to Spinnaker.


# Using both a **Jenkins trigger** and a **Jenkins stage** in a Spinnaker pipeline serves different purposes, and whether you need both depends on your use case. Here's why you might use both:

---

### **1. Jenkins Trigger**
- **Purpose**: Automatically starts the Spinnaker pipeline when a Jenkins job completes.
- **Use Case**: 
  - If you want the Spinnaker pipeline to be initiated by a Jenkins job (e.g., a build or test job).
  - The trigger listens for the Jenkins job's completion and starts the pipeline without manual intervention.
- **Example**: A Jenkins job builds a Docker image and pushes it to a container registry. Once the job completes, the Spinnaker pipeline is triggered to deploy the image.

---

### **2. Jenkins Stage**
- **Purpose**: Executes a Jenkins job as part of the Spinnaker pipeline.
- **Use Case**:
  - If you want the Jenkins job to be part of the pipeline execution flow.
  - The pipeline waits for the Jenkins job to complete before proceeding to the next stage.
- **Example**: A Jenkins job runs integration tests or builds a Helm chart, and the pipeline waits for the job to finish before deploying the chart.

---

### **Why Use Both?**
You might need both a **Jenkins trigger** and a **Jenkins stage** if:
1. **Triggering the Pipeline**:
   - The pipeline is triggered by a Jenkins job (e.g., a build job).
2. **Executing Additional Jenkins Jobs**:
   - The pipeline itself needs to execute other Jenkins jobs (e.g., running tests or building artifacts) as part of its workflow.

---

### **When to Use Only One**
- **Only Jenkins Trigger**:
  - Use this if the Jenkins job completes all necessary tasks (e.g., building and testing) and the Spinnaker pipeline only needs to handle deployment.
- **Only Jenkins Stage**:
  - Use this if the pipeline is triggered by another mechanism (e.g., a Git trigger or manual start) and you need to run a Jenkins job as part of the pipeline.

---

### **Example Scenarios**
1. **Using Both**:
   - A Jenkins job builds a Docker image and triggers the Spinnaker pipeline.
   - The pipeline runs another Jenkins job to perform integration tests before deploying the image.

2. **Using Only a Trigger**:
   - A Jenkins job builds and tests a Docker image, then triggers the Spinnaker pipeline to deploy the image.

3. **Using Only a Stage**:
   - A Spinnaker pipeline is triggered manually or by a Git commit, and it runs a Jenkins job to build and test the application before deploying it.

---

### **Conclusion**
- Use a **Jenkins trigger** to start the pipeline based on a Jenkins job's completion.
- Use a **Jenkins stage** to include Jenkins jobs as part of the pipeline's workflow.
- Use both if you need to trigger the pipeline from Jenkins and also run additional Jenkins jobs within the pipeline.