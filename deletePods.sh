#!/bin/bash

kubectl delete deployment ldap-deployment
kubectl delete service ldap

kubectl delete deployment kerberos-deployment
kubectl delete service kerberos

kubectl delete deployment ldap-client-deployment
kubectl delete service ldap-client

kubectl delete deployment ldap-client1-deployment
kubectl delete service ldap-client1

kubectl delete deployment hadoop-deployment
kubectl delete service hdfs-master

kubectl delete deployment hadoop-slave01-deployment
kubectl delete service slave01

kubectl delete deployment hive-deployment
kubectl delete service hive
