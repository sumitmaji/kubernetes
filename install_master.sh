#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

#/bin/bash $INSTALL_PATH/../certificates/install_ca.sh
#/bin/bash $INSTALL_PATH/../certificates/install_master.sh
/bin/bash $INSTALL_PATH/install_etcd.sh
/bin/bash $INSTALL_PATH/install_kube_api_server.sh
/bin/bash $INSTALL_PATH/install_kube_controller_manager.sh
/bin/bash $INSTALL_PATH/install_kube_scheduler.sh

if [[ $INSTALL_KUBELET_ON_MASTER == 'true' ]]
then
  /bin/bash $INSTALL_PATH/../install_nodes.sh
fi

ln -s /opt/kubernetes/server/bin/kubectl /usr/bin/kubectl

if [[ $INSTALL_DASHBOARD == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_dashboard.sh
fi

if [[ $INSTALL_SKYDNS == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_skydns.sh
fi


if [[ $INSTALL_HEAPSTER == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_cadvisor.sh
 /bin/bash $INSTALL_PATH/install_heapster.sh
fi

