#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_cluster}

${WORKING_DIR}/ldapclient/install_ldapclient.sh

${WORKING_DIR}/kerberos/install_kerberosclient.sh

${WORKING_DIR}/kerberizedservices/kerberize-ssh.sh