#!/bin/bash

[[ "TRACE" ]] && set -x


HOSTIP="$(ifconfig eth0 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')"
: ${ETCDSERVERS:=http://11.0.0.2:2379}
: ${CLUSTERIPRANGE:=11.0.0.0/24}
: ${HAPROXY:=11.0.0.1}

pushd /tmp

#Install ectd
wget http://master.cloud.com:8181/repo/workspace/etcd/etcd-v3.0.7-linux-amd64.tar.gz
tar xzvf etcd-v3.0.7-linux-amd64.tar.gz
pushd etcd-v3.0.7-linux-amd64
mkdir -p /opt/etcd/bin
mkdir -p /opt/etcd/config/
cp etcd* /opt/etcd/bin/
mkdir -p /var/lib/etcd/

cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
ETCD_DATA_DIR=/var/lib/etcd
ETCD_NAME=Master1
ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380
ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_INITIAL_CLUSTER=Master1=http://$HOSTIP:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://$HOSTIP:2380
ETCD_ADVERTISE_CLIENT_URLS=http://$HOSTIP:2379
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

#Cleanup the files
popd
rm -f xzvf etcd-v3.0.7-linux-amd64.tar.gz
rm -rf etcd-v3.0.7-linux-amd64
ln -s /opt/etcd/bin/etcd /usr/local/bin/
ln -s /opt/etcd/bin/etcdctl /usr/local/bin/

FLANNEL_NET=172.17.0.0/16

#Set FLANNEL_NET to etcd
/opt/etcd/bin/etcdctl set /coreos.com/network/config '{"Network":"172.17.0.0/16","Backend": {"Type": "vxlan"}}'

mkdir -p ./kubernetes
pushd kubernetes

#Install kube-apiserver, kube-controller-manager and kubescheduler
wget http://master.cloud.com:8181/repo/workspace/kubernetes/kubernetes/server/kubernetes-server-linux-amd64.tar.gz
tar xf kubernetes-server-linux-amd64.tar.gz -C /opt/

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-apiserver \
--insecure-bind-address=0.0.0.0 \
--insecure-port=8080 \
--etcd-servers=$ETCDSERVERS \
--logtostderr=true \
--allow-privileged=false \
--service-cluster-ip-range=$CLUSTERIPRANGE \
--admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,SecurityContextDeny,ResourceQuota \
--service-node-port-range=30000-32767 \
--advertise-address=$HAPROXY \
--client-ca-file=/root/workspace/openssl/certs/ca.crt \
--tls-cert-file=/root/workspace/openssl/certs/server.crt \
--tls-private-key-file=/root/workspace/openssl/certs/server.key \
--portal_net=10.100.0.0/26
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF



cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-controller-manager \
--master=127.0.0.1:8080 \
--root-ca-file=/root/workspace/openssl/certs/ca.crt \
--service-account-private-key-file=/root/workspace/openssl/certs/server.key \
--logtostderr=true
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-scheduler \
--logtostderr=true \
--master=127.0.0.1:8080
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

!Set appropriate permissions and create a link to kubectl
ln -s /opt/kubernetes/server/bin/kubectl /usr/local/bin/
chmod 755 -R /opt/kubernetes/server/bin/

systemctl daemon-reload
for name in kube-apiserver kube-controller-manager kube-scheduler; do
systemctl enable $name
systemctl start $name
done

popd

#Clenup files
rm -rf kubernetes




popd


