#!/bin/bash
 
 STATUS=`grep "ldap compat" /etc/nsswitch.conf`
 if [ -z "$STATUS" ]
 then
 `sed -i 's/compat/ldap compat/' /etc/nsswitch.conf`
 fi
 
 
 STATUS=`grep "umask=0022 skel=/etc/skel" /etc/pam.d/common-session`
 
 if [ -z "$STATUS" ]
 then
 `sed -i '/pam_ldap.so/ s/^/session required        pam_mkhomedir.so umask=0022 skel=\/etc\/skel\n/' /etc/pam.d/common-session`
 #`sed -i '$a\session optional        pam_mkhomedir.so        skel=/etc/skel umask=0022' /etc/pam.d/common-session`
 fi
 
 service nscd restart
 
 STATUS=`grep "%admins ALL=(ALL) ALL" /etc/sudoers`
 if [ -z "$STATUS" ]
 then
 `sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers`
 fi
