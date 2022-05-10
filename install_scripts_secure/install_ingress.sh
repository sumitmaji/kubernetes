
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR
mkdir -p ingress
pushd ingress

cp -r $INSTALL_PATH/../kube_service/ingress/* .
APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

if [ $ENABLE_KUBE_SSL == 'true' ]
then
  KUBECONFIG="$(echo '/var/lib/'"$INGRESS_HOST"'/kubeconfig' | sed 's/\//\\\//g')"
  sed -i "s/\$KUBECONFIG/$KUBECONFIG/" nginx-ingress-controller-deployment.yaml
else
  sed -i "/\$KUBECONFIG/ s/^/#/" nginx-ingress-controller-deployment.yaml
fi

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" nginx-ingress-controller-deployment.yaml

sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" nginx-ingress-controller-deployment.yaml

sed -i "s/\$INGRESS_HOST/$INGRESS_HOST/" nginx-ingress.yaml
sed -i "s/\$INGRESS_HOST/$INGRESS_HOST/" nginx-ingress-controller-deployment.yaml
sed -i "s/\$INGRESS_HOST/$INGRESS_HOST/" example/app-ingress.yaml

kubectl create namespace ingress
kubectl create -f default-backend-deployment.yaml -f default-backend-service.yaml -n=ingress
kubectl create secret tls ingress-certificate --key /export/kubecertificate/certs/${INGRESS_HOST}.key --cert /export/kubecertificate/certs/${INGRESS_HOST}.crt -n ingress
kubectl create secret tls ingress-certificate --key /export/kubecertificate/certs/${INGRESS_HOST}.key --cert /export/kubecertificate/certs/${INGRESS_HOST}.crt -n default
kubectl create -f ssl-dh-param.yaml
kubectl create -f nginx-ingress-controller-config-map.yaml -n=ingress
kubectl create -f nginx-ingress-controller-roles.yaml -n=ingress
kubectl create -f nginx-ingress-controller-deployment.yaml -n=ingress
kubectl create -f nginx-ingress.yaml -n=ingress
kubectl create -f nginx-ingress-controller-service.yaml -n=ingress

output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -ojsonpath='{.items[0].status.containerStatuses[0].ready}'`
echo "$output"
while [ "$output" != "true" ]; do
    echo "Ingress controller service is not up, will check again after 5seconds"
    sleep 5
    output=`kubectl get po -n ingress-nginx -l app.kubernetes.io/component=controller -ojsonpath='{.items[0].status.containerStatuses[0].ready}'`
done

#Example app
kubectl create -f example/



popd
popd
