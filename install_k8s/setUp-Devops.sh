#!/bin/bash
[[ "TRACE" ]] && set -x

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

#Setup registry
pushd $WORKING_DIR/registry

chmod +x master.sh
./master.sh

popd

#Setup GitHook
pushd $WORKING_DIR/githook

chmod +x *.sh
./run_githook.sh

popd


#Setup DockerHook
pushd $WORKING_DIR/dockerhook

chmod +x *.sh
./run_dockerhook.sh

popd

#Setup RegistryHook
pushd $WORKING_DIR/reghook

chmod +x *.sh
./run_reghook.sh

popd