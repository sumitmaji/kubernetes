#!/bin/bash
[[ "TRACE" ]] && set -x

while [ $# -gt 0 ]; do
  case "$1" in
  -d | --domain)
    shift
    DOMAIN_NAME=$1
    ;;
  -p | --password)
    shift
    LDAP_PASSWORD=$1
    ;;
  -k | --kpassword)
    shift
    KDC_PASSWORD=$1
    ;;
  esac
  shift
done


echo "kerberos krb5-config/default_realm string ${DOMAIN_NAME}" | debconf-set-selections

# kerberos client and pam configuration for kerberos
LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-user libpam-krb5

# Kerberize sshd
apt-get install -yq libsasl2-modules-gssapi-mit

mkdir -p /etc/secret/krb
mkdir -p /etc/secret/ldap
echo "${LDAP_PASSWORD}" >/etc/secret/ldap/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/kdcpassword
echo "${KDC_PASSWORD}" >/etc/secret/krb/admpassword

utility/bootstrap.sh

