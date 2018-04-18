#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
 -o|--option)
 ACTION="$2"
 shift
 shift
 ;;
esac
done

systemctl stop kubelet
systemctl stop kube-proxy
systemctl disable kubelet
systemctl disable kube-proxy
systemctl daemon-reload

rm -rf /etc/systemd/system/kube-proxy.service
if [ "$ACTION" != 'stop' ]
then
 rm -rf /opt/kubernetes
fi
