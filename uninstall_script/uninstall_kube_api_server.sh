#!/bin/bash

[[ "TRACE" ]] && set -x

systemctl stop kube-apiserver
systemctl enable kube-apiserver
systemctl daemon-reload

rm -rf /etc/systemd/system/kube-apiserver.service

rm -rf /opt/kubernetes
