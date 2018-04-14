#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
[Service]
User=root
ExecStart=/opt/kubernetes/server/bin/kube-controller-manager --v=2 --allocate-node-cidrs=true --attach-detach-reconcile-sync-period=1m0s --cluster-cidr=$FLANNEL_NET --cluster-name=cloud.com --leader-elect=true --root-ca-file=$CERTIFICATE_MOUNT_PATH/ca.crt --service-account-private-key-file=$CERTIFICATE_MOUNT_PATH/server.key --use-service-account-credentials=true --kubeconfig=/var/lib/kube-controller-manager/kubeconfig --cluster-signing-cert-file=$CERTIFICATE_MOUNT_PATH/ca.crt --cluster-signing-key-file=$CERTIFICATE_MOUNT_PATH/ca.key --service-cluster-ip-range=$CLUSTERIPRANGE --configure-cloud-routes=false --logtostderr=true --master=127.0.0.1:8080
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager

systemctl status kube-controller-manager
