#!/bin/bash

[[ "TRACE" ]] && set -x

#Remove the softlink
rm /usr/local/bin/etcd
rm /usr/local/bin/etcdctl

#Stop the services
systemctl stop etcd && systemctl disable etcd && systemctl daemon-reload

#Remove etcd files
rm -rf /etc/systemd/system/etcd.service
rm -rf /var/lib/etcd
rm -rf /opt/etcd
