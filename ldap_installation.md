# LDAP Installation Guide

This document provides step-by-step instructions for installing LDAP using the `run_ldap.sh` script and managing users and groups with the `createUserGroup` function.

## Prerequisites

1. Ensure Kubernetes is installed and running.
2. Helm must be installed and configured.
3. Docker must be installed and running.
4. The `gokclient` Docker image must be available. Build and save it using the `ci.sh` script located in the `gokutil` directory:
   ```bash
   cd $MOUNT_PATH/kubernetes/install_k8s/gokutil
   ./ci.sh
   ```

## Installation Steps

1. **Set Environment Variables**
   - Ensure the following environment variables are set in the `configuration` file:
     - `MOUNT_PATH`: Path to the Kubernetes installation directory.
     - `REPO_NAME`: Docker repository name for the LDAP image.
     - `RELEASE_NAME`: Helm release name for LDAP.

2. **Build and Push Docker Image**
   - The `run_ldap.sh` script automatically builds and pushes the Docker image for LDAP using the `build.sh` and `tag_push.sh` scripts.

3. **Run the Installation Script**
   - Execute the `run_ldap.sh` script with the following options:
     ```bash
     ./run_ldap.sh --user <DOCKER_USER> --password <DOCKER_PASSWORD>
     ```
     Replace `<DOCKER_USER>` and `<DOCKER_PASSWORD>` with your Docker credentials.

4. **Patch Ingress**
   - Patch the LDAP ingress to use Let's Encrypt certificates:
     ```bash
     gok patch ingress ldap ldap letsencrypt <ldap-subdomain>
     ```

5. **Wait for Services**
   - Wait for all LDAP pods to be ready:
     ```bash
     kubectl --timeout=240s wait --for=condition=Ready pods --all --namespace ldap
     ```

6. **Access LDAP**
   - Once the installation is complete, access LDAP at:
     ```
     https://<ldap-subdomain>.<root-domain>/
     ```

## Managing Users and Groups

The `createUserGroup` function allows you to create LDAP users and groups dynamically.

### Design Details

1. **Script Content Passed to Job**
   - The `createUserGroup` function copies the specified script (e.g., `create_ldap_user.sh` or `create_ldap_group.sh`) to a temporary location (`/tmp/user_script.sh`).
   - The script is then added to a Kubernetes ConfigMap named `user-script`.

2. **Job Execution**
   - The `job.yaml` file defines a Kubernetes Job that:
     - Mounts the `user-script` ConfigMap as a volume at `/scripts`.
     - Copies the script from `/scripts/user_script.sh` to `/tmp/user_script.sh` inside the container.
     - Executes the script after making it executable.

3. **Environment Variables**
   - The job uses environment variables from the following sources:
     - `ldap-user-data` ConfigMap: Contains user-specific data like username, password, email, etc.
     - `ldap-env-config` ConfigMap: Contains LDAP environment configuration like `LDAP_HOSTNAME` and `BASE_DN`.
     - `ldapsecret` Secret: Contains sensitive LDAP credentials.

4. **Cleanup**
   - After the job completes, the following resources are deleted to ensure no sensitive data is left behind:
     - The job itself.
     - ConfigMaps (`ldap-user-data`, `user-script`, `ldap-env-config`).
     - The `ldapsecret` secret in the `default` namespace.

### Usage

```bash
createUserGroup -u <USERNAME> -p <PASSWORD> -e <EMAIL> -f <FIRST_NAME> -l <LAST_NAME> -g <GROUP_NAME> -s <SCRIPT_NAME>
```

### Parameters

- `-u | --username`: Username for the LDAP user.
- `-p | --password`: Password for the LDAP user.
- `-e | --email`: Email address of the LDAP user.
- `-f | --first-name`: First name of the LDAP user.
- `-l | --last-name`: Last name of the LDAP user.
- `-g | --group-name`: Name of the LDAP group.
- `-s | --script-name`: Script to execute for creating the user or group. Examples:
  - `create_ldap_user.sh`: For creating a user.
  - `create_ldap_group.sh`: For creating a group.

### Example

1. **Create a User**
   ```bash
   createUserGroup -u john.doe -p password123 -e john.doe@example.com -f John -l Doe -g developers -s create_ldap_user.sh
   ```

2. **Create a Group**
   ```bash
   createUserGroup -g administrators -s create_ldap_group.sh
   ```

### Notes

- Ensure the `ldapsecret` secret is copied to the `default` namespace before running the function.
- Update the `ldap-env-config` ConfigMap with the correct `LDAP_HOSTNAME` and `BASE_DN` values.

## Notes

- Replace placeholders like `<DOCKER_USER>`, `<DOCKER_PASSWORD>`, `<ldap-subdomain>`, and `<root-domain>` with actual values.
- Ensure Cert-Manager is properly configured to issue certificates.
- The `configuration` file must be updated with the correct paths and repository details before running the script.
