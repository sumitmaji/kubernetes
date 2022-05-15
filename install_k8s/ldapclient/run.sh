#!/bin/bash
source configuration
docker run -it -e ENABLE_KRB='true' --name ldap-client -h ldap-client.cloud.com --net cloud.com $REGISTRY/$REPO_NAME -d
