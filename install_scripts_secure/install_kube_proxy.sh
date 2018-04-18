#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR
$INSTALL_PATH/setup.sh
pushd workspace/

if [ ! -d /opt/kubernetes ]
then
 tar xf kubernetes-server-linux-amd64.tar.gz -C /opt/
fi

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Proxy
After=network.target
[Service]
ExecStart=/opt/kubernetes/server/bin/kube-proxy \
--hostname-override=$(hostname -s) \
--master=$APISERVER_HOST \
--cluster-cidr=$FLANNEL_NET \
--kubeconfig=/var/lib/kube-proxy/kubeconfig \
--logtostderr=true
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy
systemctl restart kube-proxy
systemctl status kube-proxy

popd
popd
