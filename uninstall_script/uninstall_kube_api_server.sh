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


if [ $ACTION == 'stop' ]
then
systemctl stop kube-apiserver
systemctl enable kube-apiserver
systemctl daemon-reload
exit 0
else
systemctl stop kube-apiserver
systemctl enable kube-apiserver
systemctl daemon-reload
fi

rm -rf /etc/systemd/system/kube-apiserver.service

rm -rf /opt/kubernetes
