#!/bin/bash

source configuration

source $MOUNT_PATH/kubernetes/install_k8s/util

: ${PATH_TO_CHART:=chart}

while [ $# -gt 0 ]; do
    case "$1" in
        -u | --user)
        shift
        DOCKER_USER=$1
        ;;
        -p | --password)
        shift
        DOCKER_PASSWORD=$1
        ;;
    esac
shift
done

: ${PATH_TO_CHART:=chart}

#if [[ "$(docker images -q $REPO_NAME 2> /dev/null)" == "" ]]; then
./build.sh
./tag_push.sh
#fi

SECRET_NAME=regcred
kubectl create ns $RELEASE_NAME
kubectl get secret $SECRET_NAME >/dev/null 2>&1 || kubectl create secret docker-registry \
    $SECRET_NAME --docker-server=$(fullRegistryUrl) --docker-username=$DOCKER_USER --docker-password=$DOCKER_PASSWORD -n $RELEASE_NAME
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}'   -n $RELEASE_NAME
helm uninstall $RELEASE_NAME -n $RELEASE_NAME
helm install $RELEASE_NAME $PATH_TO_CHART \
  --set image.repository=$(fullRegistryUrl)/ldap \
  --namespace $RELEASE_NAME

echo "Waiting for services to be up!!!!"
kubectl --timeout=180s wait --for=condition=Ready pods --all --namespace "$RELEASE_NAME"
echoSuccess "ldap service is up!!"