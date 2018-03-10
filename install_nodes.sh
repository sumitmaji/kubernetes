#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}

source $INSTALL_PATH/../config

/bin/bash $INSTALL_PATH/install_kubelet.sh
/bin/bash $INSTALL_PATH/install_kube_proxy.sh
/bin/bash $INSTALL_PATH/install_flannel.sh
