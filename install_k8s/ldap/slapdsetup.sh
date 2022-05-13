#!/bin/bash

cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password sumit
slapd slapd/internal/adminpw password sumit
slapd slapd/password2 password sumit
slapd slapd/password1 password sumit
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string cloud.com
slapd shared/organization string Cloud Inc
slapd slapd/backend string HBD
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

dpkg-reconfigure -f noninteractive slapd
