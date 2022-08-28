#!/bin/bash
[[ "TRACE" ]] && set -x

: ${ENV:="LOCAL"}
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --host)
        shift
        CLOUD_HOST_IP=$1
        ;;
        -e | --env)
        shift
        ENV=$1
        ;;
    esac
shift
done

apt-get update
apt-get install -y net-tools

: ${CLOUD_HOST_IP:=$(ifconfig eth0 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
if [ -z "$CLOUD_HOST_IP" ]; then
    : ${CLOUD_HOST_IP:=$(ifconfig enp0s8 2>/dev/null|awk '/inet / {print $2}'|sed 's/addr://')}
fi

if [ -z "$CLOUD_HOST_IP" ]
then
	echo "Please provide master host ip"
	exit 0
fi

echo 'Installing the master node!!!!!!!!!'

apt-get update
echo "Installing dhcp server wget nfs-common bind9 ntp gcc make ifupdown net-tools"
apt-get install -y isc-dhcp-server wget nfs-common bind9 ntp gcc make ifupdown net-tools


hostnamectl set-hostname master.cloud.com

if [ "$ENV" == "LOCAL" ]
then
rm /etc/netplan/00-installer-config.yaml
touch /etc/netplan/00-installer-config.yaml
cat > /etc/netplan/00-installer-config.yaml << EOF
network:
  ethernets:
    enp0s3:
      dhcp4: false
      addresses: [11.0.0.1/24]
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
    enp0s8:
      dhcp4: true
  version: 2
EOF
netplan generate
netplan apply

elif [ "$ENV" == "CLOUD" ]; then
    sudo touch /etc/systemd/network/eth2.netdev
    sudo touch /etc/systemd/network/eth2.network
    cat <<EOF >/etc/systemd/network/eth2.network
[Match]
Name=eth2
[Network]
Address=11.0.0.1
Mask=255.255.255.0
EOF
    cat <<EOF >/etc/systemd/network/eth2.netdev
[NetDev]
Name=eth2
Kind=dummy
EOF
    systemctl restart systemd-networkd

fi

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
sed -i "s/option domain-name-servers ns1.example.org, ns2.example.org;/option domain-name-servers 11.0.0.1, 192.168.0.1;/" /etc/dhcp/temp-local-zones
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
sed -i '/nameserver/ i nameserver 11.0.0.1' /etc/resolv.conf
sed -i '/nameserver 11.0.0.1/ a\nameserver 192.168.0.1' /etc/resolv.conf
sed -i 's/search.*/search cloud.com ./' /etc/resolv.conf
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
if [ "$ENV" == "LOCAL" ]; then
  iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE
elif [ "$ENV" == "CLOUD" ]; then
   iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
fi

iptables-save > /etc/iptables.rules
STATUS="$(grep "pre-up iptables-restore < /etc/iptables.rules" /etc/network/interfaces)"
if [ -z "$STATUS" ]
then
sed -i '$a pre-up iptables-restore < /etc/iptables.rules' /etc/network/interfaces
fi

if [ "$ENV" == "LOCAL" ]; then
      ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa
      cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

      useradd -m admin
      cp ~/.ssh/ /home/admin/ -r
      chown -R admin /home/admin/
fi


#################################
#################################
##########SETTING NTP############
#################################
#################################

sed -i '/^restrict ::1$/a\ restrict 11.0.0.0 mask 255.255.255.0 nomodify notrap' /etc/ntp.conf
service ntp start


#################################
#################################
##########SETTING NFS############
#################################
#################################


apt-get install -y nfs-kernel-server

echo "/export 11.0.0.0/24(rw,async,no_root_squash)" >> /etc/exports
mkdir -p /export
chmod 777 /export
exportfs -va
systemctl start nfs-kernel-server
systemctl enable nfs-kernel-server
mount 11.0.0.1:/export /export


echo 'export MOUNT_PATH=/export' >> /etc/bash.bashrc
echo 'iptables -P FORWARD ACCEPT' >> /root/.bashrc

rm -rf rndc-key