#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/ingress

kubectl delete -f v1.2.yaml
kubectl delete secret appingress-certificate -n default
kubectl delete -f example/

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ingress.key 4096
openssl req -new -key ingress.key -out ingress.csr -subj "/CN=ingress/O=ingress:masters"
openssl x509 -req -in ingress.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ingress.crt -days 7200

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ${APP_HOST}.key 4096
openssl req -new -key ${APP_HOST}.key -out ${APP_HOST}.csr -subj "/CN=${APP_HOST}"
openssl x509 -req -in ${APP_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${APP_HOST}.crt -days 7200

kubectl create secret tls appingress-certificate --key ${APP_HOST}.key --cert ${APP_HOST}.crt -n default

cat v1.2.yaml | \
sed '393 a \t\t- --default-backend-service=$(POD_NAMESPACE)/default-backend' | \
kubectl apply -f -
kubectl apply -f default-backend-deployment.yaml -f default-backend-service.yaml

#Example app
cat example/app-ingress.yaml | \
envsubst | \
kubectl create -f -

kubectl create -f example/app-deployment.yaml
kubectl create -f example/app-service.yaml

popd
