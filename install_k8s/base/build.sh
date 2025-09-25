#!/bin/bash
source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util
docker build --build-arg REGISTRY=$(fullRegistryUrl)  -t $IMAGE_NAME .
docker tag $IMAGE_NAME $(fullRegistryUrl)/$REPO_NAME
docker push $(fullRegistryUrl)/$REPO_NAME
if [ $? -eq 0 ]
then
  exit 0
else
  exit 1
fi
