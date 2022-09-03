# LDAP

Its an open ldap installation which is integrated with kerberos to provide kerberized ssh 
feature. Using this kerberized ssh, user need to login only once and they can move across
multiple vms without being asked to login again.
- Base Dn: `dc=default,dc=svc,dc=cloud,dc=uat`
- Ldap server hostname: `ldap.default.svc.cloud.uat`
- Admin user account: `cn=admin,dc=default,dc=svc,dc=cloud,dc=uat`, password: sumit/admin
- Sample user account: `cn=smaji,ou=users,dc=default,dc=svc,dc=cloud,dc=uat`
- `bootstrap.sh` contains script for setting up ldap.
- `utility/createUser.sh` creates user in ldap.
- `utility/createGroup.sh` creates new group in ldap.
- `utility/createTokenLdif.sh` creates token for integrating kubernetes with ldap.
- `utility/setupssl.sh` enabled ssl for ldap. The certificates are present in `ldap.default.svc.cloud.uat`.
The certificates can be created via [`openssl`](https://github.com/sumitmaji/openssl) application.
- Username and Password for ldap/kerberos are pushed to pods via secrets 
(`chart/templates/ldap-secret.yaml`, `char/template/krb-secret.yaml`). These secrets are loaded
into pods as volumes and read in `bootstrap.sh`.
- `config/config` contains configuration for ldap.

# Note
[`Base`](https://github.com/sumitmaji/base/tree/trusty) image should be created first.
Ldap and [`kerberos`](https://github.com/sumitmaji/kubernetes/tree/master/install_k8s/kerberos) both should be installed. First ldap and next kerberos.

# Installation commands

```console
cd /root/kubernetes/install_k8s/ldap
./run_ldap.sh
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

- To access ldap
```console
https://master.cloud.com:31000/phpldapadmin/
username: sumit
password: sumit
```

### Usefull Links

https://wiki.ubuntuusers.de/Archiv/LDAP_Client_Authentifizierung/<br>
http://techpubs.spinlocksolutions.com/dklar/ldap.html<br>
https://www.centos.org/docs/5/html/CDS/ag/8.0/index.html<br>
https://www.server-world.info/en/note?os=Ubuntu_14.04&p=ssl<br>
https://www.lisenet.com/2014/install-and-configure-an-openldap-server-with-ssl-on-debian-wheezy/<br>
https://help.ubuntu.com/lts/serverguide/kerberos-ldap.html<br>
https://bobcares.com/blog/kerberos-and-ldap-so-strong-together/<br>
http://www.rjsystems.nl/en/2100-d6-kerberos-openldap-provider.php<br>
http://www.linux-mag.com/id/4765/<br>
https://docs.oracle.com/cd/E19253-01/816-4557/ggdqi/index.html<br>
https://help.ubuntu.com/lts/serverguide/kerberos-ldap.html<br>
http://jurjenbokma.com/ApprenticesNotes/kerberized_ssh.xhtml<br>
https://ubuntu.com/server/docs/service-kerberos-with-openldap-backend<br>
