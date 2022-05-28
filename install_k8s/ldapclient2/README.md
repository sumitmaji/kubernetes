# LDAP Client

Ldap client is the base image which incorporates both ldap and kerberos. Using this client we can
login to other vms via single signon.
- `utility/bootstrap.sh` contains script for setting up ldap client.
- `config/config` contains configuration for ldap client.

# Note
[`Ldap`](https://github.com/sumitmaji/kubernetes/tree/master/install_k8s/ldap)
and [`kerberos`](https://github.com/sumitmaji/kubernetes/tree/master/install_k8s/kerberos)
both should be installed. First ldap and next kerberos. Only after that ldapclient should be
installed.

# Installation commands

```console
cd /root/kubernetes/install_k8s/ldapclient2
./run_ldapclient2.sh
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