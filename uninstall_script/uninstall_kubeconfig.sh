#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi


for user in kubelet kube-proxy kube-controller-manager kube-scheduler
do
 rm -rf /var/lib/${user}/kubeconfig
 rm -rf /var/lib/${user}
done

rm -rf  $CERTIFICATE_MOUNT_PATH/known_tokens.csv
rm -rf $CERTIFICATE_MOUNT_PATH/basic_auth.csv
