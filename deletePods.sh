#!/bin/bash

kubectl delete deployment ldap-deployment
kubectl delete service ldap

kubectl delete deployment kerberos-deployment
kubectl delete service kerberos

kubectl delete deployment ldap-client-deployment
kubectl delete service ldap-client

