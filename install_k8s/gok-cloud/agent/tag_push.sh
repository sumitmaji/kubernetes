#!/bin/bash

source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util

docker tag $IMAGE_NAME $(fullRegistryUrl)/$REPO_NAME
docker push $(fullRegistryUrl)/$REPO_NAME