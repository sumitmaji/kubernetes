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
./gok install ingress
```

## To enable authentication in Ingress
In order to enable authentication of application accessed via ingress controller, you need to put
below tags in annotation secret of ingress resource

`nginx.ingress.kubernetes.io/auth-signin: https://master.cloud.com:32028/authenticate`
`nginx.ingress.kubernetes.io/auth-url: https://master.cloud.com:32028/check`

- Here `https://master.cloud.com:32028` is the host and port where ingress controller is running.
- The `/check` api returns 200 (OK) if the user is authenticated, otherwise it returns 401 (Unauthorized).
- Once `/authenticate` api presents user with login page, and on successful authentication redirects user to 
the target page present in the `Referrer` field in header of the request.

#### Note: 
[`Kubeauthentication`](https://github.com/sumitmaji/kubeauthentication) service must be running for
this work.

#### Below is the flow performed by ingress
1. User tries to access protected resource, e.g. https://master.cloud.com:32028/app1.
2. Ingress calls api present in `auth-url` to check whether the user is authenticated.
   1. If Not Authenticated: redirect the request to the url present in `auth-signin` along with 
   `rd=https://master.cloud.com:32028/app1` as its query parameter.
   https://master.cloud.com:32028/authenticate? `rd=https://master.cloud.com:32028/app1`
      1. The above redirect url presents the login page, which upon authentication redirects user
      to the target page present in the `Referrer` field in the header of the request.
      2. After redirection, the ingress again calls the `/check` api to validate if the user is 
      authenticated. This time since use is authenticated in previous step, the request is forwarded
      to backend.
   2. If Authenticated, then forward the request to the backend.

#### Please check the [`link`](https://mac-blog.org.ua/kubernetes-oauth2-proxy) containing good explanation.

## Description
The [install_ingress.sh](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh) 
file contains scripts to install ingress in kubernetes cluster. It first [deletes](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L8)
the ingress certificates that would be used in the ingress resource for ssl connection and sample apps.

Next it would [install](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L12) 
certificates for ingress user named `ingress` and group named `ingress:master`. 

It [deploys](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L23) ingress controller.

It then [creates](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/install_ingress.sh#L12) 
the certificates that would be used in ingress resource for ssl connection. Finally, it creates the sample 
app resources.

All apps deployed in default namespace use `appingress-certificate` certificate.

After the installation is completed you should see below resources
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img.png)

We need to know the port where ingress-controller is running, which would used to access 
ingress apps from outside. The highlighted text in the below screenshot is port number
where ingress controller is running.
```console
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img_1.png)

Inorder to access apps via ingress
1. Update /etc/hosts file in your system to point to the ip address of the vm where ingress controller is running.
![alt text](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/ingress/images/img_2.png)
2. Open browser and access https://master.cloud.com:32028/app1


# Notes
- To access nginx ui

```console
http://master.cloud.com:32028/nginx_status
```

# Integate with Keycloak
https://stackoverflow.com/questions/75694040/how-to-configure-nginx-ingress-rules-with-keycloak
https://docs.syseleven.de/metakube/de/tutorials/setup-ingress-auth-to-use-keycloak-oauth
https://www.keycloak.org/server/reverseproxy
https://medium.com/@ankit.wal/authenticate-requests-to-apps-on-kubernetes-using-nginx-ingress-and-an-authservice-37bf189670ee
https://www.gresearch.com/news/securing-kubernetes-services-with-oauth2-oidc/
