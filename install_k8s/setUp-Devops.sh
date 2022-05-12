#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

#Setup registry
pushd $WORKING_DIR/registry

./master.sh

popd

#Setup GitHook

#Setup DockerHook
pushd $WORKING_DIR/dockerhook

./run_dockerhook.sh

popd

#Setup RegistryHook
pushd $WORKING_DIR/reghook

./run_reghook.sh

popd