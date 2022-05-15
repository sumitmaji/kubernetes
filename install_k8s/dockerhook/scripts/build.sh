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

if [ "$BUILD_TYPE" == "REACT" ]; then
    cp /usr/src/app/scripts/Dockerfile_React ./Dockerfile
elif [ "$BUILD_TYPE" == "NODE" ]; then
    cp /usr/src/app/scripts/Dockerfile_Node ./Dockerfile
fi

sed -i "s/__PATH__/$APP_SRC_CODE/g" Dockerfile
sed -i "s/__PORT__/$APP_PORT/g" Dockerfile
docker build -t $IMAGE_NAME .


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
