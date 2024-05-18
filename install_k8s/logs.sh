#!/bin/bash
APP_NAME=$1
POD_NAME="$(kubectl get po -l=k8s-app=$APP_NAME --all-namespaces -o jsonpath="{.items[0].metadata.name}")"
NAMESPACE="$(kubectl get po -l=k8s-app=$APP_NAME --all-namespaces -o jsonpath="{.items[0].metadata.namespace}")"
kubectl logs $POD_NAME -n $NAMESPACE "$@"