#!/bin/bash
source $MOUNT_PATH/kubernetes/install_k8s/util

docker build \
  --build-arg REGISTRY=$(fullRegistryUrl) \
  -t sumit/kerberos:latest .
