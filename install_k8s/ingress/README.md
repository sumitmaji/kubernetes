# Ingress Nginx

Installation of Ingress Nginx controller.

## Configuration

The following table lists the configurable parameters of the ingress nginx controller install and their default values.

| Parameter                  | Description                                                                                                                                                                                  | Default                               |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| `APP_HOST`                 | Hostname to be used in ingress resource                                                                                                                                                      | `master.cloud.com`                    |
| `MOUNT_PATH`               | The mount path where kubernetes scripts and certificates are available.                                                                                                                      | `/root`                               |

# Installation steps:

- Install Ingress

```console
cd /root/kubernetes/install_k8s/
./install_ingress.sh
```

## Description
The [install_ingress.sh](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh) 
file contains scripts to install ingress in kubernetes cluster. It first [deletes](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L8)
the ingress certificates that would be used in the ingress resource for ssl connection and sample apps.

Next it would [install](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L12) 
certificates for ingress user named `ingress` and group named `ingress:master`. 

It [deploys](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L23) ingress controller.

It then [creates](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L12) 
the certificates that would be used in ingress resource for ssl connection. Finally it creates the sample 
app resources.

All apps deployed in default namespace use `appingress-certificate` certificate.

After the installation is completed you should see below resources
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img.png)

We need to know the port where ingress-controller is running, which would used to access 
ingress apps from outside. The highlighted text in the below scren shot is port number
where ingress controller is running.
```shell
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img_1.png)

Inorder to access apps via ingress
1. Update /etc/hosts file in your system to point to the ip address of the vm where ingress controller is running.
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img_2.png)
2. Open browser and access https://master.cloud.com:32028/app1