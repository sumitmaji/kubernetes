#!/bin/bash
[[ "TRACE" ]] && set -x

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
    LDC_PASSWORD=$1
    ;;
  esac
  shift
done

# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d

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

echo "slapd slapd/internal/adminpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "slapd slapd/internal/generated_adminpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "slapd slapd/password2 password ${LDAP_PASSWORD}" | debconf-set-selections
echo "slapd slapd/password1 password ${LDAP_PASSWORD}" | debconf-set-selections
echo "slapd slapd/domain string ${LDAP_DOMAIN}" | debconf-set-selections
echo "slapd shared/organization string ${LDAP_ORG}" | debconf-set-selections
echo "slapd slapd/backend string HDB" | debconf-set-selections
echo "slapd slapd/purge_database boolean true" | debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
echo "slapd slapd/allow_ldap_v2 boolean false" | debconf-set-selections
echo "slapd slapd/no_configuration boolean false" | debconf-set-selections
echo "slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION" | debconf-set-selections
echo "slapd slapd/dump_database select when needed" | debconf-set-selections

LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes slapd ldap-utils

apt-get install -yq phpldapadmin

sed -i "s/servers->setValue('server','host','127.0.0.1');/servers->setValue('server','host','${LDAP_HOSTNAME}');/" /etc/phpldapadmin/config.php
sed -i "s/servers->setValue('server','base',array('dc=example,dc=com'));/servers->setValue('server','base',array('$BASE_DN'));/" /etc/phpldapadmin/config.php
sed -i "s/servers->setValue('login','bind_id','cn=admin,dc=example,dc=com');/servers->setValue('login','bind_id','cn=admin,$BASE_DN');/" /etc/phpldapadmin/config.php
sed -i "s/'appearance','password_hash'/'appearance','password_hash_custom'/" /usr/share/phpldapadmin/lib/TemplateRender.php

sed -i "s/<VirtualHost \*:80>/<VirtualHost \*:8181>/" /etc/apache2/sites-available/000-default.conf
sed -i "s/Listen 80/Listen 8181/" /etc/apache2/ports.conf

# Set FQDN for Apache Webserver
echo "ServerName ${LDAP_HOSTNAME}" >/etc/apache2/conf-available/fqdn.conf
a2enconf fqdn

echo "ldap-auth-config ldap-auth-config/rootbindpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/bindpw password ${LDAP_PASSWORD}" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/dblogin boolean false" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/override boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap:///$LDAP_HOSTNAME" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/pam_password string md5" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/dbrootlogin boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=net" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/ldap_version string 3" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/move-to-debconf boolean true" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/ldapns/base-dn string $BASE_DN" | debconf-set-selections
echo "ldap-auth-config ldap-auth-config/rootbinddn string cn=admin,$BASE_DN" | debconf-set-selections

cat >/etc/auth-client-config/profile.d/krb-ldap-config <<EOF
[krb_ldap]
nss_group=group:          files ldap
nss_passwd=passwd:         files ldap
nss_shadow=shadow:         files ldap
nss_netgroup=netgroup:       ldap
pam_account=account sufficient        pam_unix.so
        account sufficient        pam_krb5.so
        account required          pam_deny.so
pam_auth=auth sufficient pam_krb5.so
        auth sufficient pam_unix.so use_first_pass
        auth required   pam_deny.so
pam_password=password  sufficient   pam_unix.so nullok obscure md5
        password  sufficient   pam_krb5.so use_first_pass
        password  required     pam_deny.so
pam_session=session required        pam_unix.so
EOF

apt-get install -yq ldap-auth-client nscd krb5-user libpam-krb5 libpam-ccreds
auth-client-config -a -p krb_ldap

STATUS=$(grep "ldap compat" /etc/nsswitch.conf)
if [ -z "$STATUS" ]; then
  $(sed -i 's/compat/ldap compat/' /etc/nsswitch.conf)
fi

echo 'account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so
account requisite                       pam_deny.so
account required                        pam_permit.so
account required                        pam_krb5.so minimum_uid=1000' >/etc/pam.d/common-account

echo 'auth    [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
auth    [success=1 default=ignore]      pam_unix.so nullok_secure try_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so' >/etc/pam.d/common-auth

echo 'password        [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
password        [success=1 default=ignore]      pam_unix.so obscure use_authtok try_first_pass sha512
password        requisite                       pam_deny.so
password        required                        pam_permit.so' >/etc/pam.d/common-password

echo 'session [default=1]                     pam_permit.so
session requisite                       pam_deny.so
session required                        pam_permit.so
session optional                        pam_krb5.so minimum_uid=1000
session required        pam_unix.so
session required        pam_mkhomedir.so        skel=/etc/skel umaks=0022' >/etc/pam.d/common-session

service nscd restart

STATUS=$(grep "%admins ALL=(ALL) ALL" /etc/sudoers)
if [ -z "$STATUS" ]; then
  $(sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers)
fi

echo "$LDAP_PASSWORD" >/etc/ldap.secret
chmod 600 /etc/ldap.secret
adduser openldap sudo
echo openldap:openldap | chpasswd
chown -R openldap:openldap /var/lib/ldap

chown -R openldap:openldap /etc/ldap

chgrp openldap /etc/init.d/slapd
chmod g+x /etc/init.d/slapd
echo "local4.*			/var/log/sldapd.log" >/etc/rsyslog.d/slapd.conf

apt-get install -yq ntp ntpdate nmap libsasl2-modules-gssapi-mit

# Cleanup Apt
apt-get autoremove
apt-get autoclean
apt-get clean

touch /var/userid
echo '1000' >/var/userid
chown root:root /var/userid
touch /var/groupidb
chown root:root /var/groupid
echo '502' >/var/groupid

mkdir -p /etc/secret/krb
mkdir -p /etc/secret/ldap

echo "${LDAP_PASSWORD}" > /etc/secret/ldap/password
echo "${KDC_PASSWORD}" > /etc/secret/krb/password
echo "${KDC_PASSWORD}" > /etc/secret/krb/kdcpassword
echo "${KDC_PASSWORD}" > /etc/secret/krb/admpassword
