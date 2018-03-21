#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/kubernetes/kubernetes/server

if [ ! -d /opt/kubernetes ]
then
 tar xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Proxy
After=network.target
[Service]
ExecStart=/opt/kubernetes/server/bin/kube-proxy \
--hostname-override=$(hostname -s) \
--master=$APISERVER_HOST \
--logtostderr=true
--kubeconfig=$CERTIFICATE_MOUNT_PATH/kubeconfig \
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy
systemctl restart kube-proxy
systemctl status kube-proxy
