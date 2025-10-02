#!/bin/bash

[[ "TRACE" ]] && set -x

source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util
docker build -t $IMAGE_NAME .

 if [ $? -eq 0 ]
 then
   exit 0
else
  exit 1
fi
