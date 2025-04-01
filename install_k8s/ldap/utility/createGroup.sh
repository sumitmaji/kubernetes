#!/bin/bash

[[ "TRACE" ]] && set -x
uid=$(< /var/userid)
gid=$(< /var/groupid)

: ${LDAP_PASSWORD:=$3}
: ${BASE_DN:=$2}
: ${MEMBERS:=$4}

# Convert comma-separated members into multiple memberUid attributes
member_uids=""
IFS=',' read -ra users <<< "$MEMBERS"
for user in "${users[@]}"; do
  member_uids+="memberUid: $user"$'\n'
done

echo "dn: cn=$1,ou=groups,$BASE_DN
cn: $1
gidnumber: $gid
objectclass: posixGroup
objectclass: top
$member_uids
" > /var/tmp/groups.ldif

ldapadd -x -D "cn=admin,$BASE_DN" -w ${LDAP_PASSWORD} -H ldapi:/// -f /var/tmp/groups.ldif
if [ $? == 0 ]
then
  echo $(($gid + 1)) > /var/groupid
else
 exit 1
fi
exit 0


