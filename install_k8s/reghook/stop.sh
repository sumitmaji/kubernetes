#!/bin/bash
source config
source scripts/config
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME