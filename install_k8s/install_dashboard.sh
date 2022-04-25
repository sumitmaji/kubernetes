#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

envsubst < $WORKING_DIR/dashboard/v1.6.3.yaml > $WORKING_DIR/dashboard/dashboard.yaml

kubectl create -f $WORKING_DIR/dashboard/dashboard.yaml