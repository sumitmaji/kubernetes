#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace

#Install ectd
pushd etcd
tar -xzvf etcd-v3.0.7-linux-amd64.tar.gz
pushd etcd-v3.0.7-linux-amd64
mkdir -p /opt/etcd/bin
mkdir -p /opt/etcd/config/
cp etcd* /opt/etcd/bin/
mkdir -p /var/lib/etcd/

cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
ETCD_DATA_DIR=/var/lib/etcd
ETCD_NAME=$(hostname -s)
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER=${ETCD_1_NAME}=http://${ETCD_1_IP}:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${ADVERTISE_IP}:2380
ETCD_ADVERTISE_CLIENT_URLS=http://${ADVERTISE_IP}:2379
ETCD_HEARTBEAT_INTERVAL=6000
ETCD_ELECTION_TIMEOUT=30000
GOMAXPROCS=$(nproc)
EOF

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=Etcd Server
Documentation=https://github.com/coreos/etcd
After=network.target
[Service]
User=root
Type=simple
EnvironmentFile=-/opt/etcd/config/etcd.conf
ExecStart=/opt/etcd/bin/etcd
Restart=on-failure
RestartSec=10s
LimitNOFILE=40000
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable etcd && systemctl start etcd

popd
popd
popd
popd

ln -s /opt/etcd/bin/etcd /usr/local/bin/etcd
ln -s /opt/etcd/bin/etcdctl /usr/local/bin/etcdctl

sleep 10

#Set FLANNEL_NET to etcd
/opt/etcd/bin/etcdctl set /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}'
