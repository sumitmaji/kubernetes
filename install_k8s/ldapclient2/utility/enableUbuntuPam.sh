#!/bin/bash

echo 'account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so\naccount requisite                       pam_deny.so\naccount required                        pam_permit.so'  > /etc/pam.d/common-account

echo 'auth    [success=1 default=ignore]      pam_unix.so nullok_secure\nauth    requisite                       pam_deny.so\nauth    required                        pam_permit.so\nauth    optional                        pam_cap.so' > /etc/pam.d/common-auth

echo 'password        [success=1 default=ignore]      pam_unix.so obscure sha512\npassword        requisite                       pam_deny.so\npassword        required                        pam_permit.so' > /etc/pam.d/common-password

echo 'session [default=1]                     pam_permit.so\nsession requisite                       pam_deny.so\nsession required                        pam_permit.so\nsession optional                        pam_umask.so\nsession required        pam_unix.so' > /etc/pam.d/common-session

