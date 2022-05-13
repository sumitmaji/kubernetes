#!/bin/bash

[[ "TRACE" ]] && set -x


cp /certificates/node.key \
/certificates/node.crt \
/certificates/ca.crt \
/etc/ldap/sasl2/

chown openldap. /etc/ldap/sasl2/node.key \
/etc/ldap/sasl2/node.crt \
/etc/ldap/sasl2/ca.crt

cat <<EOF | sudo tee mod_ssl.ldif
dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/sasl2/ca.crt
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/sasl2/node.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/sasl2/node.key
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f mod_ssl.ldif

sed -i 's/SLAPD_SERVICES=/#SLAPD_SERVICES=/g' /etc/default/slapd

echo "SLAPD_SERVICES=\"ldap:/// ldapi:/// ldaps:///\"" >> /etc/default/slapd


###Client Setup#######
echo "TLS_REQCERT allow" >> /etc/ldap/ldap.conf
sed -i 's/#ssl start_tls/ssl start_tls/g' /etc/ldap.conf
sed -i 's/TLS_CACERT/#TLS_CACERT/g' /etc/ldap/ldap.conf
echo "TLS_CACERT /etc/ldap/sasl2/ca.crt" >> /etc/ldap/ldap.conf
#####################

service slapd stop
kill -9 $(ps -ef | grep openldap | grep '/usr/sbin/slapd' | awk '{print $2}')

sleep 10

service slapd start
