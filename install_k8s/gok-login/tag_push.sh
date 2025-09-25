#!/bin/bash
# Tag and push gok-login image to registry
docker tag gok-login:latest registry.gokcloud.com/gok-login:latest
docker push registry.gokcloud.com/gok-login:latest
