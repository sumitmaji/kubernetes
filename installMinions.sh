#!/bin/bash

[[ "TRACE" ]] && set -x


HOSTIP="$(ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')"
: ${HAPROXY:=11.0.0.1}
: ${ETCDSERVERS:=http://11.0.0.2:2379}

cd /tmp

mkdir -p ./kubernetes
pushd kubernetes

#Install kubelet, kube-proxy and flannel
wget http://master.cloud.com:8181/repo/workspace/kubernetes/kubernetes/server/kubernetes-server-linux-amd64.tar.gz

if [ ! -d /opt/kubernetes ]
then
 tar xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service
[Service]
ExecStart=/opt/kubernetes/server/bin/kubelet \
--hostname-override=$HOSTIP \
--api-servers=http://$HAPROXY:8080 \
--logtostderr=true
Restart=on-failure
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Proxy
After=network.target
[Service]
ExecStart=/opt/kubernetes/server/bin/kube-proxy \
--hostname-override=$HOSTIP \
--master=http://$HAPROXY:8080 \
--logtostderr=true
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

popd

#Cleanup
rm -rf kubernetes


mkdir flannel
pushd flannel

wget http://master.cloud.com:8181/repo/workspace/flannel/flannel.tar.gz
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
--etcd-endpoints="$ETCDSERVERS" \
--iface=$HOSTIP \
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

systemctl daemon-reload
for name in kubelet kube-proxy flanneld; do
systemctl enable $name
systemctl start $name
done

systemctl restart docker

popd

rm -rf flannel
