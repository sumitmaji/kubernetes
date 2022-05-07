#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

: ${COUNTRY:=IN}
: ${STATE:=UP}
: ${LOCALITY:=GN}
: ${ORGANIZATION:=CloudInc}
: ${ORGU:=IT}
: ${EMAIL:=cloudinc.gmail.com}
: ${COMMONNAME:=kube-client}

mkdir -p $CERTIFICATE_PATH/certs
pushd $CERTIFICATE_PATH/certs

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
`
IFS=','
counter=1
for server in $SERVER_DNS; do
echo "DNS.$counter = $server"
counter=$((counter+1))
done
counter=1
for server in $SERVER_IP; do
echo "IP.$counter = $server"
counter=$((counter+1))
done
`
EOF

#Create a private key
openssl genrsa -out server.key 2048

#Create CSR for the server
openssl req -new -key server.key \
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=$COMMONNAME/emailAddress=$EMAIL" \
-out server.csr -config server-openssl.cnf

#Create a self signed certificate
openssl x509 -req -in server.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out server.crt \
-days 10000 -extensions v3_req -extfile server-openssl.cnf

#Verify a Private Key Matches a Certificate
openssl x509 -noout -text -in server.crt


popd
