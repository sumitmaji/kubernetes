#!/bin/bash
docker rmi $(docker images | grep "^<none>" | awk "{print $3}")
docker rmi $(docker images -a -q)
