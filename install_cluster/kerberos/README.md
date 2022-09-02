# Kerberos

Using this kerberized ssh, user need to login only once and they can move across
multiple vms without being asked to login again.
- Admin user: admin, password: admin
- `config.sh` contains script for setting up kerberos.
- Username and Password for ldap/kerberos are pushed to pods via secrets
  (`chart/templates/ldap-secret.yaml`, `char/template/krb-secret.yaml`). These secrets are loaded
  into pods as volumes and read in `bootstrap.sh`.
- `config` contains configuration for ldap.

# Note
[`Base`](https://github.com/sumitmaji/base/tree/trusty) image should be created first.
[`Ldap`](https://github.com/sumitmaji/kubernetes/tree/master/install_k8s/ldap) and kerberos both should be installed. First ldap and next kerberos.

# Installation commands

```console
cd /root/kubernetes/install_k8s/kerberos
./run_kerberos.sh
```

- Inorder to access pod
```console
cd chart/util
./bash.sh
```

- Inorder to access logs
```console
ch char/util
./logs.sh
```