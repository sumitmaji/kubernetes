#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}

source $INSTALL_PATH/../config

kubectl create -f $INSTALL_PATH/../kube_service/influxdb/

