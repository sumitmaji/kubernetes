#!/bin/bash

source configuration
docker tag $IMAGE_NAME $REGISTRY/$REPO_NAME
docker push $REGISTRY/$REPO_NAME