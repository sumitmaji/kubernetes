# Opensearch

## Documentation
- [Opensearch](https://opensearch.org/docs/latest/install-and-configure/install-opensearch/helm/)
- [Opensearch Dashboard](https://artifacthub.io/packages/helm/opensearch-project-helm-charts/opensearch-dashboards)

## Install

```shell
./gok install opensearch
```

![img_5.png](img_5.png)

## Uninstall

```shell
./gok reset opensearch
```

## Setup

**Note:** Before beginning setup, make sure [fluentd](../fluentd/README.md) service has been started.

- Switch tenant as Admin
- Click on `Discover`

![img.png](img.png)

- Click on `Create Index Pattern`

![img_1.png](img_1.png)

- Filter the `fluentd` index and click on next

![img_2.png](img_2.png)

- Click on create index pattern

![img_3.png](img_3.png)

- Select `Discover` again, you should be able to view container logs under fluentd index.

![img_4.png](img_4.png)