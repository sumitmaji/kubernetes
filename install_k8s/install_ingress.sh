#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

pushd $WORKING_DIR/ingress

output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -o json | jq '.items | length'`

if [ "$ouput" == "1" ]; then
  kubectl delete -f v1.2.yaml -f default-backend-deployment.yaml -f default-backend-service.yaml
  kubectl delete secret appingress-certificate -n ingress-nginx
  kubectl delete secret appingress-certificate -n default
  kubectl delete -f example/
  output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -o json | jq '.items | length'`
  while [ "$output" != "0" ]; do
      echo "Ingress controller service is not down, will check again after 5seconds"
      sleep 5
      output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -o json | jq '.items | length'`
  done

  output=`kubectl get po -n ingress-nginx -l app=default-backend -o json | jq '.items | length'`
  while [ "$output" != "0" ]; do
      echo "backend service is not down, will check again after 5seconds"
      sleep 5
      output=`kubectl get po -n ingress-nginx -l app=default-backend -o json | jq '.items | length'`
  done
fi


#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ingress.key 4096
openssl req -new -key ingress.key -out ingress.csr -subj "/CN=ingress/O=ingress:masters"
openssl x509 -req -in ingress.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ingress.crt -days 7200

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out ${APP_HOST}.key 4096
openssl req -new -key ${APP_HOST}.key -out ${APP_HOST}.csr -subj "/CN=${APP_HOST}" \
-addext "subjectAltName = DNS:${APP_HOST}"
openssl x509 -req -in ${APP_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${APP_HOST}.crt -days 7200

cat v1.2.yaml | \
sed '393 a \            - --default-backend-service=$(POD_NAMESPACE)/default-backend' | \
kubectl apply -f -
kubectl apply -f default-backend-deployment.yaml -f default-backend-service.yaml
kubectl create secret tls appingress-certificate --key ${APP_HOST}.key --cert ${APP_HOST}.crt -n ingress-nginx
kubectl create secret tls appingress-certificate --key ${APP_HOST}.key --cert ${APP_HOST}.crt -n default

output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -ojsonpath='{.items[0].status.containerStatuses[0].ready}'`

while [ "$output" != "true" ]; do
    echo "Ingress controller service is not up, will check again after 5seconds"
    sleep 5
    output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -ojsonpath='{.items[0].status.containerStatuses[0].ready}'`
done


#Example app
cat example/app-ingress.yaml | \
envsubst | \
kubectl create -f -

kubectl create -f example/app-deployment.yaml
kubectl create -f example/app-service.yaml
kubectl create -f example/echo-deployment.yaml
kubectl create -f example/echo-service.yaml
kubectl create -f example/echo-ingress.yaml
popd
