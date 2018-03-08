#!/bin/bash

[[ "TRACE" ]] && set -x

: ${EXPORTDIR:=/home/sumit}

mkdir -p /etc/docker/certs.d/master.cloud.com:5000

cp "$EXPORTDIR"/certs/domain.crt /etc/docker/certs.d/master.cloud.com:5000/domain.crt
