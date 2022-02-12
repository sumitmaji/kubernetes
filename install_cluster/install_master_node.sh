#!/bin/bash
[[ "TRACE" ]] && set -x

while [ $# -gt 0 ]
do
    case "$1" in
        '-h')  CLOUD_HOST_IP="$2";;
    esac
    shift
done

if [ -z "$CLOUD_HOST_IP" ]
then
	echo "Please provide master host ip"
	exit 0
fi

echo 'Installing the master node!!!!!!!!!'

apt-get update
echo "Installing dhcp server wget nfs-common bind9 ntp gcc make ifupdown net-tools"
apt-get install -y isc-dhcp-server wget nfs-common bind9 ntp gcc make ifupdown net-tools

sed -i 's/master$/master.cloud.com/' /etc/hostname

touch /etc/network/interfaces
STATUS="$(grep "##ethernet setup completed" /etc/network/interfaces)"
if [ -z "$STATUS" ]
then
cat >> /etc/network/interfaces << EOF
iface enp0s8 inet dhcp
auto enp0s3
iface enp0s3 inet static
address 11.0.0.1
netmast 255.255.255.0
network 11.0.0.0
broadcast 11.0.0.254
##ethernet setup completed
EOF
fi

sed -i 's/\(127.0.1.1\)\(.*master.*\)/'"$CLOUD_HOST_IP"' master.cloud.com/' /etc/hosts
echo "Activating eth0 ethernet"
ifup enp0s3


STATUS="$(grep "##zone append end" /etc/bind/named.conf.default-zones)"
if [ -z "$STATUS" ]
then
cat >>  /etc/bind/named.conf.default-zones << EOF
##zone append begin
zone "cloud.com" {
	type master;
	file "/etc/bind/cloud.com.fwd";
	allow-update { key rndc-key; };
};

zone "0.0.11.in-addr.arpa" {
	type master;
	file "/etc/bind/cloud.com.rev";
	allow-update { key rndc-key; };
};
##zone append end
EOF
fi

touch ./rndc-key
STATUS="$(grep "##rndc-key copy end" ./rndc-key)"
if [ -z "$STATUS" ]
then
echo '##rndc-key copy begin' >  ./rndc-key
grep -A 3 "key \"rndc-key\"" /etc/bind/rndc.key >> ./rndc-key
sed -i '$a\##rndc-key copy end' ./rndc-key
fi

STATUS="$(grep "##rndc-key copy end" /etc/bind/named.conf.options)"
if [ -z "$STATUS" ]
then
sed -i '$r ./rndc-key' /etc/bind/named.conf.options
fi

sed -i 's_/etc/bind/\*\* r,_/etc/bind/\*\* rw,_' /etc/apparmor.d/usr.sbin.named
service apparmor restart

if [ -f /etc/bind/cloud.com.fwd ]
then
echo "The forward exits"
else
touch /etc/bind/cloud.com.fwd
cat >> /etc/bind/cloud.com.fwd << EOF
\$TTL	86400
@	IN 		SOA 	master.cloud.com.		root.cloud.com. (
	1		;Serial
	604800	;Refresh
	86400	;Retry
	2419200	;Expire
	86400	;minimum
)
@	IN		NS		master.cloud.com.
master		IN		A	11.0.0.1
EOF
fi

if [ -f /etc/bind/cloud.com.rev ]
then
echo "The reverse exists"
else
touch /etc/bind/cloud.com.rev
cat >> /etc/bind/cloud.com.rev << EOF
\$TTL    86400
@       IN              SOA     master.cloud.com.         root.cloud.com. (
        1               ;Serial
        3600            ;Refresh
        1800            ;Retry
        604800          ;Expire
        86400           ;minimum ttl
)
@       IN      NS      master.cloud.com
master.cloud.com  IN      A       11.0.0.1
1       IN      PTR     master.cloud.com
EOF
fi

service bind9 restart

if [ -f /etc/dhcp/dhcpd.conf_tmp ]
then
echo "Dhcp Temp file exists."
else
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf_tmp
fi

if [[ ! -f /etc/dhcp/temp-local-zones ]]
then
cat ./rndc-key > /etc/dhcp/temp-local-zones
cat >> /etc/dhcp/temp-local-zones << EOF
zone cloud.com. {
        primary 127.0.0.1;
        key rndc-key;
}

zone 0.0.11.in-addr.arpa. {
        primary 127.0.0.1;
        key rndc-key;
}
EOF
cat /etc/dhcp/dhcpd.conf_tmp >> /etc/dhcp/temp-local-zones
sed -i 's/ddns-update-style none/ddns-update-style interim/' /etc/dhcp/temp-local-zones
sed -i '/ddns-update-style interim/ a\autorotive;' /etc/dhcp/temp-local-zones
sed -i '/autorotive/ a\ddns-domainname "cloud.com";' /etc/dhcp/temp-local-zones
sed -i '/ddns-domainname "cloud.com"/ a\ddns-rev-domainname "in-addr.arpa";' /etc/dhcp/temp-local-zones
sed -i '/ddns-rev-domainname "in-addr.arpa"/ a\ddns-updates on;' /etc/dhcp/temp-local-zones
sed -i 's/option domain-name "example.org";/option domain-name "cloud.com";/' /etc/dhcp/temp-local-zones
sed -i "s/option domain-name-servers ns1.example.org, ns2.example.org;/option domain-name-servers 11.0.0.1, $CLOUD_HOST_IP;/" /etc/dhcp/temp-local-zones
sed -i '/^max-lease-time 7200;/ a\subnet 11.0.0.0 netmask 255.255.255.0 {' /etc/dhcp/temp-local-zones
sed -i '/subnet 11.0.0.0 netmask 255.255.255.0 {/ a\option routers 11.0.0.1;'  /etc/dhcp/temp-local-zones
sed -i '/option routers 11.0.0.1;/ a\option subnet-mask 255.255.255.0;' /etc/dhcp/temp-local-zones
sed -i '/option subnet-mask 255.255.255.0;/ a\option time-offset -18000;' /etc/dhcp/temp-local-zones
sed -i '/option time-offset -18000;/ a\range 11.0.0.1 11.0.0.254;' /etc/dhcp/temp-local-zones
sed -i '/range 11.0.0.1 11.0.0.254;/ a\}' /etc/dhcp/temp-local-zones

