#!/bin/bash

count=`exec docker ps -aq | wc -l`
#echo "The count is $count"
if [ $count -ne "0" ]
then
echo "STOPPING THE DOCKER CONTAINERS!!!!!!"
docker stop $(docker ps -aq)
echo "REMOVING THE DOCKER CONTAINERS!!!!!!"
docker rm $(docker ps -aq)
echo "PROCESS SUCCESSFUL!!!!!!!!!!!!!!!!!!"
else
echo "No contiainers to remove!!!!!!!!!!!!"
fi
