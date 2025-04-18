# Gokutil Installation and Usage Guide

This document provides step-by-step instructions for setting up and using the `gokutil` directory, which contains scripts and configurations for building, tagging, pushing Docker images, and running Kubernetes jobs.

## Overview

The `gokutil` directory includes the following components:
- **Scripts**: Automate Docker image management and Kubernetes job execution.
- **Configuration**: Centralized settings for Docker and Kubernetes operations.
- **Dockerfile**: Defines the base image and dependencies for the container.
- **Kubernetes Job YAML**: Template for running a Kubernetes job.

## Prerequisites

1. Ensure Docker is installed and running.
2. Ensure Kubernetes is installed and configured.
3. Install the following dependencies:
   - `bash`
   - `kubectl`
   - `jq`
4. Verify access to the Docker registry specified in the configuration file.

## Installation Steps

1. **Clone the Repository**
   - Clone the repository containing the `gokutil` directory:
     ```bash
     git clone <repository-url>
     cd <repository-name>/install_k8s/gokutil
     ```

2. **Set Executable Permissions**
   - Make all scripts in the `gokutil` directory executable:
     ```bash
     chmod +x *.sh
     ```

3. **Update Configuration**
   - Edit the `configuration` file to set the appropriate values for your environment:
     ```bash
     IMAGE_NAME=<your-image-name>
     REGISTRY=<your-registry-url>
     REPO_NAME=<your-repo-name>
     CONTAINER_NAME=<your-container-name>
     BUILD_PATH=<your-build-path>
     RELEASE_NAME=<your-release-name>
     PATH_TO_CHART=<path-to-helm-chart>
     DEPLOY=<true-or-false>
     ```

## Usage

### Build Docker Image
- Use the `build.sh` script to build the Docker image:
  ```bash
  ./build.sh
  ```
- The script builds the image using the `Dockerfile` and exits with a success or failure code.

### Tag and Push Docker Image
- Use the `tag_push.sh` script to tag and push the Docker image to the registry:
  ```bash
  ./tag_push.sh
  ```
- The script tags the image with the registry URL and pushes it to the specified repository.

### Continuous Integration
- Use the `ci.sh` script to automate the build and push process:
  ```bash
  ./ci.sh
  ```
- This script runs `build.sh` followed by `tag_push.sh`.

### Kubernetes Job Deployment
- Use the `job.yaml` file to deploy a Kubernetes job:
  ```bash
  kubectl apply -f job.yaml
  ```
- **Purpose**: This job is used to create LDAP users and groups. It runs a container with the specified image and executes a user-provided script that interacts with the LDAP server. The script uses environment variables and secrets provided via ConfigMaps and Secrets.

### Dockerfile
- The `Dockerfile` defines the base image and installs necessary tools like `ldap-utils`, `bash`, `curl`, and `jq`. You can customize it as needed.

## Notes

- Ensure the `configuration` file is updated with valid values before running any scripts.
- Replace placeholders in the `job.yaml` file with actual values specific to your environment.
- Review the scripts and YAML files to ensure they meet your requirements.

## Support

For issues or questions, contact the repository maintainer or refer to the repository's documentation.
