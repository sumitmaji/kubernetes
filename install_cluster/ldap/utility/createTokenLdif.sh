#!/bin/bash

[[ "TRACE" ]] && set -x

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster/ldap}
: ${LDAP_PASSWORD:=$1}
: ${BASE_DN:=$2}

mkdir -p /var/tmp/kubernetes
pushd /var/tmp/kubernetes
while read -r user; do
fname=$(echo $user | grep -E -o "cn=[a-z0-9]+" | cut -d"=" -f2)
token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
cat << EOF > "/var/tmp/kubernetes/${fname}.ldif"
$user
changetype: modify
add: objectClass
objectclass: kubernetesAuthenticationObject
-
add: kubernetesToken
kubernetesToken: $token
EOF
done < ${WORKING_DIR}/config/users.txt

for i in *.ldif; do ldapmodify -x -D "cn=admin,$BASE_DN" -w ${LDAP_PASSWORD} -H ldapi:/// -f $i; done
popd
exit 0
