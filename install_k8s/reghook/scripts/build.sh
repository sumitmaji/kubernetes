#!/usr/bin/env bash
[[ "TRACE" ]] && set -x

source ./scripts/config
: ${BUILD_PATH:=/tmp}
: ${BRANCH:=master}

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
 -r|--repository)
 REP="$2"
 shift
 shift
 ;;
 -u|--url)
 URL="$2"
 shift
 shift
 ;;
 -b|--branch)
 BRANCH="$2"
 shift
 shift
 ;;

esac
done

NUMBER=$[ ( $RANDOM % 100 )  + 1 ]
mkdir /$BUILD_PATH/$NUMBER
pushd /$BUILD_PATH/$NUMBER
git clone -b $BRANCH $URL/${REP}.git
pushd $REP
source configuration
if [[ $DEPLOY == "true" ]]; then
  helm uninstall $RELEASE_NAME
  helm install $RELEASE_NAME $PATH_TO_CHART
fi
popd
popd
