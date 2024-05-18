#!/bin/bash

[[ "TRACE" ]] && set -x

source config/config
source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util
docker build --build-arg LDAP_DOMAIN=$DOMAIN_NAME \
 --build-arg REGISTRY=$(fullRegistryUrl) \
 --build-arg LDAP_HOSTNAME=$LDAP_HOSTNAME --build-arg BASE_DN=$DC  \
 --build-arg LDAP_PASSWORD=sumit -t $IMAGE_NAME .

 if [ $? -eq 0 ]
 then
   exit 0
else
  exit 1
fi
