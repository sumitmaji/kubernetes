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

RUN apt-get update
# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl
RUN apt-get install -yq nmap
RUN apt-get install -yq apt debconf
RUN apt-get upgrade -yq
RUN apt-get -y -o Dpkg::Options::="--force-confdef" upgrade
RUN apt-get -y dist-upgrade

RUN echo "ldap-auth-config ldap-auth-config/dblogin boolean false" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/override boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap://$LDAP_HOSTNAME" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/pam_password string md5" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/dbrootlogin boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=net" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/ldap_version string 3" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/move-to-debconf boolean true" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/ldapns/base-dn string $BASE_DN" | debconf-set-selections
RUN echo "ldap-auth-config ldap-auth-config/rootbinddn string cn=admin,$BASE_DN" | debconf-set-selections

ADD config/krb-ldap-config /etc/auth-client-config/profile.d/krb-ldap-config
RUN apt-get install -yq ldap-auth-client nscd krb5-user libpam-krb5 libpam-ccreds
RUN apt-get install -yq ntp ntpdate nmap libsasl2-modules-gssapi-mit
#RUN auth-client-config -a -p krb_ldap

RUN mkdir /utility
RUN mkdir /utility/ldap
RUN mkdir /utility/kerberos
ADD utility/enableLdapPam.sh /utility/ldap/enableLdapPam.sh
RUN chmod +x /utility/ldap/enableLdapPam.sh
ADD utility/enableKerbPam.sh /utility/kerberos/enableKerbPam.sh
RUN chmod +x /utility/kerberos/enableKerbPam.sh
ADD utility/enableUbuntuPam.sh /utility/enableUbuntuPam.sh
RUN chmod +x /utility/enableUbuntuPam.sh
#ADD config/ldap.secret /etc/ldap.secret
RUN echo "$LDAP_PASSWORD" > /etc/ldap.secret
RUN chmod 600 /etc/ldap.secret
RUN apt-get install -yq nmap ntp ntpdate
ADD utility/setupUser.sh /utility/setupUser.sh
RUN chmod +x /utility/setupUser.sh

#RUN adduser openldap
#RUN adduser openldap sudo
#RUN echo openldap:openldap | chpasswd
#RUN chown -R openldap:openldap /var/lib/ldap


#RUN /utility/enableUbuntuPam.sh

# Cleanup Apt
RUN apt-get autoremove
RUN apt-get autoclean
RUN apt-get clean

ADD utility/bootstrap.sh /utility/ldap/bootstrap.sh
RUN chmod +x /utility/ldap/bootstrap.sh
ADD config/config /config

EXPOSE 389 636 80
ENTRYPOINT ["/utility/ldap/bootstrap.sh"]
