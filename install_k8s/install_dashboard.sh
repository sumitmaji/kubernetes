#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

mkdir -p $WORKING_DIR/dashboard
pushd $WORKING_DIR/dashboard
apt-get install net-tools

rm dashboard.key dashboard.crt dashboard.csr
kubectl delete -f v2.5.1.yaml
kubectl delete csr dashboard-csr

openssl genrsa -out dashboard.key 4096
openssl req -new -key dashboard.key -out dashboard.csr -subj "/CN=dashboard/O=cloud:masters"

B64=`cat dashboard.csr | base64 | tr -d '\n'`
cat ../signing-request-template.yaml | \
    sed "s@__USERNAME__@dashboard@" | \
    sed "s@__CSRREQUEST__@${B64}@" | \
    kubectl create -f -


kubectl certificate approve dashboard-csr

KEY=`cat dashboard.key | base64 | tr -d '\n'`
CERT=`kubectl get csr dashboard-csr -o jsonpath='{.status.certificate}'`
echo $CERT | base64 -d > dashboard.crt

cat v2.5.1.yaml | \
sed "s@__DASHBOARD_KEY__@${KEY}@" | \
sed "s@__DASHBOARD_CRT__@${CERT}@" > dashboard.yaml
cat dashboard.yaml | envsubst | kubectl create -f -

popd