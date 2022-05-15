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
mkdir -p ./CLOUD_CHART
cp -r /usr/src/app/scripts/chart ./CLOUD_CHART/
source configuration
find ./ -type f -exec sed -i -e "s/__APPNAME__/$APPNAME/g" {} \;
find ./ -type f -exec sed -i -e "s/__CONTEXT__/$CONTEXT/g" {} \;
find ./ -type f -exec sed -i -e "s/__VERSION__/$VERSION/g" {} \;

if [[ $DEPLOY == "true" ]]; then
  helm uninstall $RELEASE_NAME
  helm install $RELEASE_NAME CLOUD_CHART/chart
fi
popd
popd
