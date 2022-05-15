#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

chmod +x *.sh

./install-k8s.sh

./install_ingress.sh

./install_dashboard.sh

./setUp-Devops.sh

#./install_prometheus-graphana.sh