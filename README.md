# kubernetes

Installation of kubernetes cluster in private cloud using kubeadm.

## Configuration

The following table lists the configurable parameters of the kubernetes cluster install and their default values.

| Parameter                   | Description                                                                                                                                                                                  | Default                               |
|-----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| `CLUSTER_NAME`              | Kubernetes cluster name                                                                                                                                                                      | `cloud.com`                           |
| `MOUNT_PATH`                | The mount path where kubernetes scripts and certificates are available.                                                                                                                      | `/root`                               |
| `DNS_DOMAIN`                | The domains where vms are hosted.                                                                                                                                                            | `cloud.uat`                           |
| `CERTIFICATE_PATH`          | The path where certificates are present.                                                                                                                                                     | `/etc/kubernetes/pki`                 |
| `SERVER_DNS`                | The comma separated dns names where kubernetes master would be running, this also includes name of the kubernetes api service dns names, the dns name where ha proxy is running              | `master.cloud.com..`                  |
| `SERVER_IP`                 | The comma separated list of all the ip addresses where master and ha proxy would be running (actual & virtual). This should also include the ip addess of kubernetes cluster api service ip. | `11.0.0.1,..`                         |
| `HA_PROXY_PORT`             | Port of HA Proxy.                                                                                                                                                                            | `6443`                                |
| `HA_PROXY_HOSTNAME`         | IP/Hostname where HA Proxy running.                                                                                                                                                          | `11.0.0.1`                            |
| `LOAD_BALANCER_URL`         | Endpoint of HA Proxy.                                                                                                                                                                        | `11.0.0.1:6443`                       |
| `APP_HOST`                  | Hostname that would be put in ingress.                                                                                                                                                       | `master.cloud.com`                    |
| `API_SERVERS`               | List of api servers which are used in creating certificates for ha proxy.                                                                                                                    | `11.0.0.1:master.clud.com,..`         |
| `OIDC_ISSUE_URL`            | OpenID Connect issuer url.                                                                                                                                                                   | `https://skmaji.auth0.com/`           |
| `OIDC_CLIENT_ID`            | OpenID Connect Application ID.                                                                                                                                                               | `Client ID`                           |
| `OIDC_USERNAME_CLAIM`       | Field name in the ID Token for username claim.                                                                                                                                               | `sub`                                 |
| `OIDC_GROUPS_CLAIM`         | Field name in the ID Token for group claim.                                                                                                                                                  | `http://localhost:8080/claims/groups` |


# Installation steps:

- Install Cluster

```console
cd /root/kubernetes/install_cluster
./install_master_node.sh
```

- Install kubernetes:

  - Master:

  ```console
  cd /root/kubernetes/install_k8s
  ./install-k8s.sh
  ```

  - Worker:

  ```console
  cd /root/kubernetes/install_k8s
  ./install-k8s-worker.sh
  ```

  - To join a worker node:
  
  ```shell script
  sodo kubeadm join master_ip:master_port --token token_id --discovery-token-ca-cert-hash hash_cert
  ```

  - To remoave a kubernetes setup:
  
  ```shell script
  kubeadm reset
  ```
  
  - To create a new join token
  
  ```shell script
  kubeadm token create print-join-command
  ```
When you reboot the vms, the kubelet service may not run, you need to restart the kubelet.
```shell
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

systemctl stop kubelet
syatemctl start kubelet
```
### Other begging steps
```shell
systemctl status kubelet
journalctl -u kubelet
```


# Useful commands:

- To change namespace

```console
alias kcd='kubectl config set-context $(kubectl config current-context) --namespace'
kcd name_space
```

- Inorder to login via OpenId Connect username/password

```console
alias kctl='kubectl --kubeconfig=/root/oauth.conf --token=$(python3 /root/kubernetes/install_k8s/kube-login/cli-auth.py)'
```

In order to use the above approach, you must install and run
1. Ingress [Instress ReadME]()
2. Kubeauthentication service [KubeAuth ReadME]()


- To enable verbose(logging) of kubectl command

```console
kubectl get pods --v 6
```

# Useful commands

```console
kubectl top nodes --v 6
```
```console
kubectl get pod, svc, hpa -owide
watch -n1 !!
```
```console
kubectl get componentstatus
```

# Setup required to use ingress

- Enable port forwarding to ingress service ports from master vm

```console
iptables -t nat -A PREROUTING -p tcp --dport 30000 -j DNAT --to-destination 11.0.0.2:30000 # http
iptables -t nat -A PREROUTING -p tcp --dport 32000 -j DNAT --to-destination 11.0.0.2:32000 # nginx ui
iptables -t nat -A PREROUTING -p tcp --dport 31000 -j DNAT --to-destination 11.0.0.2:31000 # https
```

- Add ca.crt and server.crt file in chrome browser, please refer [link](https://support.globalsign.com/customer/portal/articles/1211541-install-client-digital-certificate---windows-using-chrome) on how to add certificate. Add server.crt in `Other People` tab and ca.crt in `Trusted Root Certificate Authority` tab.

- Add `ip_address master.cloud.com` to windows host file located in C:\Windows\System32\drivers\etc. e.g. `192.168.1.5 master.cloud.com` >> host file.

# Notes
- To access nginx ui

```console
http://master.cloud.com:32000/nginx_status
```

- To access kubernetes dashboard

```console
https://master.cloud.com/api/v1/namespaces/kube-system/services/http:kubernetes-dashboard:/proxy/
username: admin
password: admin
```

- To access ldap

```console
https://master.cloud.com:31000/phpldapadmin/
username: sumit
password: sumit
```