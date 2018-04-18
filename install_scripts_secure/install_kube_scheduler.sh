#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
: ${UNINSTALL_PATH:=$MOUNT_PATH/kubernetes/uninstall_script/}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi
/bin/bash $UNINSTALL_PATH/uninstall_kube_scheduler.sh

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-scheduler \
--logtostderr=true \
--master=127.0.0.1:8080 \
--leader-elect=true \
--v=2 \
--kubeconfig=/var/lib/kube-scheduler/kubeconfig
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler
systemctl start kube-scheduler

systemctl status kube-scheduler
