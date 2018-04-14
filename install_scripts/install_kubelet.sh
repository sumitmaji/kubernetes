#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace

if [ ! -d /opt/kubernetes ]
then
 tar -xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service
[Service]
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=/opt/kubernetes/server/bin/kubelet --v=2 --non-masquerade-cidr=$CLUSTER_NON_MASQUEARADE_CIDR --allow-privileged=true --enable-custom-metrics=true --cgroup-root=/ --enable-debugging-handlers=true --eviction-hard=memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%,imagefs.available<10%,imagefs.inodesFree<5% --kubeconfig=/var/lib/kubelet/kubeconfig --pod-manifest-path=/etc/kubernetes/manifests --register-schedulable=true --container-runtime=docker --docker=unix:///var/run/docker.sock --tls-cert-file=$CERTIFICATE_MOUNT_PATH/server.crt --tls-private-key-file=$CERTIFICATE_MOUNT_PATH/server.key --client-ca-file=$CERTIFICATE_MOUNT_PATH/ca.crt --fail-swap-on=false --hostname-override=$(hostname -s) --node-labels=kubernetes.io/role=master,node-role.kubernetes.io/master=
Restart=on-failure
KillMode=process
[Install]
WantedBy=multi-user.target
EOF



#ExecStart=/opt/kubernetes/server/bin/kubelet \
#--hostname-override=$(hostname -s) \
#--logtostderr=true \
#--tls-cert-file=$CERTIFICATE_MOUNT_PATH/server.crt \
#--tls-private-key-file=$CERTIFICATE_MOUNT_PATH/server.key \
#--kubeconfig=/var/lib/kubelet/kubeconfig \
#--fail-swap-on=false
systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
systemctl status kubelet

popd
popd
