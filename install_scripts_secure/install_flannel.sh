#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

/bin/bash $UNINSTALL_PATH/uninstall_flannel.sh

pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace
mkdir -p /opt/flannel
tar xzf $FLANNEL_VERSION.tar.gz -C /opt/flannel

mkdir -p /etc/flanneld
proto='http'
if [ $ENABLE_ETCD_SSL == 'true' ]
then
 proto='https'
fi

get_etcd_endpoints(){

IFS=','
counter=0
cluster=""
for worker in $ETCD_CLUSTERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 if [ -z "$cluster" ]
 then
  cluster="$proto://$ip:4001"
 else
  cluster="$cluster,$proto://$ip:4001"
 fi
 counter=$((counter+1))
 IFS=$oifs
done
unset IFS
echo "${cluster}"
}

ETCD_END_POINTS="--etcd-endpoints=$(get_etcd_endpoints)"
FLANNELD_ETCD_ENDPOINTS=$(get_etcd_endpoints)

cat <<EOF | sudo tee /etc/flanneld/options.env
FLANNELD_ETCD_ENDPOINTS=${FLANNELD_ETCD_ENDPOINTS}
FLANNELD_ETCD_CAFILE=$CERTIFICATE_MOUNT_PATH/ca.crt
FLANNELD_ETCD_CERTFILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.crt
FLANNELD_ETCD_KEYFILE=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.key
FLANNELD_IFACE=$HOSTINTERFACE
EOF


#EnvironmentFile=/etc/flanneld/options.env
cat <<EOF | sudo tee /etc/systemd/system/flanneld.service
[Unit]
Description=Flanneld
Documentation=https://github.com/coreos/flannel
After=network.target
Before=docker.service
[Service]
User=root
LimitNOFILE=40000
LimitNPROC=1048576
#ExecStartPre=/sbin/modprobe ip_tables
#ExecStartPre=/bin/mkdir -p /run/flanneld

ExecStart=/opt/flannel/flanneld \
`if [ $ENABLE_ETCD_SSL == 'true' ]
then

 echo "--etcd-cafile=$CERTIFICATE_MOUNT_PATH/ca.crt --etcd-certfile=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.crt --etcd-keyfile=$CERTIFICATE_MOUNT_PATH/$(hostname -s).${DOMAIN}-etcd-client.key "

fi
` \
$ETCD_END_POINTS \
--iface=$HOSTINTERFACE \
--ip-masq
## Updating Docker options
#ExecStartPost=/opt/flannel/mk-docker-opts.sh -d /run/flanneld/docker_opts.env -i
ExecStartPost=/bin/bash /opt/flannel/update_docker.sh
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /opt/flannel/update_docker.sh
source /run/flannel/subnet.env
#source /run/flanneld/docker_opts.env
#sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock \${DOCKER_OPT_BIP} \${DOCKER_OPT_MTU} \${DOCKER_OPT_IPMASQ}|g" /lib/systemd/system/docker.service
sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}|g" /lib/systemd/system/docker.service
rc=0
ip link show docker0 >/dev/null 2>&1 || rc="$?"
if [[ "$rc" -eq "0" ]]; then
ip link set dev docker0 down
ip link delete docker0
fi
systemctl daemon-reload
EOF

#sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}|g" /lib/systemd/system/docker.service
#rc=0
#ip link show docker0 >/dev/null 2>&1 || rc="$?"
#if [[ "$rc" -eq "0" ]]; then
#ip link set dev docker0 down
#ip link delete docker0
#fi

systemctl daemon-reload && systemctl enable flanneld && systemctl start flanneld

systemctl restart docker

systemctl status flanneld

popd
popd

