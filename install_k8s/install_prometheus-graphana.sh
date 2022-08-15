#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/prometheus-graphana

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update

helm install monitoring \
  prometheus-community/kube-prometheus-stack \
  --values values.yaml \
  --version 16.10.0 \
  --namespace monitoring \
  --create-namespace

kubectl -n kube-system get cm kube-proxy-config -o yaml | sed \
  's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249' \
  kubectl apply -f -

kubectl -n kube-system patch ds kube-proxy -p \
  '{"spec":{"template":{"metadata":{"labels":{"updateTime":"`date + '%s'`"}}}}}'

helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm install postgres \
  bitnami/postgresql \
  --values postgres-values.yaml \
  --version 10.5.0 \
  --namespace db \
  --create-namespace


#https://computingforgeeks.com/setup-prometheus-and-grafana-on-kubernetes/
##Grapha details
#Username: admin
#password: admin
popd
