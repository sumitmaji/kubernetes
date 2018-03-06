#!/bin/bash
[[ "TRACE" ]] && set -x

HAPROXY="$(ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')"

: ${COUNTRY:=IN}
: ${STATE:=UP}
: ${LOCALITY:=GN}
: ${ORGANIZATION:=CloudInc}
: ${ORGU:=IT}
: ${EMAIL:=cloudinc.gmail.com}
: ${COMMONNAME:=kube-system}

mkdir -p ./certs
pushd certs

openssl req -new -x509 -nodes -keyout ca.key -out ca.crt -days 3650 -passin pass:sumit \
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=$COMMONNAME/emailAddress=$EMAIL"

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
