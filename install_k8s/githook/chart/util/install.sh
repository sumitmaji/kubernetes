#!/bin/bash

release=$(<release)

helm install /export/helm-charts/incubator/githook --name $release
