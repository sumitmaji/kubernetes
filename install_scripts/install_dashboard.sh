#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR

cp $INSTALL_PATH/../kube_service/dashboard/kubernetes-dashboard.yaml .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/kubernetes-dashboard.yaml

sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/kubernetes-dashboard.yaml

kubectl create -f $WORKDIR/kubernetes-dashboard.yaml

popd
