#!/bin/bash

release=$2
CMD=$1

if [ $CMD == "bash" ]; then
  pod=$(kubectl get po -l app=$release 2>/dev/null | awk "/${release}/" | awk '{print $1}' | head -n 1)
  echo "Opening terminal on $pod"
  kubectl exec -it $pod -- /bin/bash
elif [ $CMD == "desc" ]; then
  pod=$(kubectl get po -l app=$release 2>/dev/null | awk  "/${release}/" | awk '{print $1}' | head -n 1)
  echo "Describing pod $pod"
  kubectl describe po $pod
elif [ $CMD == "logs" ]; then
    pod=$(kubectl get po -l app=$release 2>/dev/null | awk  "/${release}/" | awk '{print $1}' | head -n 1)
    echo "Viewing logs of pod $pod"
    kubectl logs $pod
elif [ $CMD == "status" ]; then
    helm status $release
fi
