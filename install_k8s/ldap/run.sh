#!/bin/bash
docker run -it -p 8181:8181 --name ldap -h ldap.cloud.com --net cloud.com sumit/ldap /bin/bash
