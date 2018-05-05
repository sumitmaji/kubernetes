# kubernetes

Installation of kubernetes cluster in private cloud.

## Configuration

The following table lists the configurable parameters of the drone charts and their default values.

| Parameter           | Description                                                                                           | Default                     |
|---------------------|-------------------------------------------------------------------------------------------------------|-----------------------------|
| `ENABLE_DEBUG`      | To enable debug mode for the scripts.                                                                 | `true`                      |
| `MOUNT_PATH`        | The mount path where kubernetes scripts and certificates are available.                               | `/export`                   |
| `INSTALL_PATH`      | The directory where kubernetes installation scripts are available.                                    | `$MOUNT_PATH/kubernetes/install_scripts_secure` |
| `REPOSITORY`        | The url where kubernetes binaries are present.                                                        | `http://192.168.1.5`        |
| `HOSTINTERFACE`     | The host interface name of node                                                                       | `eth0`                      |
| `HOSTIP`            | IP Address of the host.                                                                               | `Retrieved via script`      |
| `WORKDIR`           | The temporary installation path for kubernetes components.                                            | `/export/tmp`               |



Useful links:<br>
https://kubernetes.io/docs/tasks/tools/install-kubectl/<br>
https://medium.com/@TarunChinmai/installing-kubernetes-f0c8dec1487c<br>
https://medium.com/@felipedutratine/kubernetes-on-local-with-minikube-tutorial-413475d587e6<br>
https://www.techrepublic.com/article/how-to-quickly-install-kubernetes-on-ubuntu/<br>
https://blog.alexellis.io/kubernetes-in-10-minutes/<br>
https://github.com/dannyaj/Install-Kubernetes-on-Ubuntu-16.04<br>
https://hxquangnhat.com/2016/12/21/tutorial-deploy-a-kubernetes-cluster-on-ubuntu-16-04/<br>
http://www.dasblinkenlichten.com/kubernetes-101-networking/<br>
http://leebriggs.co.uk/blog/2017/02/18/kubernetes-networking-calico.html<br>
http://docker-k8s-lab.readthedocs.io/en/latest/docker/bridged-network.html<br>
http://network-insight.net/2016/06/kubernetes-networking-101/<br>
http://blog.oddbit.com/2014/08/11/four-ways-to-connect-a-docker/<br>
https://blog.laputa.io/kubernetes-flannel-networking-6a1cb1f8ec7c<br>
https://ahmet.im/blog/kubernetes-network-policy/<br>
https://icicimov.github.io/blog/kubernetes/Kubernetes-cluster-step-by-step/ <br>
https://developer.epages.com/blog/tech-stories/how-to-setup-a-ha-kubernetes-cluster-worker-components-and-skydns/ <br>
https://github.com/trondhindenes/Kubernetes-Auth0 <br>
https://github.com/wardviaene/advanced-kubernetes-course <br>
