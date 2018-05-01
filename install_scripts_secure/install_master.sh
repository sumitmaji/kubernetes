#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

/bin/bash $INSTALL_PATH/install_binaries.sh
/bin/bash $INSTALL_PATH/install_kubeconfig.sh
/bin/bash $INSTALL_PATH/install_etcd.sh
/bin/bash $INSTALL_PATH/install_kube_api_server.sh
/bin/bash $INSTALL_PATH/install_kube_controller_manager.sh
/bin/bash $INSTALL_PATH/install_kube_scheduler.sh

if [[ $INSTALL_KUBELET_ON_MASTER == 'true' ]]
then
  /bin/bash $INSTALL_PATH/install_nodes.sh
fi

ln -s /opt/kubernetes/server/bin/kubectl /usr/bin/kubectl

kubectl create -f $INSTALL_PATH/admin.yaml

if [[ $INSTALL_DASHBOARD == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_dashboard.sh
fi

if [[ $INSTALL_SKYDNS == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_skydns.sh
fi

if [[ $INSTALL_INGRESS == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_ingress.sh
fi




if [[ $INSTALL_HEAPSTER == 'true' ]]
then
 /bin/bash $INSTALL_PATH/install_cadvisor.sh
 /bin/bash $INSTALL_PATH/install_heapster.sh
fi

