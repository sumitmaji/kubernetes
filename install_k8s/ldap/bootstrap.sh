#!/bin/bash

[[ "TRACE" ]] && set -x

source /config

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
  cat>/etc/resolv.conf<<EOF
nameserver $NAMESERVER_IP
search $SEARCH_DOMAINS
EOF
}

fix_hostname() {
  sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
  if [ "$ENABLE_KUBERNETES" == 'true' ]
  then
   cp /etc/hosts ~/tmp
   sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/"  ~/tmp
   cp -f ~/tmp /etc/hosts
  fi
}

create_config() {
 mkdir -p /var/log/kerberos
 touch /var/log/kerberos/krb5libs.log
 touch /var/log/kerberos/krb5kdc.log
 touch /var/log/kerberos/kadmind.log

  cat>/etc/krb5.conf<<EOF
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

gzip -d /kerberos.schema.gz
echo "include /kerberos.schema" > /schema_convert.conf
mkdir ./ldif_result

slapcat -f ./schema_convert.conf -F ./ldif_result \
-s "cn=kerberos,cn=schema,cn=config"

cp ./ldif_result/cn\=config/cn\=schema/cn\=\{0\}kerberos.ldif \
./kerberos.ldif

#####Edit the file here
sed -i 's/cn={0}kerberos/cn=kerberos,cn=schema,cn=config/' ./kerberos.ldif
sed -i 's/{0}kerberos/kerberos/' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif
sed -i '$d' ./kerberos.ldif

ldapadd -QY EXTERNAL -H ldapi:/// -f ./kerberos.ldif

echo "dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn="cn=admin,$BASE_DN" write" > /var/tmp/access.ldif

sed -i "s/\$DOMAIN_NAME_UPPER/$REALM/" /access.ldif
sed -i "s/\$DC/$BASE_DN/" /access.ldif

ldapmodify -c -Y EXTERNAL -H ldapi:/// -f /var/tmp/access.ldif
ldapmodify -c -Y EXTERNAL -H ldapi:/// -f /access.ldif

  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/core.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/cosine.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/nis.ldif
  sudo ldapadd -c -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/inetorgperson.ldif
  echo "dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: 256" > /var/tmp/loglevel.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /var/tmp/loglevel.ldif

echo "dn: ou=users,$BASE_DN
ou: users
objectClass: organizationalUnit
objectclass: top

dn: ou=groups,$BASE_DN
ou: groups
objectClass: organizationalUnit
objectclass: top" > /var/tmp/ou.ldif
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
objectclass: top" > /var/tmp/groups.ldif
ldapadd -x -D "cn=admin,$BASE_DN" -w $LDAP_PASSWORD -H ldapi:/// -f /var/tmp/groups.ldif

/utility/ldap/createGroup.sh hadoop $BASE_DN $LDAP_PASSWORD "smaji,hduser,hive,hue,oozie,yarn,hdfs,mapred,jobhist,spark,pig,hbase,livy"
/utility/ldap/createGroup.sh administrator $BASE_DN $LDAP_PASSWORD "smaji"
/utility/ldap/createGroup.sh developers $BASE_DN $LDAP_PASSWORD "smaji"
/utility/ldap/createUser.sh smaji administrator sumit $LDAP_PASSWORD $BASE_DN $LDAP_HOST Sumit Maji smaji@outlook.com
/utility/ldap/createUser.sh hduser hadoop hadoop $LDAP_PASSWORD $BASE_DN $LDAP_HOST Hadoop Hadoop hadoop@outlook.com
/utility/ldap/createUser.sh hive hadoop hive $LDAP_PASSWORD $BASE_DN $LDAP_HOST Hive Hive hive@outlook.com
/utility/ldap/createUser.sh hue hadoop hue $LDAP_PASSWORD $BASE_DN $LDAP_HOST Hue Hue hue@outlook.com
/utility/ldap/createUser.sh oozie hadoop oozie $LDAP_PASSWORD $BASE_DN $LDAP_HOST Oozie Oozie oozie@outlook.com
/utility/ldap/createUser.sh yarn hadoop yarn $LDAP_PASSWORD $BASE_DN $LDAP_HOST Yarn Yarn yarn@outlook.com
/utility/ldap/createUser.sh hdfs hadoop hdfs $LDAP_PASSWORD $BASE_DN $LDAP_HOST Hdfs Hdfs hdfs@outlook.com
/utility/ldap/createUser.sh mapred hadoop mapred $LDAP_PASSWORD $BASE_DN $LDAP_HOST Mapred Mapred mapred@outlook.com
/utility/ldap/createUser.sh jobhist hadoop jobhist $LDAP_PASSWORD $BASE_DN $LDAP_HOST Jobhist Jobhist jobhist@outlook.com
/utility/ldap/createUser.sh spark hadoop spark $LDAP_PASSWORD $BASE_DN $LDAP_HOST Spark Spark spark@outlook.com
/utility/ldap/createUser.sh pig hadoop pig $LDAP_PASSWORD $BASE_DN $LDAP_HOST Pig Pig pig@outlook.com
/utility/ldap/createUser.sh hbase hadoop hbase $LDAP_PASSWORD $BASE_DN $LDAP_HOST Hbase Hbase hbase@outlook.com
/utility/ldap/createUser.sh livy hadoop livy $LDAP_PASSWORD $BASE_DN $LDAP_HOST Livy Livy livy@outlook.com

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
userPassword: sumit" > /tmp/krb5.ldif
ldapadd -x -D "cn=admin,$BASE_DN" -w $LDAP_PASSWORD -H ldapi:/// -f /tmp/krb5.ldif

#Install kube tokens
mkdir -p kubernetes_tokens
echo "include /kubernetesToken.schema" > kubernetes_tokens/schema_convert.conf
slapcat -f /kubernetes_tokens/schema_convert.conf -F /kubernetes_tokens -s "cn=kubernetestoken,cn=schema,cn=config"
cp /kubernetes_tokens/cn\=config/cn\=schema/cn\=\{0\}kubernetestoken.ldif \
/kubernetestoken.ldif

#####Edit the file here
sed -i 's/cn={0}kubernetestoken/cn=kubernetestoken,cn=schema,cn=config/' /kubernetestoken.ldif
sed -i 's/{0}kubernetestoken/kubernetestoken/' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif
sed -i '$d' /kubernetestoken.ldif


ldapadd -QY EXTERNAL -H ldapi:/// -f ./kubernetestoken.ldif

echo "dn: cn=smaji,ou=users,$BASE_DN" >> /users.txt
/utility/ldap/createTokenLdif.sh $LDAP_PASSWORD $BASE_DN

}

enableGss() {
 sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
 echo 'GSSAPIAuthentication yes
 GSSAPICleanupCredentials yes' >> /etc/ssh/sshd_config

}

start_ldap() {
   create_config
   service slapd start
   # /usr/sbin/slapd -h "ldap:/// ldapi:///" -g openldap -u openldap -F /etc/ldap/slapd.d -d Trace &>> /tmp/output.log 2>> /tmp/error.log
   service apache2 start
   service nscd start
   enableGss
   service ssh restart
   create_ldif

   if [ "$ENABLE_SSL" == 'true' ]
   then
     /utility/ldap/setupssl.sh
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
