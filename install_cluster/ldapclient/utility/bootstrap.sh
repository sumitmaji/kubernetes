#!/bin/bash

[[ "TRACE" ]] && set -x

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster/ldapclient}

pushd ${WORKING_DIR}

: ${CONFIG_FILE:=$MOUNT_PATH/kubernetes/install_cluster/config}

source $CONFIG_FILE


: ${ENABLE_KRB:=$ENABLE_KRB}
: ${REALM:=$(echo $DOMAIN_NAME | tr 'a-z' 'A-Z')}
: ${DOMAIN_REALM:=$DOMAIN_NAME}
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
  #sed -i "/^hosts:/ s/ *files dns/ dns files/" /etc/nsswitch.conf
  if [ "$ENABLE_KUBERNETES" == 'true' ]; then
    cp /etc/hosts ~/tmp
    sed -i "s/\([0-9\.]*\)\([\t ]*\)\($(hostname -f)\)/\1 $(hostname -f).$DOMAIN_REALM \3/" ~/tmp
    cp -f ~/tmp /etc/hosts
  fi
}

initialize() {
    fix_hostname
    utility/enableLdapPam.sh
}

start_ldap() {
  service nscd restart
  #service ssh restart
}

main() {
  if [ ! -f /ldap_initialized ]; then
    initialize
    start_ldap
    touch /ldap_initialized
  else
    start_ldap
  fi
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
