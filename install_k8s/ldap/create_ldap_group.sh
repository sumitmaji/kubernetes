#!/bin/bash


LDAP_ADMIN_PASSWORD=$password

# Add the LDAP group
ldapadd -x -H "$LDAP_HOSTNAME" -D "cn=admin,$BASE_DN" -w "$LDAP_ADMIN_PASSWORD" <<EOF
dn: cn=$GROUP_NAME,ou=groups,$BASE_DN
objectClass: top
objectClass: posixGroup
cn: $GROUP_NAME
gidNumber: $((RANDOM % 10000 + 1000))
EOF

if [[ $? -ne 0 ]]; then
echo "Failed to create LDAP group: $userGROUP_NAMEname"
exit 1
fi

echo "LDAP group '$GROUP_NAME' created successfully."