#!/bin/bash

kubectl delete deployment ldap-deployment
kubectl delete service ldap

kubectl delete deployment kerberos-deployment
kubectl delete service kerberos
