#!/bin/bash

STATUS=`grep "ldap compat" /etc/nsswitch.conf`
if [ -z "$STATUS" ]
then
`sed -i 's/compat/ldap compat/' /etc/nsswitch.conf`
fi


echo 'account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so
account requisite                       pam_deny.so
account required                        pam_permit.so
account required                        pam_krb5.so minimum_uid=1000' > /etc/pam.d/common-account

echo 'auth    [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
auth    [success=1 default=ignore]      pam_unix.so nullok_secure try_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so' > /etc/pam.d/common-auth

echo 'password        [success=2 default=ignore]      pam_krb5.so minimum_uid=1000
password        [success=1 default=ignore]      pam_unix.so obscure use_authtok try_first_pass sha512
password        requisite                       pam_deny.so
password        required                        pam_permit.so' > /etc/pam.d/common-password

echo 'session [default=1]                     pam_permit.so
session requisite                       pam_deny.so
session required                        pam_permit.so
session optional                        pam_krb5.so minimum_uid=1000
session required        pam_unix.so
session required        pam_mkhomedir.so        skel=/etc/skel umaks=0022' > /etc/pam.d/common-session



service nscd restart

STATUS=`grep "%admins ALL=(ALL) ALL" /etc/sudoers`
if [ -z "$STATUS" ]
then
`sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers`
fi

