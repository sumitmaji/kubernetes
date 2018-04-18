#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi
/bin/bash $UNINSTALL_PATH/uninstall_kubelets.sh -o stop

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
ExecStart=/opt/kubernetes/server/bin/kubelet \
`
if [ $ENABLE_KUBE_SSL == 'true' ]
then
 echo "--v=2 --non-masquerade-cidr=$CLUSTER_NON_MASQUEARADE_CIDR --allow-privileged=true --enable-custom-metrics=true --cgroup-root=/ --enable-debugging-handlers=true --eviction-hard=memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%,imagefs.available<10%,imagefs.inodesFree<5% --tls-cert-file=$CERTIFICATE_MOUNT_PATH/server.crt --tls-private-key-file=$CERTIFICATE_MOUNT_PATH/server.key --client-ca-file=$CERTIFICATE_MOUNT_PATH/ca.crt --node-labels=kubernetes.io/role=master,node-role.kubernetes.io/master= "
fi
` \
--hostname-override=$(hostname -s) \
--logtostderr=true --fail-swap-on=false \
--kubeconfig=/var/lib/kubelet/kubeconfig --pod-manifest-path=/etc/kubernetes/manifests --register-schedulable=true --container-runtime=docker --docker=unix:///var/run/docker.sock
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
