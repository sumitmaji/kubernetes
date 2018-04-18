#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi
/bin/bash $UNINSTALL_PATH/uninstall_etcd.sh

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

proto='http'
if [ $ENABLE_ETCD_SSL == 'true' ]
then
 proto='https'
fi

get_etcd_cluster(){

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
   cluster="$node=${proto}://$ip:2380"
  else
   cluster="$cluster,$node=${proto}://$ip:2380"
  fi
  counter=$((counter+1))
  IFS=$oifs
 done
 unset IFS
 echo "$cluster"

}
ETCD_INITIAL_CLUSTER=$(get_etcd_cluster)

cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
ETCD_DATA_DIR=/var/lib/etcd
ETCD_NAME=$(hostname -s)
`
#Enable ssl
if [ $ENABLE_ETCD_SSL == 'true' ]
then
 echo "ETCD_LISTEN_PEER_URLS=https://${HOSTIP}:2380"
 echo "ETCD_LISTEN_CLIENT_URLS=https://${HOSTIP}:2379,https://${HOSTIP}:4001,http://127.0.0.1:2379,http://127.0.0.1:4001"
 echo "ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}"
 echo "ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${HOSTIP}:2380"
 echo "ETCD_ADVERTISE_CLIENT_URLS=https://${HOSTIP}:2379,https://${HOSTIP}:4001"
 echo "ETCD_PEER_CERT_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd.crt"
 echo "ETCD_PEER_KEY_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd.key"
 echo "ETCD_PEER_TRUSTED_CA_FILE=$CERTIFICATE_MOUNT_PATH/ca.crt"
 echo "ETCD_PEER_CLIENT_CERT_AUTH=true"
 echo "ETCD_CERT_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd.crt"
 echo "ETCD_KEY_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd.key"
 echo "ETCD_TRUSTED_CA_FILE=$CERTIFICATE_MOUNT_PATH/ca.crt"
 echo "ETCD_CLIENT_CERT_AUTH=true"
else
 echo "ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380"
 echo "ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379,http://0.0.0.0:4001"
 echo "ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}"
 echo "ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${HOSTIP}:2380"
 echo "ETCD_ADVERTISE_CLIENT_URLS=http://${HOSTIP}:2379,http://${HOSTIP}:4001"
fi
`
ETCD_INITIAL_CLUSTER_STATE=new
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
Type=notify
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


#Set FLANNEL_NET to etcd
if [ $ENABLE_ETCD_SSL == 'true' ]
then
 #sleep 50
 /opt/etcd/bin/etcdctl --cert-file $CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.crt --key-file $CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.key --ca-file $CERTIFICATE_MOUNT_PATH/ca.crt set /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}'
 /opt/etcd/bin/etcdctl --cert-file $CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.crt --key-file $CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.key --ca-file $CERTIFICATE_MOUNT_PATH/ca.crt cluster-health
else
 #sleep 20
 /opt/etcd/bin/etcdctl set /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}'
 /opt/etcd/bin/etcdctl cluster-health
fi
