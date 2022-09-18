#!/bin/bash

#[[ "TRACE" ]] && set -x

if [ ! -f ~/.user ]; then
 if [ ! -z $USER ]; then
 if [ $USER != 'root' ]; then
 touch ~/.user
 mkdir ~/.ssh
 ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa
 cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
 cp /container/scripts/ssh_config ~/.ssh/config
 chmod 600 ~/.ssh/config
 echo "GSSAPIDelegateCredentials yes" >> ~/.ssh/config
 echo "GSSAPIRenewalForcesRekey yes" >> ~/.ssh/config
 
 ###Additional in future
 
 fi
 fi
fi 

