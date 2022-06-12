#!/bin/bash

[[ "TRACE" ]] && set -x

#/bin/bash /cluster/setDns.sh
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

/bin/bash /cluster/install_haproxy.sh

systemctl stop kubelet
systemctl start kubelet