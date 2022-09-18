#!/bin/bash

release=$(<release)

helm install /export/helm-charts/incubator/dockerhook --name $release
