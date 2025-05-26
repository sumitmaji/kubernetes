#!/bin/bash

source configuration
source $MOUNT_PATH/kubernetes/install_k8s/util
: ${PATH_TO_CHART:=chart}

LDAP_PASSWORD="$1"
KERBEROS_PASSWORD="$2"
KERBEROS_KDC_PASSWORD="$3"
KERBEROS_ADM_PASSWORD="$4"

if [[ -z "$LDAP_PASSWORD" || -z "$KERBEROS_PASSWORD" || -z "$KERBEROS_KDC_PASSWORD" || -z "$KERBEROS_ADM_PASSWORD" ]]; then
    echo "Usage: $0 <ldap_password> <kerberos_password> <kerberos_kdc_password> <kerberos_adm_password>"
    return 1
fi


./build.sh
./tag_push.sh

NS=ldap
helm uninstall $RELEASE_NAME -n $NS || true

SECRET_NAME=regcred
kubectl create namespace $NS >/dev/null 2>&1 || true
kubectl get secret $SECRET_NAME >/dev/null 2>&1 || kubectl create secret docker-registry \
    $SECRET_NAME --docker-server=$(fullRegistryUrl) --docker-username=$DOCKER_USER --docker-password=$DOCKER_PASSWORD -n $NS
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}' -n $NS
helm install $RELEASE_NAME $PATH_TO_CHART \
--set image.repository=$(fullRegistryUrl)/$REPO_NAME \
--namespace $NS \
--set ldap.password="$LDAP_PASSWORD" \
--set kerberos.password="$KERBEROS_PASSWORD" \
--set kerberos.kdcpassword="$KERBEROS_KDC_PASSWORD" \
--set kerberos.admpassword="$KERBEROS_ADM_PASSWORD"

echo "Waiting for services to be up!!!!"
kubectl --timeout=180s wait --for=condition=Ready pods --all --namespace "$NS"
echoSuccess "$REPO_NAME service is up!!"