#!/usr/bin/env bash
[[ "TRACE" ]] && set -x

kubectl apply -f scripts/rbac.yaml
#helm init --service-account tiller
helm version
helm repo add stable https://charts.helm.sh/stable
helm repo update

npm start
