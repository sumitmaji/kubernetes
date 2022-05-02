#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

mkdir $WORKING_DIR/ingress
pushd $WORKING_DIR/ingress

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ingress.key 4096
openssl req -new -key ingress.key -out ingress.csr -subj "/CN=ingress/O=ingress:masters"
openssl x509 -req -in ingress.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ingress.crt -days 7200

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out master.cloud.com.key 4096
openssl req -new -key master.cloud.com.key -out master.cloud.com.csr -subj "/CN=master.cloud.com"
openssl x509 -req -in master.cloud.com.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out master.cloud.com.crt -days 7200



sed -i "s/\$LOAD_BALANCER_URL/$LOAD_BALANCER_URL/" nginx-ingress-controller-deployment.yaml

sed -i "s/\$APP_HOST/$INGRESS_HOST/" nginx-ingress.yaml
sed -i "s/\$APP_HOST/$INGRESS_HOST/" example/app-ingress.yaml

kubectl create namespace ingress
kubectl create -f default-backend-deployment.yaml -f default-backend-service.yaml -n=ingress
kubectl create secret tls ingress-certificate --key ingress.key --cert ingress.crt -n ingress
kubectl create secret tls ingress-certificate --key ingress.key --cert ingress.crt -n default
kubectl create -f ssl-dh-param.yaml
kubectl create -f nginx-ingress-controller-config-map.yaml -n=ingress
kubectl create -f nginx-ingress-controller-roles.yaml -n=ingress
kubectl create -f nginx-ingress-controller-deployment.yaml -n=ingress
kubectl create -f nginx-ingress.yaml -n=ingress
kubectl create -f nginx-ingress-controller-service.yaml -n=ingress

#Example app
kubectl create -f example/

popd
