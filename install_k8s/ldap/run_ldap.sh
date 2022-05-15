#!/bin/bash

source configuration

: ${PATH_TO_CHART:=chart}

#if [[ "$(docker images -q $REPO_NAME 2> /dev/null)" == "" ]]; then
./build.sh
./tag_push.sh
#fi

helm uninstall $RELEASE_NAME
helm install $RELEASE_NAME $PATH_TO_CHART