cat /etc/dhcp/temp-local-zones > /etc/dhcp/dhcpd.conf
fi

service isc-dhcp-server restart

chattr -i /etc/resolv.conf
echo "nameserver 11.0.0.1" > /etc/resolv.conf
echo "nameserver $CLOUD_HOST_IP" >> /etc/resolv.conf
echo "search cloud.com Home" >> /etc/resolv.conf
cp /etc/resolv.conf .
rm /etc/resolv.conf
cp resolv.conf /etc/
chattr +i /etc/resolv.conf

chmod 775 -R /etc/bind
chown -R bind /etc/bind
service bind9 restart
service isc-dhcp-server restart


###########################
###########################
######SETTING NAT##########
###########################
###########################
###########################

echo "1" > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE
iptables-save > /etc/iptables.rules
STATUS="$(grep "pre-up iptables-restore < /etc/iptables.rules" /etc/network/interfaces)"
if [ -z "$STATUS" ]
then
`sed -i '/broadcast 11.0.0.254/ a\pre-up iptables-restore < /etc/iptables.rules' /etc/network/interfaces`
fi

#ssh-keygen

#cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

#cp ~/.ssh/ /home/sumit/ -r

#chown -R sumit /home/sumit/


#################################
#################################
##########SETTING NFS############
#################################
#################################


apt-get install -y nfs-kernel-server
mkdir -p /home/shared

echo "/root 11.0.0.0/24(rw,async,no_root_squash)" > /etc/exports
echo "/home 11.0.0.0/24(rw,async,no_root_squash)" >> /etc/exports
echo "/home/shared 11.0.0.0/24(rw,async,no_root_squash)" >> /etc/exports
echo "/export 11.0.0.0/24(rw,async,no_root_squash)" >> /etc/exports

mkdir -p /export

exportfs -va

service nfs-kernel-server start

mount 11.0.0.1:/home/shared /export

#umount /export

#################################
#################################
##########SETTING NTP############
#################################
#################################

`sed -i '/^restrict ::1$/a\ restrict 11.0.0.0 mask 255.255.255.0 nomodify notrap' /etc/ntp.conf`

service ntp start

echo 'export MOUNT_PATH=/export' >> /etc/bash.bashrc
echo 'iptables -P FORWARD ACCEPT' >> /root/.bashrc

rm -rf rndc-key

exit 0

#################################
#################################
#######SETTING GANGLIA###########
#################################
#################################

apt-get install -y ganglia-monitor rrdtool gmetad ganglia-webfrontend

cp /etc/ganglia-webfrontend/apache.conf /etc/apache2/sites-enabled/ganglia.conf

`sed -i 's/data_source "my cluster" localhost/data_source "cloud" master.cloud.com/' /etc/ganglia/gmetad.conf`

`sed -i 's/name = "unspecified"/name = "cloud"/' /etc/ganglia/gmond.conf`

`sed -i '/udp_send_channel {/,/}/ { s/mcast_join/#mcast_join/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_send_channel {/,/}/ { s/.*mcast_join.*/host = master.cloud.com/}' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/mcast_join/#mcast_join/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/bind/#bind/ }' /etc/ganglia/gmond.conf`
service ganglia-monitor restart

service gmetad restart

service apache2 restart


#################################
#################################
###########SETTING LDAP##########
#################################
#################################

apt-get install -y slapd ldap-utils

dpkg-reconfigure slapd

apt-get install -y phpldapadmin

`sed -i "s/servers->setValue('server','host','127.0.0.1');/servers->setValue('server','host','master.cloud.com');/" /etc/phpldapadmin/config.php`
`sed -i "s/servers->setValue('server','base',array('dc=example,dc=com'));/servers->setValue('server','base',array('dc=cloud,dc=com'));/" /etc/phpldapadmin/config.php`
`sed -i "s/servers->setValue('login','bind_id','cn=admin,dc=example,dc=com');/servers->setValue('login','bind_id','cn=admin,dc=cloud,dc=com');/" /etc/phpldapadmin/config.php`
`sed -i "s/'appearance','password_hash'/'appearance','password_hash_custom'/" /usr/share/phpldapadmin/lib/TemplateRender.php`

#################################
#################################
########SETTING LDAP CLIENT######
#################################
#################################

#apt-get install -y libpam-ldap nscd
sudo apt-get install -y ldap-auth-client nscd

sudo auth-client-config -t nss -p lac_ldap

STATUS=`grep "umask=0022 skel=/etc/skel" /etc/pam.d/common-session`

if [ -z "$STATUS" ]
then
`sed -i '/pam_ldap.so/ s/^/session required        pam_mkhomedir.so umask=0022 skel=\/etc\/skel\n/' /etc/pam.d/common-session`
#`sed -i '$a\session optional        pam_mkhomedir.so        skel=/etc/skel umask=0022' /etc/pam.d/common-session`
fi

service nscd restart

STATUS=`grep "%admins ALL=(ALL) ALL" /etc/sudoers`
if [ -z "$STATUS" ]
then
`sed -i '/%admin ALL=(ALL) ALL/a\%admins ALL=(ALL) ALL' /etc/sudoers`
fi
