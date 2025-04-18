# HAProxy Installation and Configuration Guide

This document outlines the steps for installing and configuring HAProxy as a load balancer for Kubernetes.

## Prerequisites
1. **Docker Installation**:
   - Ensure Docker is installed on the system.
   - Refer to the [Docker Installation Guide](./docker_installation.md).

2. **HAProxy Configuration Directory**:
   - Ensure the directory `/opt` exists and is writable for storing the HAProxy configuration file.

## Installation Steps
1. **Stop and Remove Existing HAProxy Container**:
   - If an HAProxy container is already running, stop and remove it.
   - Commands:
     ```bash
     docker stop master-proxy
     docker rm master-proxy
     ```

2. **Create HAProxy Configuration File**:
   - Create the HAProxy configuration file at `/opt/haproxy.cfg`.
   - Example configuration:
     ```plaintext
     global
         log 127.0.0.1 local0
         log 127.0.0.1 local1 notice
         maxconn 4096
         maxpipes 1024
         daemon
     defaults
         log global
         mode tcp
         option tcplog
         option dontlognull
         option redispatch
         option http-server-close
         retries 3
         timeout connect 5000
         timeout client 50000
         timeout server 50000
         frontend default_frontend
         bind *:$HA_PROXY_PORT
         default_backend master-cluster
     backend master-cluster
     ...dynamic server entries based on `$API_SERVERS`...
     ```

   - The backend server entries are dynamically generated based on the `$API_SERVERS` environment variable.

3. **Run HAProxy Container**:
   - Start the HAProxy container using the configuration file.
   - Command:
     ```bash
     docker run -d --name master-proxy \
       -v /opt/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
       --net=host haproxy
     ```

## Post-Installation Steps
1. **Verify HAProxy is Running**:
   - Check if the HAProxy container is running.
   - Command: `docker ps | grep master-proxy`

2. **Test HAProxy**:
   - Ensure HAProxy is forwarding traffic to the Kubernetes API servers.
   - Use tools like `curl` or `telnet` to test connectivity.

## Configuration Dependencies
| **Configuration Source** | **Description**                                                                 |
|---------------------------|---------------------------------------------------------------------------------|
| `$API_SERVERS`            | Contains the list of Kubernetes API server IPs and hostnames. Used to dynamically generate backend server entries. |
| `$HA_PROXY_PORT`          | Specifies the port on which HAProxy listens for incoming traffic.              |
| `kubernetes/install_k8s/gok` | The script dynamically generates the HAProxy configuration file based on these variables. |
| `kubernetes/install_k8s/config` | Contains additional configuration details required for HAProxy setup.      |

2. **HAProxy Configuration File**:
   - Path: `/opt/haproxy.cfg`
   - Dynamically generated based on `$API_SERVERS`.

3. **Docker**:
   - HAProxy is run as a Docker container using the `haproxy` image.

## Notes
- Ensure all environment variables are correctly set before running the script.
- The HAProxy container uses the `haproxy` image from Docker Hub.
- The script dynamically generates the backend server entries in the HAProxy configuration file based on the `$API_SERVERS` environment variable.
- Additional configuration details are sourced from `kubernetes/install_k8s/config`.

For further details, refer to the script located at `/home/sumit/Documents/repository/kubernetes/install_k8s/gok`.