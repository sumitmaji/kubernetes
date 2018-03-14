#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

/bin/bash $INSTALL_PATH/install_etcd.sh
/bin/bash $INSTALL_PATH/install_kube_apiserver.sh
/bin/bash $INSTALL_PATH/install_kube_controller_manager.sh
/bin/bash $INSTALL_PATH/install_kube_scheduler.sh

ln -s /opt/kubernetes/server/bin/kubectl /usr/bin/kubectl
