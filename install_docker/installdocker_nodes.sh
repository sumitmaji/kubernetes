#!/bin/bash

[[ "TRACE" ]] && set -x

: ${EXPORTDIR:=/export}
EXPORTDIR=$MOUNT_PATH
mkdir -p /etc/docker/certs.d/master.cloud.com:5000

cp "$EXPORTDIR"/certs/domain.crt /etc/docker/certs.d/master.cloud.com:5000/domain.crt

