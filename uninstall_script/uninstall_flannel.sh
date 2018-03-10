#!/bin/bash

systemctl stop flanneld
systemctl disable flanneld
systemctl daemon-reload

service docker stop
sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H fd:\/\/|g" /lib/systemd/system/docker.service
service docker start

rm -rf /etc/systemd/system/flanneld.service
rm -rf /opt/flannel

