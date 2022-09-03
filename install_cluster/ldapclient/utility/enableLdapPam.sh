#!/bin/bash

STATUS=$(grep "ldap" /etc/nsswitch.conf)
if [ -z "$STATUS" ]; then
  sed -i 's/files systemd/files ldap systemd/g' /etc/nsswitch.conf
  sed -i 's/\(shadow:\)\(.*\)files/\1\2files ldap/g' /etc/nsswitch.conf
  sed -i 's/netgroup:\(.*\)nis/netgroup:\1ldap/g' /etc/nsswitch.conf
fi

STATUS=$(grep "umask=0022 skel=/etc/skel" /etc/pam.d/common-session)

if [ -z "$STATUS" ]; then
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

fi

service nscd restart

STATUS=$(grep "%admins ALL=(ALL) ALL" /etc/sudoers)
if [ -z "$STATUS" ]; then
  $(sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers)
fi
