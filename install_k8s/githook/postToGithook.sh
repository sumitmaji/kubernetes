#!/bin/bash

while [ $# -gt 0 ]; do
    case "$1" in
        -b | --branch)
        shift
        BRANCH=$1
        ;;
        -a | --app)
        shift
        APP=$1
        ;;
    esac
shift
done

if [ -z "$BRANCH" ]
then
	echo "Please provide branch name"
	exit 0
fi

if [ -z "$APP" ]
then
	echo "Please provide app name"
	exit 0
fi

: ${IP:=$(ifconfig eth0 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
if [ -z "$IP" ]; then
    : ${IP:=$(ifconfig enp0s8 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
fi



DATA="{
  "ref": "refs/heads/$BRANCH",
  "repository": {
    "name": "$APP",
    "owner": {
      "html_url": "https://github.com/sumitmaji"
    }
}"

curl --header "Content-Type: application/json" \
  --request POST \
  --data '$DATA' \
  http://$IP:32501/payload
