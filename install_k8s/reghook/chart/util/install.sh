#!/bin/bash

release=$(<release)

helm install /export/helm-charts/incubator/reghook --name $release
