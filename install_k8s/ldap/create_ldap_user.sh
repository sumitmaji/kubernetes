#!/bin/bash
  
  username="$USERNAME"
  user_password="$USER_PASSWORD"
  email="$EMAIL"
  first_name="$FIRST_NAME"
  last_name="$LAST_NAME"
  group_name="$GROUP_NAME"

  echo "Creating LDAP user: $username"

  echo "Environment variables:"
  echo "USERNAME: $username"
  echo "USER_PASSWORD: $user_password"
  echo "EMAIL: $email"
  echo "FIRST_NAME: $first_name"
  echo "LAST_NAME: $last_name"
  echo "GROUP_NAME: $group_name"
  echo "BASE_DN: $BASE_DN"
  echo "LDAP_HOSTNAME: $LDAP_HOSTNAME"
  echo "Admin Password: $password"
  gid=$(ldapsearch -x -b "ou=groups,$BASE_DN" "cn=$group_name" -D "cn=admin,$BASE_DN" -w ${password} -H ${LDAP_HOSTNAME} -LLL gidNumber | grep 'gidNumber' | grep -Eo '[0-9]+')
  
  echo "Found gidNumber for group '$group_name': $gid"
  # Create the user using ldapadd
  ldapadd -x -D "cn=admin,${BASE_DN}" -w "${password}" <<EOF
dn: cn=${username},ou=users,${BASE_DN}
gidnumber: $gid
givenname: $first_name
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
homedirectory: /home/users/$username
loginshell: /bin/bash
uid: ${username}
cn: ${username}
sn: ${last_name}
userpassword: ${user_password}
mail: ${email}
uidnumber: $((RANDOM % 10000 + 1000))
EOF

  if [[ $? -ne 0 ]]; then
    echo "Failed to create LDAP user: $username"
    exit 1
  fi

  echo "LDAP user $username created successfully!"