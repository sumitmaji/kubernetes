# Kubernetes Dashboard

Installation of Kubernetes Dashboard

## Configuration

TODO

## Installation Steps

```shell
cd /root/kubernetes/install_k8s/
./gok install dashboard
```

## Uninstallation Steps
```shell
cd /root/kubernetes/install_k8s/
./gok reset dashboard
```

```console

Note: [`Ingress Controller`](../ingress/README.md) should be installed if dashboard need to be accessible from outside the cluster.

## Installation steps using gok using letsencrypt
```console
./gok install dashboard
./gok create certificate kubernetes-dashboard kube
./gok patch ingress kubernetes-dashboard kubernetes-dashboard letsencrypt kube
```


## Accessing Kubernetes Dashboard

```text
https://master.cloud.com:32000/dashboard/
```

## Generating token for login to dashboard

- Generate role and user
```shell
cd /root/kubernetes/install_k8s/dashboard/
./create-sample-user.sh
```

- Get the token
```shell
cd /root/kubernetes/install_k8s/dashboard/
./get-sample-user-token.sh
```
