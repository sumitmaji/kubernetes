#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

#Setup registry
pushd $WORKING_DIR/registry

./master.sh

popd
#Setup GitHook



#Setup DockerHook

#Setup RegistryHook