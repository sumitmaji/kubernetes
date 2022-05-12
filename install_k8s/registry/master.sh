#!/bin/bash
[[ "TRACE" ]] && set -x

: ${COUNTRY:=IN}
: ${STATE:=UP}
: ${LOCALITY:=GN}
: ${ORGANIZATION:=CloudInc}
: ${ORGU:=IT}
: ${EMAIL:=cloudinc.gmail.com}
: ${COMMONNAME:=master.cloud.com}
: ${MOUNT_PATH:=/root}

EXPORTDIR=$MOUNT_PATH

mkdir -p "$EXPORTDIR"/certs
mkdir -p /mnt/registry
cp config.yml /mnt/registry/config.yml
pushd "$EXPORTDIR"
if [ -f /etc/docker/certs.d/master.cloud.com:5000/domain.crt ]
then
echo "The file is present, not creating it!!!!!"
else
openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -x509 -days 365 -out certs/domain.crt \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGU/CN=$COMMONNAME/emailAddress=$EMAIL" \
  -addext "subjectAltName = DNS:${COMMONNAME}"
fi

docker stop registry
docker rm registry

docker run -d \
  --restart=always \
  --name registry \
  -v $EXPORTDIR/certs:/root/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/root/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/root/certs/domain.key \
  -v /mnt/registry:/var/lib/registry \
  -v /mnt/registry/config.yml:/etc/docker/registry/config.yml \
  -p 5000:5000 \
  registry:latest

mkdir -p /etc/docker/certs.d/master.cloud.com:5000

cp "$EXPORTDIR"/certs/domain.crt /etc/docker/certs.d/master.cloud.com:5000/domain.crt

popd