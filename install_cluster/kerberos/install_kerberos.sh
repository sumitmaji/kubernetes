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

LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-kdc krb5-admin-server krb5-kdc-ldap

# kerberos client and pam configuration for kerberos
apt-get install -yq krb5-user libpam-krb5

mkdir -p /etc/secret/krb

echo "${LDAP_PASSWORD}" >/etc/secret/ldap/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/password
echo "${KDC_PASSWORD}" >/etc/secret/krb/kdcpassword
echo "${KDC_PASSWORD}" >/etc/secret/krb/admpassword