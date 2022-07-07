#!/bin/bash

[[ "TRACE" ]] && set -x

# e.g. ./execute.sh -h 192.168.0.23 -e LOCAL
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --host)
        shift
        APP_HOST=$1
        ;;
        -n | --namespace)
        shift
        NAMESPACE=$1
        ;;
    esac
shift
done

if [ -z "$APP_HOST" ]; then
    echo "Please provide host name"
    exit 1
elif [ -z "$NAMESPACE" ]; then
    echo "Please provide namespace"
    exit 1
fi

CERT_NAME=${APP_HOST//./-}

#below would create user named ingress with group assigned as ingress:masters
openssl genrsa -out "${APP_HOST}".key 4096
openssl req -new -key "${APP_HOST}".key -out "${APP_HOST}".csr -subj "/CN=${APP_HOST}" \
-addext "subjectAltName = DNS:${APP_HOST}"
openssl x509 -req -in "${APP_HOST}".csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out "${APP_HOST}".crt -days 7200

kubectl create secret tls "${CERT_NAME}"-tls --key "${APP_HOST}".key --cert "${APP_HOST}".crt -n "${NAMESPACE}"

rm "${APP_HOST}".key "${APP_HOST}".crt "${APP_HOST}".csr