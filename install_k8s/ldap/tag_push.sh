#!/bin/bash

source configuration
docker tag $IMAGE_NAME $REGISTRY/$REPO_NAME
docker push $REPO_NAME
