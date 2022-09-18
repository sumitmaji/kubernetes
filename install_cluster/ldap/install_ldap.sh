#!/bin/bash
[[ "TRACE" ]] && set -x

: ${CONFIG_FILE:=$MOUNT_PATH/kubernetes/install_cluster/config}

source $CONFIG_FILE

apt-get update

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

LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils

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

# To enable the system see and use LDAP accounts, we need to install libnss-ldap, libpam-ldap and nscd.
# ldap-auth-client: will install all required packages for an ldap client (auth-client-config, ldap-auth-config, libnss-ldap and libpam-ldap)
# libpam-ccreds: To cache the password information through the use of the PAM module
apt-get install -yq ldap-auth-client nscd libpam-ccreds
apt-get install -yq ntp ntpdate nmap schema2ldif

mkdir -p /etc/secret/ldap
echo "${LDAP_PASSWORD}" >/etc/secret/ldap/password

STATUS=$(grep "ldap" /etc/nsswitch.conf)
if [ -z "$STATUS" ]; then
  sed -i 's/files systemd/files ldap systemd/g' /etc/nsswitch.conf
  sed -i 's/\(shadow:\)\(.*\)files/\1\2files ldap/g' /etc/nsswitch.conf
  sed -i 's/netgroup:\(.*\)nis/netgroup:\1ldap/g' /etc/nsswitch.conf
fi

echo '# Disable if using Kerberos:
account [success=2 new_authtok_reqd=done default=ignore]        pam_unix.so
account [success=1 default=ignore]      pam_ldap.so

# Enable if using Kerberos:
#account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so

account requisite                       pam_deny.so

account required                        pam_permit.so

# Enable if using Kerberos:
#account required                        pam_krb5.so minimum_uid=1000' >/etc/pam.d/common-account

echo '# Disable if using Kerberos:
auth    [success=2 default=ignore]      pam_unix.so nullok_secure
auth    [success=1 default=ignore]      pam_ldap.so use_first_pass

# Enable if using Kerberos:
#auth    [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
#auth    [success=1 default=ignore]      pam_unix.so nullok_secure try_first_pass

auth    requisite                       pam_deny.so

auth    required                        pam_permit.so' >/etc/pam.d/common-auth

echo '# Disable if using Kerberos:
password        [success=2 default=ignore]      pam_unix.so obscure sha512
password        [success=1 user_unknown=ignore default=die]     pam_ldap.so use_authtok try_first_pass

# Enable if using Kerberos:
#password        [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
#password        [success=1 default=ignore]      pam_unix.so obscure use_authtok try_first_pass sha512

password        requisite                       pam_deny.so

password        required                        pam_permit.so' >/etc/pam.d/common-password

echo 'session [default=1]                     pam_permit.so

session requisite                       pam_deny.so

session required                        pam_permit.so

# Enable if using Kerberos:
#session  optional  pam_krb5.so minimum_uid=1000

session required        pam_unix.so

# Disable if using Kerberos:
session optional                        pam_ldap.so
session required        pam_mkhomedir.so        skel=/etc/skel umaks=0022' >/etc/pam.d/common-session

service nscd restart

STATUS=$(grep "%admins ALL=(ALL) ALL" /etc/sudoers)
if [ -z "$STATUS" ]; then
  sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers
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

# Cleanup Apt
apt-get autoremove
apt-get autoclean
apt-get clean

touch /var/userid
echo '1000' >/var/userid
chown root:root /var/userid
touch /var/groupid
chown root:root /var/groupid
echo '502' >/var/groupid

utility/bootstrap.sh