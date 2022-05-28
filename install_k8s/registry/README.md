# Registry

Installation of local docker registry.

## Configuration

The following table lists the configurable parameters of the registry install and their default values.

| Parameter                  | Description                                                             | Default                               |
|----------------------------|-------------------------------------------------------------------------|---------------------------------------|
| `APP_HOST`                 | Hostname of the certificate.                                            | `master.cloud.com`                    |
| `MOUNT_PATH`               | The mount path where kubernetes scripts and certificates are available. | `/root`                               |

# Installation steps:
- Master:
```shell
cd /root/kubernetes/install_k8s/registry
./master.sh
```
- Worker:
```shell
cd /root/kubernetes/install_k8s/registry
./nodes.sh
```

Sample commands for build/tag/push
```shell
docker build -t sumit/base .
docker tag sumit/base master.cloud.com:5000/base
docker push master.cloud.com:5000/base
```

- Go to [registry](https://docs.docker.com/registry/deploying/) to get details about docker registry setup.
- Go to [notification](https://docs.docker.com/registry/notifications/) to setup webhook.
- Go to [configuration](https://docs.docker.com/registry/configuration/) for configuring docker registry.
