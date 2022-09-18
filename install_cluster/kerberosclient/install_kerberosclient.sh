#!/bin/bash
[[ "TRACE" ]] && set -x

: ${CONFIG_FILE:=$MOUNT_PATH/kubernetes/install_cluster/config}

source $CONFIG_FILE

echo "kerberos krb5-config/default_realm string ${DOMAIN_NAME}" | debconf-set-selections

# kerberos client and pam configuration for kerberos
LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-user libpam-krb5

# Kerberize services
apt-get install -yq libsasl2-modules-gssapi-mit

mkdir -p /etc/secret/krb
mkdir -p /etc/secret/ldap
echo "${LDAP_PASSWORD}" >/etc/secret/ldap/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/kdcpassword
echo "${KDC_PASSWORD}" >/etc/secret/krb/admpassword

utility/bootstrap.sh

