# LDAP

Ldap active directory for user authentication

# Installing the Chart

To install the chart with the release name `ldap`

```console
$ helm install incubator/ldap --name ldap
```

# Uninstalling the Chart

To uninstall/delete the `ldap` deployment:

- The command removes all the Kubernetes components associated with the chart and deletes the release.

```console
$ helm delete --purge ldap
```

- The command removes nearly all the Kubernetes components associated with the chart and deletes the release.

```console
$ helm delete ldap
```

## Configuration

The following table lists the configurable parameters of the drone charts and their default values.

| Parameter                   | Description                                                                                   | Default                     |
|-----------------------------|-----------------------------------------------------------------------------------------------|-----------------------------|
| `replicaCount`              | No of pods                                                                                    | `1`                         |
| `image.repository`          | Docker repository path                                                                        | `master.cloud.com:5000/ldap` |
| `image.tag`                 | Docker repository version                                                                     | `latest`                    |
| `image.pullPolicy`          | How the image would be pulled from docker repository                                          | `IfNotPresent`              |
| `ingress.enabled`           | Should ingress be enabled                                                                     | `true`                      |
| `ingress.path`              | The route of ldap home page (login page)                                                      | `/phpldapadmin`             |
| `ingress.hosts`             |                                                                                               | `master.cloud.com`          |
| `ingress.tls.secretName`    | SSL secret                                                                                    | `ingress-certificate`       |
| `ingress.tls.hosts`         |                                                                                               | `master.cloud.com`          |
