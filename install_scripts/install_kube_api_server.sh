#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/
if [ ! -d /opt/kubernetes ]
then
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

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
`#Install etcd nodes
IFS=','
counter=0
cluster=""
for worker in $ETCD_CLUSTERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 if [ -z "$cluster" ]
 then
  cluster="http://$ip:4001"
 else
  cluster="$cluster,http://$ip:4001"
 fi
 counter=$((counter+1))
 IFS=$oifs
done
unset IFS
echo "--etcd-servers=${cluster}"` \
--logtostderr=true \
--allow-privileged=true \
--anonymous-auth=false \
--authorization-mode=RBAC,AlwaysAllow \
--authorization-rbac-super-user=admin \
--basic-auth-file=$CERTIFICATE/certs/basic_auth.csv \
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,DefaultTolerationSeconds,ResourceQuota \
--service-cluster-ip-range=$CLUSTERIPRANGE \
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,SecurityContextDeny,ResourceQuota \
--service-node-port-range=30000-32767 \
--advertise-address=$HAPROXY \
--client-ca-file=$CERTIFICATE/certs/ca.crt \
--tls-cert-file=$CERTIFICATE/certs/server.crt \
--tls-private-key-file=$CERTIFICATE/certs/server.key \
--token-auth-file=$CERTIFICATE/certs/known_tokens.csv \
--service-account-key-file=$CERTIFICATE/certs/server.key \
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
