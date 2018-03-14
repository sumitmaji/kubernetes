#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/flannel
mkdir -p /opt/flannel
tar xzf flannel.tar.gz -C /opt/flannel

cat <<EOF | sudo tee /etc/systemd/system/flanneld.service
[Unit]
Description=Flanneld
Documentation=https://github.com/coreos/flannel
After=network.target
Before=docker.service
[Service]
User=root
ExecStart=/opt/flannel/flanneld \
--etcd-endpoints="http://${ETCD_1_IP}:2379" \
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

