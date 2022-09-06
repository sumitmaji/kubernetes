#!/bin/bash
[[ "TRACE" ]] && set -x

: ${CONFIG_FILE:=$MOUNT_PATH/kubernetes/install_cluster/config}

source $CONFIG_FILE

apt-get update

echo "kerberos krb5-config/default_realm string ${DOMAIN_NAME}" | debconf-set-selections

LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-kdc krb5-admin-server krb5-kdc-ldap

# kerberos client and pam configuration for kerberos
apt-get install -yq krb5-user libpam-krb5

mkdir -p /etc/secret/krb

echo "${LDAP_PASSWORD}" >/etc/secret/ldap/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/kdcpassword
echo "${KDC_PASSWORD}" >/etc/secret/krb/admpassword

utility/config.sh
