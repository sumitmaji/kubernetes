#!/bin/bash
source config
source scripts/config
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME

docker run -v /var/run/docker.sock:/var/run/docker.sock -v $BUILD_PATH:/tmp -p 5002:5002 -d --name $CONTAINER_NAME $IMAGE_NAME
