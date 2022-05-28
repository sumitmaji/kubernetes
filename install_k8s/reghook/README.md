# RegHook

Installation of application installation webhook. This service would capture the push events coming from dockerhook service.
The service would then capture the repository name, branch name and repository url and trigger helm commands.

Once it receives a push message it runs the [`build.sh`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/reghook/scripts/build.sh)
to trigger the Docker build. It has [`config`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/reghook/scripts/config)
file which mentions what would be port number (`APP_PORT`) where service should run. The service would expect the
repository would provide below details in the `configuration` file present at the root of the repository
`APPNAME`, `CONTEXT`, `VERSION`, `DEPLOY`, `RELEASE_NAME`.

The application has a common [`chart`](https://github.com/sumitmaji/kubernetes/tree/master/install_k8s/reghook/scripts/chart) that would be applied to the application. 


| Parameter                 | Description                                                    | Default |
|---------------------------|----------------------------------------------------------------|---------|
| `APPNAME`                 | Name of the application. e.g. hlw                              |         |
| `CONTEXT`                 | Path to be put in ingress. e.g. hlw                            |         |
| `VERSION`                 | Version number of the application.                             |         |
| `DEPLOY`                  | Whether application should be deployed or not. e.g. true/false |         |
| `RELEASE_NAME`            | Name of the release used in helm install command               |         |

- The port number the service is listening is `5003`.
- The end which would receive the push messages `/deploy`.
- Hostname is `reghook.default.svc.cloud.uat`.
- The application code is present in [`server/index.js`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/reghook/server/index.js).
- The configuration files for build and push is present in [`config`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/reghook/config) file.



## Configuration

The following table lists the configurable parameters of the registry install and their default values.

| Parameter                  | Description                                                             | Default                               |
|----------------------------|-------------------------------------------------------------------------|---------------------------------------|
| `APP_HOST`                 | Hostname of the certificate.                                            | `master.cloud.com`                    |
| `MOUNT_PATH`               | The mount path where kubernetes scripts and certificates are available. | `/root`                               |


# Installation steps:
```console
cd /root/kubernetes/install_k8s/reghook
chmod +x *.sh
./run_reghook.sh
```

- To view logs run logs.sh:
```console
cd /root/kubernetes/install_k8s/reghook/chart/util
./log.sh
```
- To get container terminal run bash.sh:
```console
cd /root/kubernetes/install_k8s/reghook/chart/util
./bash.sh
```