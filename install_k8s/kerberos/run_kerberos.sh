#!/bin/bash

source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util

while [ $# -gt 0 ]; do
    case "$1" in
        -u | --user)
        shift
        DOCKER_USER=$1
        ;;
        -p | --password)
        shift
        DOCKER_PASSWORD=$1
        ;;
    esac
shift
done


: ${PATH_TO_CHART:=chart}

./build.sh
./tag_push.sh

helmInst $RELEASE_NAME $REPO_NAME default