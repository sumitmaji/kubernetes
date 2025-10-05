#!/bin/bash

if [[ $1 == "-d" ]]; then
  while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
su - hduser -c "/bin/bash"
fi

if [[ $1 == "-ssh" ]]; then
/usr/sbin/sshd -D
fi

