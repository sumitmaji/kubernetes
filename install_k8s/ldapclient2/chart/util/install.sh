#!/bin/bash

release=$(<release)

helm install /export/helm-charts/incubator/ldap --name $release 
