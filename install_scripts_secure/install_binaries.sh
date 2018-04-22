#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/
if [ ! -d /opt/kubernetes ]
then
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

cp /opt/kubernetes/server/bin/{hyperkube,kubeadm,kube-apiserver,kubelet,kube-proxy,kubectl} /usr/local/bin
mkdir -p /var/lib/{kube-controller-manager,kubelet,kube-proxy,kube-scheduler}
mkdir -p /etc/{kubernetes,sysconfig}
mkdir -p /etc/kubernetes/manifests

popd
