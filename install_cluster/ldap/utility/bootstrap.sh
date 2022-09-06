#!/bin/bash

[[ "TRACE" ]] && set -x

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster/ldap}
: ${CONFIG_FILE:=$MOUNT_PATH/kubernetes/install_cluster/config}

source $CONFIG_FILE


pushd ${WORKING_DIR}

source $CONFIG_FILE

: ${REALM:=$(echo $DOMAIN_NAME | tr 'a-z' 'A-Z')}
: ${DOMAIN_REALM:=$DOMAIN_NAME}
: ${KERB_MASTER_KEY:=masterkey}
: ${KERB_ADMIN_USER:=root}
: ${KERB_ADMIN_PASS:=$(</etc/secret/krb/password)}
: ${KDC_ADDRESS:=$KDC_ADDRESS}
: ${LDAP_HOST:=$LDAP_HOST}
: ${BASE_DN:=$DC}
: ${LDAP_PASSWORD:=$(</etc/secret/ldap/password)}
: ${DC_1:=$DC_1}
: ${DC_2:=$DC_2}

fix_nameserver() {
  cat >/etc/resolv.conf <<EOF
nameserver $NAMESERVER_IP
search $SEARCH_DOMAINS
EOF
}

fix_hostname() {
  if [ "$ENABLE_KUBERNETES" == 'true' ]; then
    cp /etc/hosts ~/tmp
    sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/" ~/tmp
    cp -f ~/tmp /etc/hosts
  fi
}


create_ldif() {

  echo "dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn="cn=admin,$BASE_DN" write" >/var/tmp/access.ldif


  ldapmodify -c -Y EXTERNAL -H ldapi:/// -f /var/tmp/access.ldif

  echo "dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: 256" >/var/tmp/loglevel.ldif
  ldapmodify -Y EXTERNAL -H ldapi:/// -f /var/tmp/loglevel.ldif

  echo "dn: ou=users,$BASE_DN
ou: users
objectClass: organizationalUnit
objectclass: top

dn: ou=groups,$BASE_DN
ou: groups
objectClass: organizationalUnit
objectclass: top" >/var/tmp/ou.ldif
  ldapadd -x -D "cn=admin,$BASE_DN" -w $LDAP_PASSWORD -H ldapi:/// -f /var/tmp/ou.ldif

  echo "dn: cn=admins,ou=groups,$BASE_DN
cn: admins
gidnumber: 500
objectclass: posixGroup
objectclass: top

dn: cn=users,ou=groups,$BASE_DN
cn: users
gidnumber: 501
objectclass: posixGroup
objectclass: top" >/var/tmp/groups.ldif
  ldapadd -x -D "cn=admin,$BASE_DN" -w $LDAP_PASSWORD -H ldapi:/// -f /var/tmp/groups.ldif

  utility/createGroup.sh hadoop $BASE_DN $LDAP_PASSWORD
  utility/createUser.sh smaji admins sumit $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh hduser hadoop hadoop $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh hive hadoop hive $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh hue hadoop hue $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh oozie hadoop oozie $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh yarn hadoop yarn $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh hdfs hadoop hdfs $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh mapred hadoop mapred $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh jobhist hadoop jobhist $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh spark hadoop spark $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh pig hadoop pig $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh hbase hadoop hbase $LDAP_PASSWORD $BASE_DN $LDAP_HOST
  utility/createUser.sh livy hadoop livy $LDAP_PASSWORD $BASE_DN $LDAP_HOST

  #Install kube tokens
  ldap-schema-manager -i config/kubernetesToken.schema

  echo "dn: cn=smaji,ou=users,$BASE_DN" >>config/users.txt
  utility/createTokenLdif.sh $LDAP_PASSWORD $BASE_DN

}


start_ldap() {
  service slapd start
  service nscd start
  create_ldif

  if [ "$ENABLE_SSL" == 'true' ]; then
    utility/setupssl.sh
  fi
}

main() {
  echo "My Ldap password iss $LDAP_PASSWORD"
  if [ ! -f /ldap_initialized ]; then
    fix_hostname
    start_ldap
    touch /ldap_initialized
  else
    start_ldap
  fi

  while true; do sleep 1000; done
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
