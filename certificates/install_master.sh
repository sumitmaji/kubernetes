#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

: ${COUNTRY:=IN}
: ${STATE:=UP}
: ${LOCALITY:=GN}
: ${ORGANIZATION:=CloudInc}
: ${ORGU:=IT}
: ${EMAIL:=cloudinc.gmail.com}
: ${COMMONNAME:=kube-system}

mkdir -p $CERTIFICATE/certs
pushd $CERTIFICATE/certs

cat <<EOF | sudo tee server-openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 127.0.0.1
IP.2 = $HAPROXY
EOF

openssl genrsa -out server.key 2048

openssl req -new -key server.key \
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=$HAPROXY/emailAddress=$EMAIL" \
-out server.csr -config server-openssl.cnf

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt \
-days 10000 -extensions v3_req -extfile server-openssl.cnf

openssl x509 -noout -text -in server.crt

popd
