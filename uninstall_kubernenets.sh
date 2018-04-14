#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config

kubectl delete --all deployments -n kube-system
kubectl delete --all services -n kube-system
kubectl delete --all rc -n kube-system

kubectl delete --all deployments
kubectl delete --all services
kubectl delete --all rc

/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_flannel.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_kubelets.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_kube_scheduler.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_kube_controller_manager.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_kube_api_server.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_etcd.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_kubeconfig.sh
/bin/bash $INSTALL_PATH/../uninstall_script/uninstall_binaries.sh
