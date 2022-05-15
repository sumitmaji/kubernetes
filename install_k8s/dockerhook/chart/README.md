# LDAP

Ldap active directory for user authentication

# Installing the Chart

To install the chart with the release name `dockerhook`

```console
$ helm install incubator/dockerhook --name dockerhook
```

# Uninstalling the Chart

To uninstall/delete the `dockerhook` deployment:

- The command removes all the Kubernetes components associated with the chart and deletes the release.

```console
$ helm delete --purge dockerhook
```

- The command removes nearly all the Kubernetes components associated with the chart and deletes the release.

```console
$ helm delete dockerhook
```

## Configuration

The following table lists the configurable parameters of the drone charts and their default values.

| Parameter                   | Description                                                                                   | Default                     |
|-----------------------------|-----------------------------------------------------------------------------------------------|-----------------------------|
| `replicaCount`              | No of pods                                                                                    | `1`                         |
| `image.repository`          | Docker repository path                                                                        | `master.cloud.com:5000/dockerhook` |
| `image.tag`                 | Docker repository version                                                                     | `latest`                    |
| `image.pullPolicy`          | How the image would be pulled from docker repository                                          | `IfNotPresent`              |
| `ingress.enabled`           | Should ingress be enabled                                                                     | `true`                      |
| `ingress.path`              | The route of dockerhook home page (login page)                                                      | `/phpdockerhookadmin`             |
| `ingress.hosts`             |                                                                                               | `master.cloud.com`          |
| `ingress.tls.secretName`    | SSL secret                                                                                    | `ingress-certificate`       |
| `ingress.tls.hosts`         |                                                                                               | `master.cloud.com`          |
