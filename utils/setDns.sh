#!/bin/bash

echo "nameserver 11.0.0.1" > /etc/resolv.conf
echo "nameserver $(ifconfig eth1 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "search cloud.com Home" >> /etc/resolv.conf

#hostip="$(ifconfig eth1 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://')"
#sed -i "/127.0.1.1.*master/ s/127.0.1.1/$hostip/" /etc/hosts
