#!/bin/bash

docker run -it -v /home/sumit/DockerImages/repository:/usr/local/repository --name $CONTAINER_NAME $IMAGE_NAME /bin/bash
