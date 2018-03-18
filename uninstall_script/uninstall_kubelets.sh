#!/bin/bash

[[ "TRACE" ]] && set -x

systemctl stop kubelet
systemctl stop kube-proxy
systemctl disable kubelet
systemctl disable kube-proxy
systemctl daemon-reload

rm -rf /etc/systemd/system/kube-proxy.service

rm -rf /opt/kubernetes
