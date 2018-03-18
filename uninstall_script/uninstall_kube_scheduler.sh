#!/bin/bash

[[ "TRACE" ]] && set -x

systemctl stop kube-scheduler
systemctl disable kube-scheduler
systemctl daemon-reload

rm -rf /etc/systemd/system/kube-scheduler.service
