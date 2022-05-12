#!/usr/bin/env bash
[[ "TRACE" ]] && set -x

source ./scripts/config
: ${BRANCH:=master}
: ${BUILD_PATH:=/tmp}

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

if [[ -z $REP ]]; then
  echo "Please provide repository name."
  exit 1
elif [[ -z $URL ]]; then
  echo "Please provide the url (e.g. https://github.com/sumitmaji)."
  exit 1
fi

NUMBER=$[ ( $RANDOM % 100 )  + 1 ]
mkdir /$BUILD_PATH/$NUMBER
pushd /$BUILD_PATH/$NUMBER
git clone -b $BRANCH $URL/${REP}.git
pushd $REP
source configuration
chmod +x build.sh
./build.sh
if [ $? -eq 0 ]
then
docker tag $IMAGE_NAME master.cloud.com:5000/$REPO_NAME
docker push master.cloud.com:5000/$REPO_NAME
else
  echo "Error while executing script."
  exit 1
fi
popd
popd
