#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

mkdir $WORKING_DIR/ingress
pushd $WORKING_DIR/ingress

kubectl delete -f $WORKING_DIR/ingress/

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ingress.key 4096
openssl req -new -key ingress.key -out ingress.csr -subj "/CN=ingress/O=ingress:masters"
openssl x509 -req -in ingress.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ingress.crt -days 7200

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ${APP_HOST}.key 4096
openssl req -new -key ${APP_HOST}.key -out ${APP_HOST}.csr -subj "/CN=${APP_HOST}"
openssl x509 -req -in ${APP_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${APP_HOST}.crt -days 7200



cat nginx-ingress-controller-deployment.yaml | \
sed -i "s/\$LOAD_BALANCER_URL/$LOAD_BALANCER_URL/" | kubectl create -f
sed -i "s/\$APP_HOST/$APP_HOST/" nginx-ingress.yaml
sed -i "s/\$APP_HOST/$APP_HOST/" example/app-ingress.yaml

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
