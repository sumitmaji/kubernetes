#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster}

${WORKING_DIR}/ldap/install_ldap.sh

${WORKING_DIR}/kerberos/install_kerberos.sh

${WORKING_DIR}/kerberizedservices/kerberize-ssh.sh