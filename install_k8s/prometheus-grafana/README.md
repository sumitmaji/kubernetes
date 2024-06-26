# Prometheus and Grafana

## Installation

Note: [`Ingress Controller`](../ingress/README.md) should be installed if dashboard need to be accessible from outside the cluster.

## Gok

```console
./gok install monitoring
./gok create certificate monitoring kube
./gok patch ingress prometheus-server monitoring letsencrypt kube
./gok patch ingress grafana monitoring letsencrypt kube
```

```console
./gok reset monitoring
```

## Access UI

**Prometheus:** 

https://kube.gokcloud.com/prometheus

**Grafana:** 

https://kube.gokcloud.com/grafana
username: admin
password: admin

## Adding datasource in Grfana
![img_1.png](images/img_1.png)

![img_2.png](images/img_2.png)

![img_3.png](images/img_3.png)

![img_4.png](images/img_4.png)

## Information
- Helm
https://www.youtube.com/watch?v=bwUECsVDbMA

- Kubectl
https://www.youtube.com/watch?v=mtE4migphGE

[Learn](https://k21academy.com/docker-kubernetes/prometheus-grafana-monitoring/)

Architecture Diagram
![img.png](images/img.png)

**Prometheus Server:** The main server which stores and scrapes time series data.

**TSDB(Time Series Database):** Metrics are a critical aspect of any system to understand its health and operational state. Design of any system requires collection, storage and reporting of metrics to provide a pulse of the system. Data is stored over a series of time intervals and needs an efficient database to store and retrieve this data.OpenTSDB Time Series Database is one such time series database that can serve that need.

**PromQL:** Prometheus defines a rich query language in the form of PromQL to query data from the time series database.

**Pushgateway:** Available to support short lived jobs.

**Exporters:** They are used to promoting metrics data to the prometheus server.

**Alertmanager:** Used to send notifications to various communication channels like slack, email to notify users.

https://www.youtube.com/watch?v=h4Sl21AKiDg

## Keycloak integration
https://medium.com/@charled.breteche/securing-grafana-with-keycloak-sso-d01fec05d984
https://medium.com/@iamestelleyu/using-keycloak-in-grafana-228010ef3735
https://scottaubrey.info/blog/2024-03-05-grafana-oauth2-proxy/
https://stackoverflow.com/questions/70975460/is-there-a-way-to-configure-sso-oauth2-prometheus-via-nginx-ingress-and-oauth2-p
https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/keycloak/