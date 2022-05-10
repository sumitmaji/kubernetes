#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

./install-k8s.sh

./install_ingress.sh

./install_dashboard.sh

./install_prometheus-graphana.sh