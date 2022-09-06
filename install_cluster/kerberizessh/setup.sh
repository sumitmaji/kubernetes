


echo "kerberos krb5-config/default_realm string ${DOMAIN_NAME}" | debconf-set-selections

# kerberos client and pam configuration for kerberos
LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -yq krb5-user libpam-krb5

# Kerberize sshd
apt-get install -yq libsasl2-modules-gssapi-mit

utility/bootstrap.sh
