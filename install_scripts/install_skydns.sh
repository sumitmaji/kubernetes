#!/bin/bash
[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}

source $INSTALL_PATH/../config

kubectl create -f $INSTALL_PATH/../kube_service/skydns/skydns-rc.yaml
kubectl create -f $INSTALL_PATH/../kube_service/skydns/skydns-svc.yaml

systemctl daemon-reload
systemctl restart kubelet
service docker restart


