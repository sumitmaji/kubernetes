#!/bin/bash

source config
docker tag $IMAGE_NAME $REPO_NAME
docker push $REPO_NAME
