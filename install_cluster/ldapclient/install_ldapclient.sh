#!/bin/bash
[[ "TRACE" ]] && set -x
# ./install_ldap.sh -d master.cloud.com -h ldap.master.cloud.com -b dc=master,dc=cloud,dc=com -p sumit -k admin
: ${ENV:="LOCAL"}
while [ $# -gt 0 ]; do
  case "$1" in
  -d | --domain)
    shift
    LDAP_DOMAIN=$1
    ;;
  -h | --hostname)
    shift
    LDAP_HOSTNAME=$1
    ;;
  -b | --basedn)
    shift
    BASE_DN=$1
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

DEBIAN_FRONTEND=noninteractive
LDAP_ORG=CloudInc

echo "ldap domain: $LDAP_DOMAIN"
echo "ldap hostname: $LDAP_HOSTNAME"
echo "ldap base_dn: $BASE_DN"
echo "LDAP_PASSWORD: $LDAP_PASSWORD"

DEBIAN_FRONTEND=noninteractive

# Keep upstart from complaining
dpkg-divert --local --rename --add /sbin/initctl
ln -sf /bin/true /sbin/initctl
DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -yq apt debconf
apt-get upgrade -yq
apt-get -y -o Dpkg::Options::="--force-confdef" upgrade
apt-get -y dist-upgrade

echo "ldap-auth-config ldap-auth-config/rootbindpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/bindpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/dblogin boolean false" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/override boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap://$LDAP_HOSTNAME" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/pam_password string md5" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/dbrootlogin boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=net" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/ldap_version string 3" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/move-to-debconf boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/base-dn string $BASE_DN" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/rootbinddn string cn=admin,$BASE_DN" | debconf-set-selections

apt-get install -yq ldap-auth-client nscd krb5-user libpam-krb5 libpam-ccreds
apt-get install -yq ntp ntpdate nmap libsasl2-modules-gssapi-mit


echo "$LDAP_PASSWORD" >/etc/ldap.secret
chmod 600 /etc/ldap.secret


# Cleanup Apt
apt-get autoremove
apt-get autoclean
apt-get clean