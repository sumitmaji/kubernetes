#!/bin/bash

[[ "TRACE" ]] && set -x

systemctl stop kube-controller-manager
systemctl disable kube-controller-manager
systemctl daemon-reload

rm -rf /etc/systemd/system/kube-controller-manager.service

