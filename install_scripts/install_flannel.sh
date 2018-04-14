#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace
mkdir -p /opt/flannel
tar xzf $FLANNEL_VERSION.tar.gz -C /opt/flannel

cat <<EOF | sudo tee /etc/systemd/system/flanneld.service
[Unit]
Description=Flanneld
Documentation=https://github.com/coreos/flannel
After=network.target
Before=docker.service
[Service]
User=root
ExecStart=/opt/flannel/flanneld \
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
echo "--etcd-endpoints=${cluster}"` \
--iface=$HOSTINTERFACE \
--ip-masq
ExecStartPost=/bin/bash /opt/flannel/update_docker.sh
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /opt/flannel/update_docker.sh
source /run/flannel/subnet.env
sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}|g" /lib/systemd/system/docker.service
rc=0
ip link show docker0 >/dev/null 2>&1 || rc="$?"
if [[ "$rc" -eq "0" ]]; then
ip link set dev docker0 down
ip link delete docker0
fi
systemctl daemon-reload
EOF

systemctl daemon-reload && systemctl enable flanneld && systemctl start flanneld

systemctl restart docker

systemctl status flanneld

popd
popd

