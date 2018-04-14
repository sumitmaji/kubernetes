#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace

#Install ectd
pushd etcd
tar -xzvf $ETCD_VERSION.tar.gz
pushd $ETCD_VERSION
mkdir -p /opt/etcd/bin
mkdir -p /opt/etcd/config/
cp etcd* /opt/etcd/bin/
mkdir -p /var/lib/etcd/

cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
ETCD_DATA_DIR=/var/lib/etcd
ETCD_NAME=$(hostname -f)
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001
ETCD_INITIAL_CLUSTER_STATE=new
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
  cluster="$node=http://$ip:2380"
 else
  cluster="$cluster,$node=http://$ip:2380"
 fi
 counter=$((counter+1))
 IFS=$oifs
done
unset IFS
echo "ETCD_INITIAL_CLUSTER=$cluster"
`
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${HOSTIP}:2380
ETCD_ADVERTISE_CLIENT_URLS=http://${HOSTIP}:2379,http://${HOSTIP}:4001
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

ln -s /opt/etcd/bin/etcd /usr/local/bin/etcd
ln -s /opt/etcd/bin/etcdctl /usr/local/bin/etcdctl

sleep 20

#Set FLANNEL_NET to etcd
/opt/etcd/bin/etcdctl set /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}'
