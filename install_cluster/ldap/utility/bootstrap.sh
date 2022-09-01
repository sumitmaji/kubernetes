#!/bin/bash

[[ "TRACE" ]] && set -x

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster/ldap}

pushd ${WORKING_DIR}

source config/config

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
  sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
  if [ "$ENABLE_KUBERNETES" == 'true' ]; then
    cp /etc/hosts ~/tmp
    sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/" ~/tmp
    cp -f ~/tmp /etc/hosts
  fi
}

create_config() {
  mkdir -p /var/log/kerberos
  touch /var/log/kerberos/krb5libs.log
  touch /var/log/kerberos/krb5kdc.log
  touch /var/log/kerberos/kadmind.log

  cat >/etc/krb5.conf <<EOF
[logging]
 default = FILE:/var/log/kerberos/krb5libs.log
 kdc = FILE:/var/log/kerberos/krb5kdc.log
 admin_server = FILE:/var/log/kerberos/kadmind.log

[libdefaults]
 default_realm = $REALM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 proxiable = true

[realms]
 $REALM = {
  kdc = $KDC_ADDRESS
  admin_server = $KDC_ADDRESS
  database_module = openldap_ldapconf
 }

[domain_realm]
 .$DOMAIN_REALM = $REALM
 $DOMAIN_REALM = $REALM

[dbdefaults]
        ldap_kerberos_container_dn = cn=krbContainer,$BASE_DN

[dbmodules]
        openldap_ldapconf = {
                db_library = kldap
                ldap_kdc_dn = cn=kdc-srv,ou=krb5,$BASE_DN
                ldap_kadmind_dn = cn=adm-srv,ou=krb5,$BASE_DN
                ldap_service_password_file = /etc/krb5kdc/service.keyfile
                ldap_conns_per_server = 5
                ldap_servers = $LDAP_HOST
        }
EOF
}

create_ldif() {

  gzip -d config/kerberos.schema.gz
  echo "include config/kerberos.schema" >${WORKING_DIR}/config/schema_convert.conf
  mkdir config/ldif_result

  slapcat -f config/schema_convert.conf -F config/ldif_result \
    -s "cn=kerberos,cn=schema,cn=config"

  cp config/ldif_result/cn\=config/cn\=schema/cn\=\{0\}kerberos.ldif \
    config/kerberos.ldif

  #####Edit the file here
  sed -i 's/cn={0}kerberos/cn=kerberos,cn=schema,cn=config/' config/kerberos.ldif
  sed -i 's/{0}kerberos/kerberos/' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif
  sed -i '$d' config/kerberos.ldif

  ldapadd -QY EXTERNAL -H ldapi:/// -f config/kerberos.ldif

  echo "dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn="cn=admin,$BASE_DN" write" >/var/tmp/access.ldif

  sed -i "s/\$DOMAIN_NAME_UPPER/$REALM/" config/access.ldif
  sed -i "s/\$DC/$BASE_DN/" config/access.ldif

  ldapmodify -c -Y EXTERNAL -H ldapi:/// -f /var/tmp/access.ldif
  ldapmodify -c -Y EXTERNAL -H ldapi:/// -f config/access.ldif

  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/core.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/cosine.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/nis.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/inetorgperson.ldif
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
  utility/createUser.sh smaji hadoop sumit $LDAP_PASSWORD $BASE_DN $LDAP_HOST
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

  echo "dn: ou=krb5,$BASE_DN
ou: krb5
objectClass: organizationalUnit

dn: cn=kdc-srv,ou=krb5,$BASE_DN
cn: kdc-srv
objectClass: simpleSecurityObject
objectClass: organizationalRole
description: Default bind DN for the Kerberos KDC server
userPassword: sumit

dn: cn=adm-srv,ou=krb5,$BASE_DN
cn: adm-srv
objectClass: simpleSecurityObject
objectClass: organizationalRole
description: Default bind DN for the Kerberos Administration server
userPassword: sumit" >/tmp/krb5.ldif
  ldapadd -x -D "cn=admin,$BASE_DN" -w $LDAP_PASSWORD -H ldapi:/// -f /tmp/krb5.ldif

  #Install kube tokens
  mkdir -p config/kubernetes_tokens
  echo "include config/kubernetesToken.schema" >config/kubernetes_tokens/schema_convert.conf
  slapcat -f config/kubernetes_tokens/schema_convert.conf -F config//kubernetes_tokens -s "cn=kubernetestoken,cn=schema,cn=config"
  cp config/kubernetes_tokens/cn\=config/cn\=schema/cn\=\{0\}kubernetestoken.ldif \
    config/kubernetestoken.ldif

  #####Edit the file here
  sed -i 's/cn={0}kubernetestoken/cn=kubernetestoken,cn=schema,cn=config/' config/kubernetestoken.ldif
  sed -i 's/{0}kubernetestoken/kubernetestoken/' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif
  sed -i '$d' config/kubernetestoken.ldif

  ldapadd -QY EXTERNAL -H ldapi:/// -f config/kubernetestoken.ldif

  echo "dn: cn=smaji,ou=users,$BASE_DN" >>config/users.txt
  utility/createTokenLdif.sh $LDAP_PASSWORD $BASE_DN

}

enableGss() {
  sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
  echo 'GSSAPIAuthentication yes
 GSSAPICleanupCredentials yes' >>/etc/ssh/sshd_config

}

start_ldap() {
  create_config
  service slapd start
  service apache2 start
  service nscd start
  enableGss
  service ssh restart
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
