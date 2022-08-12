#!/bin/bash

: ${WORKING_DIR:=$MOUNT_PATH/kubernetes/install_k8s}

source $WORKING_DIR/config

docker stop master-proxy
docker rm master-proxy

cat <<EOF > /opt/haproxy.cfg
global
        log 127.0.0.1 local0
        log 127.0.0.1 local1 notice
        maxconn 4096
        maxpipes 1024
        daemon
defaults
        log global
        mode tcp
        option tcplog
        option dontlognull
        option redispatch
        option http-server-close
        retries 3
        timeout connect 5000
        timeout client 50000
        timeout server 50000
        frontend default_frontend
        bind *:$HA_PROXY_PORT
        default_backend master-cluster
backend master-cluster
`#Install master nodes
IFS=','
counter=0
cluster=""
for worker in $API_SERVERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 if [ -z "$cluster" ]
 then
  cluster="$ip:6443"
 else
  cluster="$cluster,http://$ip:4001"
 fi
 counter=$((counter+1))
 IFS=$oifs
 echo "        server master-$counter ${cluster} check"
 cluster=""
done
unset IFS`
EOF

docker run -d --name master-proxy \
-v /opt/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
--net=host haproxy


