#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/prometheus-graphana
kubectl delete -f setup
kubectl delete -f ../prometheus-graphana

sleep 15

kubectl create -f setup
kubectl cretae -f ../prometheus-graphana
kubectl --namespace monitoring patch svc grafana -p '{"spec": {"type": "NodePort"}}'
kubectl --namespace monitoring patch svc alertmanager-main -p '{"spec": {"type": "NodePort"}}'
kubectl --namespace monitoring patch svc prometheus-k8s -p '{"spec": {"type": "NodePort"}}'

#https://computingforgeeks.com/setup-prometheus-and-grafana-on-kubernetes/
##Grapha details
#Username: admin
#password: admin
popd
