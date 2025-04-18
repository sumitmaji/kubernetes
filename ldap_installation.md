# LDAP Installation Guide

This document provides step-by-step instructions for installing LDAP using the `run_ldap.sh` script.

## Prerequisites

1. Ensure Kubernetes is installed and running.
2. Helm must be installed and configured.
3. Docker must be installed and running.

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

## Notes

- Replace placeholders like `<DOCKER_USER>`, `<DOCKER_PASSWORD>`, `<ldap-subdomain>`, and `<root-domain>` with actual values.
- Ensure Cert-Manager is properly configured to issue certificates.
- The `configuration` file must be updated with the correct paths and repository details before running the script.
