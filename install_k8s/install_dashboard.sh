#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

mkdir -p $WORKING_DIR/dashboard
pushd $WORKING_DIR/dashboard
apt-get install net-tools

rm dashboard.key dashboard.crt dashboard.csr
kubectl delete -f v2.5.1.yaml
kubectl delete -f metric-server.yaml
kubectl delete -f ingress.yaml
kubectl delete secret appingress-certificate -n kubernetes-dashboard
kubectl delete secret kubernetes-dashboard-certs -n kubernetes-dashboard

sleep 15
#Create a service account which is having cluster admin role to group dashboard:masters,
#This service account will be granted to kubernetes dashboard user
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: dashboard:masters
EOF

#below would create user named dashboard with group assigned as dashboard:masters
openssl genrsa -out dashboard.key 4096
openssl req -new -key dashboard.key -out dashboard.csr -subj "/CN=dashboard/O=dashboard:masters"
openssl x509 -req -in dashboard.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out dashboard.crt -days 7200

#below would create user named ingress with group assigned as ingress
openssl genrsa -out ${APP_HOST}.key 4096
openssl req -new -key ${APP_HOST}.key -out ${APP_HOST}.csr -subj "/CN=${APP_HOST}" \
-addext "subjectAltName = DNS:${APP_HOST}"
openssl x509 -req -in ${APP_HOST}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${APP_HOST}.crt -days 7200

#Certificates for dashboard user(created above) will be mounted in the pod as secret for
# authenticating dashbaord user with kubernetes api-server
kubectl create ns kubernetes-dashboard
kubectl -n kubernetes-dashboard create secret generic kubernetes-dashboard-certs \
--from-file=tls.crt=dashboard.crt \
--from-file=tls.key=dashboard.key

cat v2.5.1.yaml | envsubst | kubectl create -f -
kubectl create -f metric-server.yaml

kubectl create secret tls appingress-certificate --key ${APP_HOST}.key --cert ${APP_HOST}.crt -n kubernetes-dashboard
cat ingress.yaml | envsubst | kubectl create -f -

popd