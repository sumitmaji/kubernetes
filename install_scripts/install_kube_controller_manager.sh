#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-controller-manager \
--master=127.0.0.1:8080 \
--root-ca-file=$CERTIFICATE/certs/ca.crt \
--service-account-private-key-file=$CERTIFICATE/certs/server.key \
--logtostderr=true
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager

systemctl status kube-controller-manager
