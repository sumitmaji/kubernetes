#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/utils}

source $WORKING_DIR/config

pushd $WORKING_DIR

while [ $# -gt 0 ]; do
  case "$1" in
  -i | --ingress)
    shift
    ING=$1
    ;;
  -n | --namespace)
    shift
    NS=$1
    ;;
  -s | --secured)
    shift
    SECURED=$1
    ;;
  esac
  shift
done

if [ -z "$ING" ]; then
  echo "Please provide ingress name"
  exit 1
elif [ -z "$NS" ]; then
  echo "Please provide namespace"
  exit 1
fi

kubectl patch ingress $ING --patch-file patch-cert-letsencrypt.yaml -n $NS
kubectl patch ing $ING --type=json -p='[{"op": "replace", "path": "/spec/rules/0/host", "value":"kube.gokcloud.co.in"}]' -n $NS

if [ $SECURED == "true" ]; then
  kubectl patch ingress $ING --patch-file patch-ldap-secure.yaml -n $NS
fi

popd
