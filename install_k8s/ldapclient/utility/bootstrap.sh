#!/bin/bash

[[ "TRACE" ]] && set -x

source /config

: ${ENABLE_KRB:=$ENABLE_KRB}
: ${REALM:=$(echo $DOMAIN_NAME | tr 'a-z' 'A-Z')}
: ${DOMAIN_REALM:=$DOMAIN_NAME}
: ${KERB_MASTER_KEY:=masterkey}
: ${KERB_ADMIN_USER:=root}
: ${KERB_ADMIN_PASS:=$KERB_ADMIN_PASS}
: ${KDC_ADDRESS:=$KDC_ADDRESS}
: ${LDAP_HOST:=$LDAP_HOST}
: ${BASE_DN:=$DC}
: ${LDAP_PASSWORD:=$LDAP_PASSWORD}
: ${DC_1:=$DC_1}
: ${DC_2:=$DC_2}
: ${ENABLE_KUBERNETES:=$ENABLE_KUBERNETES}



fix_nameserver() {
  cat>/etc/resolv.conf<<EOF
nameserver $NAMESERVER_IP
search $SEARCH_DOMAINS
EOF
}

fix_hostname() {
  #sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
  if [ "$ENABLE_KUBERNETES" == 'true' ]
  then
   cp /etc/hosts ~/tmp
   sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/"  ~/tmp
   cp -f ~/tmp /etc/hosts
  fi
}

enable_krb() {
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

enableGss() {
 sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
 echo 'GSSAPIAuthentication yes
 GSSAPICleanupCredentials yes' >> /etc/ssh/sshd_config

echo '/utility/setupUser.sh' >> /etc/bash.bashrc
}
initializePrincipal() {
 #Kerberize ssh
 kadmin -p root/admin -w admin -q "addprinc -randkey host/$(hostname -f)@$REALM"
 kadmin -p root/admin -w admin -q "xst -k /etc/krb5.keytab host/$(hostname -f)@$REALM"

}

initialize() {
  if [ "$ENABLE_KRB" == 'true' ]
  then
     fix_hostname
     /utility/kerberos/enableKerbPam.sh
     enable_krb
     enableGss
     initializePrincipal
  else
    fix_hostname
    /utility/ldap/enableLdapPam.sh
  fi

}

start_ldap() {
   service nscd start
   service ssh restart
}

main() {
  if [ ! -f /ldap_initialized ]; then
    initialize
    start_ldap
    touch /ldap_initialized
  else
    start_ldap
  fi

  if [[ $1 == "-d" ]]; then
    while true; do sleep 1000; done
  else
    exit 0
  fi
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
