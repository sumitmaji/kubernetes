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





DATA="{
  "ref": "refs/heads/$BRANCH",
  "repository": {
    "name": "$APP",
    "owner": {
      "html_url": "https://github.com/sumitmaji"
    }
}"
echo $DATA

