#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi
/bin/bash $UNINSTALL_PATH/uninstall_kube_api_server.sh -o stop

pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/
if [ ! -d /opt/kubernetes ]
then
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

etcdproto='http'
if [ $ENABLE_ETCD_SSL == 'true' ]
then
 etcdproto='https'
fi


get_etcd_endpoints(){

#Install etcd nodes
IFS=','
counter=0
cluster=""
for worker in $ETCD_CLUSTERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 if [ -z "$cluster" ]
 then
  cluster="$etcdproto://$ip:4001"
 else
  cluster="$cluster,$etcdproto://$ip:4001"
 fi
 counter=$((counter+1))
 IFS=$oifs
done
unset IFS
echo "${cluster}"
}

ETCD_SERVERS="--etcd-servers=$(get_etcd_endpoints)"

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service
[Service]
User=root
EnvironmentFile=-/var/lib/flanneld/subnet.env
ExecStart=/opt/kubernetes/server/bin/kube-apiserver \
--bind-address=0.0.0.0 \
--insecure-port=8080 \
--secure-port=6443 \
--logtostderr=true \
`if [ $ENABLE_ETCD_SSL == 'true' ]
then

 echo "--etcd-cafile=$CERTIFICATE_MOUNT_PATH/ca.crt --etcd-certfile=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.crt --etcd-keyfile=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.key "

fi
` \
$ETCD_SERVERS \
`if [ $ENABLE_KUBE_SSL == 'true' ]
then
 echo "--anonymous-auth=false --authorization-mode=RBAC,AlwaysAllow --authorization-rbac-super-user=admin --basic-auth-file=$CERTIFICATE/certs/basic_auth.csv --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,ResourceQuota --token-auth-file=$CERTIFICATE/certs/known_tokens.csv --service-account-key-file=$CERTIFICATE/certs/server.key"
fi` \
--allow-privileged=true \
--service-cluster-ip-range=$CLUSTERIPRANGE \
--service-node-port-range=30000-32767 \
--advertise-address=$HAPROXY \
--client-ca-file=$CERTIFICATE/certs/ca.crt \
--tls-cert-file=$CERTIFICATE/certs/server.crt \
--tls-private-key-file=$CERTIFICATE/certs/server.key \
--v=6
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

#--portal_net=10.100.0.0/26

#--portal-net=$FLANNEL_NETWORK \
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver

systemctl status kube-apiserver

popd
popd
