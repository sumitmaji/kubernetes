#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/kubernetes/kubernetes/server

if [ ! -d /opt/kubernetes ]
then
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

mkdir -p /etc/kubernetes/manifests/
cp $INSTALL_PATH/../kube_service/cadvisor/cadvisor.manifest /etc/kubernetes/manifests/

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service
[Service]
ExecStart=/opt/kubernetes/server/bin/kubelet \
--hostname-override=$(hostname -s) \
--api-servers=http://$HAPROXY:8080 \
--logtostderr=true
--cluster-dns=${DNS_IP}
--cluster-domain=${YOUR_DOMAIN}
--config=/etc/kubernetes/manifests/
Restart=on-failure
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
systemctl status kubelet
