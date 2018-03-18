#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/kubernetes/kubernetes/server/
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
ExecStart=/opt/kubernetes/server/bin/kube-apiserver \
--insecure-bind-address=0.0.0.0 \
--insecure-port=8080 \
--etcd-servers=http://${ETCD_1_IP}:2379 \
--logtostderr=true \
--allow-privileged=false \
--service-cluster-ip-range=$CLUSTERIPRANGE \
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,SecurityContextDeny,ResourceQuota \
--service-node-port-range=30000-32767 \
--advertise-address=$HAPROXY \
--client-ca-file=$CERTIFICATE/certs/ca.crt \
--tls-cert-file=$CERTIFICATE/certs/server.crt \
--tls-private-key-file=$CERTIFICATE/certs/server.key \
--portal_net=10.100.0.0/26
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver

systemctl status kube-apiserver

popd
popd
