#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

/bin/bash $INSTALL_PATH/install_kubelet.sh
/bin/bash $INSTALL_PATH/install_kube_proxy.sh
/bin/bash $INSTALL_PATH/install_flannel.sh
