# Regisry Hook
- The build scripts are present in scripts/build.sh.
- The build path is set through scripts/config.
- Run build.sh to create the docker-build image:
```console
./build.sh
```
- Run run.sh to start the container:
```console
./run.sh
```
- To view logs run logs.sh:
```console
./log.sh
```
- To get container terminal run bash.sh:
```console
./bash.sh
```

## Configuration
The following table lists the configurable parameters of the docker-build and their default values.

| Parameter                   | Description                                           | Default                |
|-----------------------------|-------------------------------------------------------|------------------------|
| `BRANCH`                    | The branch of the repository                          | `master`               |
| `BUILD_PATH`                | The location where repository would be cloned         | `/tmp`                 |
| `PORT`                      | The port at which nodejs application is running.      | `5002`                 |
| `IMAGE_NAME`                | The name of the docker image.                         | `sumit/$REPO_NAME`     |
| `REPO_NAME`                 | The name of the repository in docker registry.        |                        |
| `CONTAINER_NAME`            | The name of the container.                            |                        |
