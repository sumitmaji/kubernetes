#!/bin/bash

source config
source scripts/config

: ${PATH_TO_CHART:=chart}

if [[ "$(docker images -q $REPO_NAME 2> /dev/null)" == "" ]]; then
  ./build.sh
  ./tag_push.sh
fi

helm del --purge $RELEASE_NAME
helm install $PATH_TO_CHART --name $RELEASE_NAME