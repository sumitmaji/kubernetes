#!/bin/bash
[[ "TRACE" ]] && set -x

: ${LDAP_PASSWORD:=$4}
: ${BASE_DN:=$5}
: ${LDAP_HOSTNAME:=$6}

uid=$(< /var/userid)
gid=`ldapsearch -x -b "ou=groups,$BASE_DN" "cn=$2" -D "cn=admin,$BASE_DN" -w ${LDAP_PASSWORD} -H ${LDAP_HOSTNAME} -LLL gidNumber | grep 'gidNumber' | grep -Eo '[0-9]+'`

echo "dn: cn=$1,ou=users,$BASE_DN
cn: $1
gidnumber: $gid
givenname: Sumit
homedirectory: /home/users/$1
loginshell: /bin/bash
objectclass: inetOrgPerson
objectclass: posixAccount
objectclass: top
sn: $1
uid: $1
uidnumber: $uid
userpassword: $3" > /var/tmp/user.ldif
ldapadd -x -D "cn=admin,$BASE_DN" -w ${LDAP_PASSWORD} -H ldapi:/// -f /var/tmp/user.ldif

if [ $? == 0 ]
then
  echo $(($uid + 1)) > /var/userid
else
 exit 1
fi
exit 0

