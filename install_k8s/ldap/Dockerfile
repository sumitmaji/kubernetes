FROM master.cloud.com:5000/base-trusty
MAINTAINER Sumit Kumar Maji

# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d

ARG DEBIAN_FRONTEND=noninteractive
ARG LDAP_DOMAIN
ARG LDAP_ORG=CloudInc
ARG LDAP_HOSTNAME
ARG LDAP_PASSWORD
ARG BASE_DN

RUN echo "ldap domain: $LDAP_DOMAIN"
RUN echo "ldap hostname: $LDAP_HOSTNAME"
RUN echo "ldap base_dn: $BASE_DN"
RUN echo "LDAP_PASSWORD: $LDAP_PASSWORD"

ENV DEBIAN_FRONTEND noninteractive

# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -yq apt debconf
RUN apt-get upgrade -yq
RUN apt-get -y -o Dpkg::Options::="--force-confdef" upgrade
RUN apt-get -y dist-upgrade

RUN echo "slapd slapd/internal/adminpw password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/internal/generated_adminpw password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/password2 password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/password1 password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/domain string ${LDAP_DOMAIN}" | debconf-set-selections
RUN echo "slapd shared/organization string ${LDAP_ORG}" | debconf-set-selections
RUN echo "slapd slapd/backend string HDB" | debconf-set-selections
RUN echo "slapd slapd/purge_database boolean true" | debconf-set-selections
RUN echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
RUN echo "slapd slapd/allow_ldap_v2 boolean false" | debconf-set-selections
RUN echo "slapd slapd/no_configuration boolean false" | debconf-set-selections
RUN echo "slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION" | debconf-set-selections
RUN echo "slapd slapd/dump_database select when needed" | debconf-set-selections


RUN LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes slapd ldap-utils

RUN apt-get install -yq phpldapadmin
ADD setup.sh /etc/setup.sh
RUN /bin/bash -c "/etc/setup.sh $LDAP_HOSTNAME $BASE_DN"

# Set FQDN for Apache Webserver
RUN echo "ServerName ${LDAP_HOSTNAME}" > /etc/apache2/conf-available/fqdn.conf
RUN a2enconf fqdn

#RUN service apache2 restart
#ARG BASE_DN=

RUN echo "ldap-auth-config ldap-auth-config/rootbindpw password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/bindpw password ${LDAP_PASSWORD}" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/dblogin boolean false" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/override boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap:///$LDAP_HOSTNAME" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/pam_password string md5" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/dbrootlogin boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=net" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/ldap_version string 3" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/move-to-debconf boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/base-dn string $BASE_DN" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/rootbinddn string cn=admin,$BASE_DN" | debconf-set-selections

ADD krb-ldap-config /etc/auth-client-config/profile.d/krb-ldap-config
RUN apt-get install -yq ldap-auth-client nscd krb5-user libpam-krb5 libpam-ccreds
RUN auth-client-config -a -p krb_ldap
ADD setupClient.sh /etc/setupClient.sh
RUN /bin/bash -c "/etc/setupClient.sh"
#ADD ldap.secret /etc/ldap.secret
RUN echo "$LDAP_PASSWORD" > /etc/ldap.secret
RUN chmod 600 /etc/ldap.secret
RUN adduser openldap sudo
RUN echo openldap:openldap | chpasswd
RUN chown -R openldap:openldap /var/lib/ldap

RUN chown -R openldap:openldap /etc/ldap

RUN chgrp openldap /etc/init.d/slapd
RUN chmod g+x /etc/init.d/slapd
RUN echo "local4.*			/var/log/sldapd.log" > /etc/rsyslog.d/slapd.conf

RUN apt-get install -yq ntp ntpdate nmap libsasl2-modules-gssapi-mit

# Cleanup Apt
RUN apt-get autoremove
RUN apt-get autoclean
RUN apt-get clean

ADD bootstrap.sh /bootstrap.sh
RUN chmod +x /bootstrap.sh
ADD kerberos.schema.gz /kerberos.schema.gz
ADD config/access.ldif /access.ldif
ADD config/config /config
RUN touch /var/userid
RUN echo '1000' > /var/userid
RUN chown root:root /var/userid
RUN touch /var/groupid
RUN chown root:root /var/groupid
RUN echo '502' > /var/groupid
RUN mkdir -p /utility/ldap
ADD utility/createGroup.sh /utility/ldap/createGroup.sh
ADD utility/createUser.sh /utility/ldap/createUser.sh
ADD utility/setupssl.sh /utility/ldap/setupssl.sh
ADD utility/createTokenLdif.sh /utility/ldap/createTokenLdif.sh

RUN chmod 700 /utility/ldap/setupssl.sh
RUN chmod 700 /utility/ldap/createGroup.sh
RUN chmod 700 /utility/ldap/createUser.sh
RUN chmod 700 /utility/ldap/createTokenLdif.sh

RUN chown root:root /utility/ldap/createUser.sh
RUN chown root:root /utility/ldap/createGroup.sh
RUN chown root:root /utility/ldap/setupssl.sh
ADD config/kubernetesToken.schema /kubernetesToken.schema

RUN mkdir -p /certificates
ADD ldap.default.svc.cloud.uat/* /certificates/

EXPOSE 389 636 80
ENTRYPOINT ["/bootstrap.sh"]
