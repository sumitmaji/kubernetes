#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/cadvisor
kubectl apply -f daemon.yaml
popd
