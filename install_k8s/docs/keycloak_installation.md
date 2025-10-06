# Keycloak Installation Guide

This document provides step-by-step instructions for installing Keycloak with Let's Encrypt certificates using the `installKeycloakWithCertMgr` function.

## Prerequisites

1. Ensure Kubernetes is installed and running.
2. Cert-Manager must be installed and configured.
3. Helm must be installed.

## Installation Steps

1. **Create Namespace and Secrets**
   - Create the `keycloak` namespace.
   - Create the `keycloak-secrets` secret with the following values:
     - `KEYCLOAK_LOG_LEVEL`: `TRACE`
     - `KEYCLOAK_ADMIN`: `user`
     - `CLIENT_ID`: `<OIDC_CLIENT_ID>`
     - `OAUTH_REALM`: `<REALM>`
     - `hostname`: `<keycloak-subdomain>.<root-domain>` (dynamically calculated)
   - Create the `keycloak-postgresql` secret with the following values:
     - `username`: `<POSTGRESQL_USERNAME>`
     - `password`: `<POSTGRESQL_PASSWORD>`
     - `postgres-password`: `<POSTGRESQL_PASSWORD>`

2. **Install Keycloak**
   - Use the following Helm command to install Keycloak:
     ```bash
     helm install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak \
         --namespace keycloak \
         --set ingress.hostname="<keycloak-subdomain>.<root-domain>" \
         --create-namespace \
         --values <path-to-values2.yaml>
     ```

3. **Create Persistent Volume**
   - Create a local storage class and persistent volume for Keycloak:
     ```bash
     createLocalStorageClassAndPV "keycloak-storage" "keycloak-pv" "/data/volumes/pv3"
     ```

4. **Patch Ingress**
   - Patch the Keycloak ingress to use Let's Encrypt certificates:
     ```bash
     gok patch ingress keycloak keycloak letsencrypt <keycloak-subdomain>
     ```

5. **Wait for Services**
   - Wait for all Keycloak pods to be ready:
     ```bash
     kubectl --timeout=240s wait --for=condition=Ready pods --all --namespace keycloak
     ```

6. **Configure Keycloak**
   - Install Python dependencies:
     ```bash
     apt install python3-dotenv python3-requests python3-jose -y
     ```
   - Run the Keycloak client setup script:
     ```bash
     python3 <path-to-keycloak-client.py> all <ADMIN_ID> <ADMIN_PWD> <CLIENT_ID> <REALM>
     ```
   - Create OAuth2 secrets:
     ```bash
     oauth2Secret
     ```

7. **LDAP Integration (Optional)**

### Setup User Federation
- The `setup_user_federation.sh` script configures LDAP user federation in Keycloak.
- It performs the following tasks:
  - Connects Keycloak to the LDAP server using the provided credentials.
  - Configures LDAP connection settings such as `connectionUrl`, `bindDn`, and `usersDn`.
  - Sets up synchronization options like `importEnabled` and `syncRegistrations`.
- Usage:
  ```bash
  ./setup_user_federation.sh <ADMIN_USERNAME> <ADMIN_PASSWORD> <LDAP_BIND_CREDENTIAL>
  ```
  - Replace `<ADMIN_USERNAME>` and `<ADMIN_PASSWORD>` with the Keycloak admin credentials.
  - Replace `<LDAP_BIND_CREDENTIAL>` with the LDAP bind password.

### Setup Group Mapper
- The `setup_group_mappers.sh` script configures the LDAP group mapper in Keycloak.
- It performs the following tasks:
  - Maps LDAP groups to Keycloak groups.
  - Configures attributes like `membership.ldap.attribute`, `group.name.ldap.attribute`, and `group.object.classes`.
  - Ensures LDAP groups are synchronized with Keycloak.
- Usage:
  ```bash
  ./setup_group_mappers.sh <ADMIN_USERNAME> <ADMIN_PASSWORD>
  ```
  - Replace `<ADMIN_USERNAME>` and `<ADMIN_PASSWORD>` with the Keycloak admin credentials.

- Run the user federation script:
  ```bash
  ./run_user_federation.sh <ADMIN_ID> <ADMIN_PWD> <LDAP_USER>
  ```
- Run the Keycloak groups creation script:
  ```bash
  ./run_keycloak_groups.sh <ADMIN_ID> <ADMIN_PWD>
  ```

## Access Keycloak

- Once the installation is complete, access Keycloak at:
  ```
  https://<keycloak-subdomain>.<root-domain>/
  ```

## Notes

- Replace placeholders like `<OIDC_CLIENT_ID>`, `<REALM>`, `<POSTGRESQL_USERNAME>`, `<POSTGRESQL_PASSWORD>`, `<keycloak-subdomain>`, and `<root-domain>` with actual values.
- Ensure Cert-Manager is properly configured to issue certificates.
