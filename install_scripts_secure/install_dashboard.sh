#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR

cp $INSTALL_PATH/../kube_service/dashboard/kubernetes-dashboard.yaml .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

if [ $ENABLE_KUBE_SSL == 'true' ]
then
  KUBECONFIG="$(echo '/var/lib/kubelet/kubeconfig' | sed 's/\//\\\//g')"
  sed -i "s/\$KUBECONFIG/$KUBECONFIG/" $WORKDIR/kubernetes-dashboard.yaml
else
  sed -i "/\$KUBECONFIG/ s/^/#/" $WORKDIR/kubernetes-dashboard.yaml
fi

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/kubernetes-dashboard.yaml

sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/kubernetes-dashboard.yaml

kubectl create -f $WORKDIR/kubernetes-dashboard.yaml

popd
