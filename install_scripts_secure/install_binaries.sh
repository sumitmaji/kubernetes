#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

mkdir -p $WORKDIR
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/
if [ ! -d /opt/kubernetes ]
then
 wget https://dl.k8s.io/v1.10.0/kubernetes-server-linux-amd64.tar.gz
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
 if [ $? -ne 0 ]
 then
   exit 1
 fi
fi

cp /opt/kubernetes/server/bin/{hyperkube,kubeadm,kube-apiserver,kubelet,kube-proxy,kubectl} /usr/local/bin
mkdir -p /var/lib/{kube-controller-manager,kubelet,kube-proxy,kube-scheduler}
mkdir -p /etc/{kubernetes,sysconfig}
mkdir -p /etc/kubernetes/manifests

popd
