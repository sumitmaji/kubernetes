# GitHook

Installation of Github webhook. This service would capture the push events coming from github
when a commit is made on a repository. The service would then capture the repository name,
branch name and repository url and push it to the docker webhook service for triggering docker
build.

- The port number the service is listening is `5001`.
- Kubernetes service port (Node Port) `32501` which is exposed to outside. This is the port which
github would push the payload.
- The end which would receive the push messages `/payload`.
- Hostname is `githook.default.svc.cloud.uat`.
- The application code is present in [`server/index.js`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/githook/server/index.js).
- The configuration files for build and push is present in [`config`](https://github.com/sumitmaji/kubernetes/blob/master/install_k8s/githook/config) file.

## Configuration

The following table lists the configurable parameters of the registry install and their default values.

| Parameter                  | Description                                                             | Default                               |
|----------------------------|-------------------------------------------------------------------------|---------------------------------------|
| `APP_HOST`                 | Hostname of the certificate.                                            | `master.cloud.com`                    |
| `MOUNT_PATH`               | The mount path where kubernetes scripts and certificates are available. | `/root`                               |


# Installation steps:
```console
cd /root/kubernetes/install_k8s/githook
chmod +x *.sh
./run_githook.sh
```

- To view logs run logs.sh:
```console
cd /root/kubernetes/install_k8s/githook/chart/util
./log.sh
```
- To get container terminal run bash.sh:
```console
cd /root/kubernetes/install_k8s/githook/chart/util
./bash.sh
```
- To manually push messages to githook service:
```console
cd /root/kubernetes/install_k8s/githook
./postToGithook.sh -b __BRANCH__NAME -a __REPOSITORY_NAME__
```

# Steps to setup webhook in github
1. Go to you repository where to need to setup webhook and receive notification.
e.g. https://github.com/sumitmaji/hlwspring
2. Click on `Settings` tab.
3. Click on `Webhook` menu on the left-hand side of the page.
4. Click on `Add webhook` button.
    - Fill the payload url. This should be host where githook service is running, port number
which was export by node port(`32501`) and the endpoint of the githook service listening for messages
. e.g. http://HostIP:32501/payload
    - Content type should be `application/json`.
    - Generate secret, copy it and put it in `.env` file under `GITHUB_SECRET`. You can always change
the secret.
    - Select `Just the push event` radio button.
    - Click on `Add webhook` button at the bottom.