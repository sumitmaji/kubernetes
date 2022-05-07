#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/prometheus-graphana
kubectl delete -f setup
kubectl delete -f ../prometheus-graphana
kubectl delete -f ingress

sleep 15

kubectl create ns monitoring

openssl genrsa -out ${GRAPHANA_HOST}.key 4096
openssl req -new -key ${GRAPHANA_HOST}.key -out ${GRAPHANA_HOST}.csr -subj "/CN=${GRAPHANA_HOST}" \
-addext "subjectAltName = DNS:${GRAPHANA_HOST}"
openssl x509 -req -in ${GRAPHANA_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${GRAPHANA_HOST}.crt -days 7200

kubectl create secret tls graphanaingress-certificate --key ${GRAPHANA_HOST}.key --cert ${GRAPHANA_HOST}.crt -n monitoring

cat ingress/ingress.yaml | envsubst | kubectl create -f -
kubectl create -f setup
kubectl create -f ../prometheus-graphana
kubectl delete networkpolicy graphana -n monitoring

#https://computingforgeeks.com/setup-prometheus-and-grafana-on-kubernetes/
##Grapha details
#Username: admin
#password: admin
popd
