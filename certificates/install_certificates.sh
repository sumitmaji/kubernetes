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
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=kube-apiserver/emailAddress=$EMAIL" \
-out server.csr -config server-openssl.cnf

#Create a self signed certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt \
-days 10000 -extensions v3_req -extfile server-openssl.cnf

#Verify a Private Key Matches a Certificate
openssl x509 -noout -text -in server.crt


#Install certificates for the services, master host and admin user
for user in admin kube-proxy kubelet kube-controller-manager kube-scheduler master.cloud.com
do
    openssl genrsa -out ${user}.key 2048
    openssl req -new -key ${user}.key -out ${user}.csr -subj "/CN=${user}"
    openssl x509 -req -in ${user}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${user}.crt -days 7200
done

#Install worker nodes
IFS=','
for worker in $WORKERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 echo "The node $node"
 $INSTALL_PATH/../certificates/install_node.sh -i $ip -h $node 
 IFS=$oifs 
done
unset IFS

echo "admin,admin,admin" > basic_auth.csv

#Install peer certificates for etcd server
IFS=','
for worker in $ETCD_CLUSTERS_CERTS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 echo "The node $node"
 $INSTALL_PATH/../certificates/install_peercert.sh -i $ip -h $node -t server -f etcd
 IFS=$oifs
done
unset IFS

#Install peer certificates for etcd client
IFS=','
for worker in $NODES; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 echo "The node $node"
 $INSTALL_PATH/../certificates/install_peercert.sh -i $ip -h $node -t client -f etcd
 IFS=$oifs
done
unset IFS

popd
