#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}
source $INSTALL_PATH/../config

: ${COUNTRY:=IN}
: ${STATE:=UP}
: ${LOCALITY:=GN}
: ${ORGANIZATION:=CloudInc}
: ${ORGU:=IT}
: ${EMAIL:=cloudinc.gmail.com}
: ${COMMONNAME:=kube-system}

mkdir -p $CERTIFICATE/certs
pushd $CERTIFICATE/certs

#Create a self signed certificate
openssl req -new -x509 -nodes -keyout ca.key -out ca.crt -days 3650 -passin pass:sumit \
-subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=$COMMONNAME/emailAddress=$EMAIL"

popd
