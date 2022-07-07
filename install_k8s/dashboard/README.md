# Kubernetes Dashboard

Installation of Kubernetes Dashboard

## Configuration

TODO

## Installation Steps

```console
cd /root/kubernetes/install_k8s/
./install_dashboard.sh
```

Note: [`Ingress Controller`](../ingress/README.md) should be installed if dashboard need to be accessible from outside the cluster.

## Accessing Kubernetes Dashboard

```text
https://master.cloud.com:32000/dashboard/
```

## Generating token for login to dashboard

- Generate role and user
```shell
cd /root/kubernetes/dashboard/
./create-sample-user.sh
```

- Get the token
```shell
cd /root/kubernetes/dashboard/
./get-sample-user-token.sh
```
