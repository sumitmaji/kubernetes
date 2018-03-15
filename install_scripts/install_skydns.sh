#!/bin/bash
[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR


cp $INSTALL_PATH/../kube_service/skydns/skydns-rc.yaml .
cp $INSTALL_PATH/../kube_service/skydns/skydns-svc.yaml .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/skydns-rc.yaml
sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/skydns-rc.yaml
sed -i "s/\$SKYDNS_DOMAIN_NAME/$SKYDNS_DOMAIN_NAME/" $WORKDIR/skydns-rc.yaml

sed -i "s/\$DNS_IP/$DNS_IP/" $WORKDIR/skydns-svc.yaml


kubectl create -f $WORKDIR/skydns-rc.yaml
kubectl create -f $WORKDIR/skydns-svc.yaml

check=`grep -E "ExecStart.*--cluster-dns.*--cluster-domain" /etc/systemd/system/kubelet.service`
if [ -z "$check" ]
then
 sed  -i "/ExecStart/s/$/ --cluster-dns=$DNS_IP --cluster-domain=$SKYDNS_DOMAIN_NAME/" /etc/systemd/system/kubelet.service
fi

systemctl daemon-reload
systemctl restart kubelet
service docker restart

popd


