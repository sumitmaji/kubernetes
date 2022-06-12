#!/bin/bash

[[ "TRACE" ]] && set -x

#/bin/bash /cluster/setDns.sh
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

/bin/bash ${MOUNT_PATH}/kubernetes/install_k8s/install_haproxy.sh

systemctl stop kubelet
systemctl start kubelet