# DockerHook

Installation of Docker webhook. This service would capture the push events coming from githook service. 
The service would then capture the repository name, branch name and repository url and trigger a docker build . Once the
build is completed and image is pushed into local docker registry. Afterwards the service would send notification 
reghook service to deploy the image to kubernetes cluster.

Once it receives a push message it runs the [`build.sh`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/dockerhook/scrips/build.sh)
to trigger the Docker build. It has [`config`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/dockerhook/scrips/config)
file which mentions what would be port number (`APP_PORT`) image should expose or application should run. Depending on the type of
application it would trigger docker build using different docker file. The service would expect the 
repository would provide below details in the `configuration` file present at the root of the 
repository
`BUILD_TYPE`, `APP_SRC_CODE`, `MAIN_CLASS`


| Parameter                  | Description                                                    | Default  |
|----------------------------|----------------------------------------------------------------|----------|
| `BUILD_TYPE`               | Technology stack of the application.`REACT`, `NODE`, `SPRING`  |          |
| `APP_SRC_CODE`             | Path where application source code is present.                 | `server` |
| `MAIN_CLASS`               | In case of springboot application, fully qualified main class. |          |


- The port number the service is listening is `5002`.
- The end which would receive the push messages `/process`.
- Hostname is `dockerhook.default.svc.cloud.uat`.
- The application code is present in [`server/index.js`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/dockerhook/server/index.js).
- The configuration files for build and push is present in [`config`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/dockerhook/config) file.

## Configuration

The following table lists the configurable parameters of the registry install and their default values.

| Parameter                  | Description                                                             | Default                               |
|----------------------------|-------------------------------------------------------------------------|---------------------------------------|
| `APP_HOST`                 | Hostname of the certificate.                                            | `master.cloud.com`                    |
| `MOUNT_PATH`               | The mount path where kubernetes scripts and certificates are available. | `/root`                               |


# Installation steps:
```console
cd /root/kubernetes/install_k8s/dcokerhook
chmod +x *.sh
./run_dockerhook.sh
```

- To view logs run logs.sh:
```console
cd /root/kubernetes/install_k8s/dockerhook/chart/util
./log.sh
```
- To get container terminal run bash.sh:
```console
cd /root/kubernetes/install_k8s/dockerhook/chart/util
./bash.sh
```