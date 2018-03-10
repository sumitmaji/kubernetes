#!/bin/bash

systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver

rm -rf /etc/systemd/system/kube-apiserver.service

rm -rf /opt/kubernetes
