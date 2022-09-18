#!/bin/bash

# This would create a service account and grant cluster-admin role to this
# serviceaccouunt. We can then use this service account get token for logging into
# kubernetes dashboard. We can get the token from get-sample-user-token.sh

kubectl create -f ${MOUNT_PATH}/kubernetes/install_k8s/dashboard/sample-user.yaml
