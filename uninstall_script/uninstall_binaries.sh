#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi


cp /opt/kubernetes/server/bin/{hyperkube,kubeadm,kube-apiserver,kubelet,kube-proxy,kubectl} /usr/local/bin
rm -rf  /usr/local/bin/{hyperkube,kubeadm,kube-apiserver,kubelet,kube-proxy,kubectl}
rm -rf  /var/lib/{kube-controller-manager,kubelet,kube-proxy,kube-scheduler}
rm -rf /etc/kubernetes/manifests
rm -rf /etc/{kubernetes}


