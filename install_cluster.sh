#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

mkdir -p /cluster/

cp $MOUNT_PATH/kubernetes/start_cluster.sh $MOUNT_PATH/kubernetes/setDns.sh $MOUNT_PATH/kubernetes/install_scripts/install_haproxy.sh /cluster/

sed -i "s/\$MASTER_1_IP/$MASTER_1_IP/" /cluster/install_haproxy.sh

chmod +x /cluster/*

cat <<EOF | sudo tee /etc/systemd/system/cluster.service
[Unit]
Description=Cluster
After=docker.service
[Service]
User=root
ExecStart=/cluster/start_cluster.sh
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable cluster && systemctl start cluster
