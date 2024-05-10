# Information

## Postgresql

```console
kubectl exec -it keycloak-postgresql-0 -- /bin/bash
psql -U sumit_keycloak -d bitnami_keycloak
```

```sql
SELECT * FROM pg_catalog.pg_tables;
SELECT * FROM user_entity;
SELECT * FROM credential;
```

## Keycloak

**Admin console**
1. Url: https://kube.gokcloud.com/
2. Username: admin
3. Password: admin

**User Console**
1. Url: https://kube.gokcloud.com/realms/{realm_name}/account