#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/prometheus-graphana
kubectl delete -f setup
kubectl delete -f ../prometheus-graphana
kubectl delete -f ingress
kubectl delete secret grafanaingress-certificate -n monitoring

sleep 15

kubectl create ns monitoring

openssl genrsa -out ${GRAFANA_HOST}.key 4096
openssl req -new -key ${GRAFANA_HOST}.key -out ${GRAFANA_HOST}.csr -subj "/CN=${GRAFANA_HOST}" \
-addext "subjectAltName = DNS:${GRAFANA_HOST}"
openssl x509 -req -in ${GRAFANA_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${GRAFANA_HOST}.crt -days 7200

kubectl create secret tls grafanaingress-certificate --key ${GRAFANA_HOST}.key --cert ${GRAFANA_HOST}.crt -n monitoring

cat ingress/ingress.yaml | envsubst | kubectl create -f -
kubectl create -f setup
kubectl create -f ../prometheus-graphana
kubectl delete networkpolicy grafana -n monitoring

#https://computingforgeeks.com/setup-prometheus-and-grafana-on-kubernetes/
##Grapha details
#Username: admin
#password: admin
popd
