#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR

cp $INSTALL_PATH/../kube_service/dashboard/v1.6.3.yaml .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

if [ $ENABLE_KUBE_SSL == 'true' ]
then
  KUBECONFIG="$(echo '/var/lib/kubelet/kubeconfig' | sed 's/\//\\\//g')"
  sed -i "s/\$KUBECONFIG/$KUBECONFIG/" $WORKDIR/v1.6.3.yaml
else
  sed -i "/\$KUBECONFIG/ s/^/#/" $WORKDIR/v1.6.3.yaml
fi

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/v1.6.3.yaml

sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/v1.6.3.yaml

kubectl create -f $WORKDIR/v1.6.3.yaml

popd
