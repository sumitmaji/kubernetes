#!/bin/bash

: ${INSTALL_PATH:=/home/sumit/kubernetes/install_scripts}
source $INSTALL_PATH/../config
if [ -d ./workspace ]
then
 echo "The workspace is present!!!!!!"
else
 wget $REPOSITORY/workspace.tar.gz
 tar -xzvf workspace.tar.gz
 rm -rf workspace.tar.gz
fi
