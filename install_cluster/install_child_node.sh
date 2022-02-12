#!/bin/bash
[[ "TRACE" ]] && set -x

    case "$1" in
        '-n')  NODE_NAME="$2"
        shift
        ;;
        '-i')  IP_ADDRESS="$2"
        shift
        ;;
    esac

if [ -z "$NODE_NAME" ]
then
	echo "Please provide node name"
	exit 0
fi

apt-get update
apt-get install -y net-tools ifupdown

rm /etc/netplan/00-installer-config.yaml
touch /etc/netplan/00-installer-config.yaml
cat >> /etc/netplan/00-installer-config.yaml << EOF
network:
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
      optional: true
  version: 2
EOF
netplan generate
netplan apply

touch /etc/network/interfaces
STATUS=`grep "auto enp0s3" /etc/network/interfaces`
if [ -z "$STATUS" ]
then
`sed -i '$a\auto enp0s3' /etc/network/interfaces`
`sed -i '$a\iface enp0s3 inet dhcp' /etc/network/interfaces`
fi

if [ ! -f /etc/dhcp/dhclient-enp0s3.conf ]
then
touch /etc/dhcp/dhclient-enp0s3.conf
fi

STATUS=`grep -i "send fqdn.fqdn "$NODE_NAME";" /etc/dhcp/dhclient-enp0s3.conf`
if [ -z "$STATUS" ]
then
echo "send fqdn.fqdn \"$NODE_NAME\";" > /etc/dhcp/dhclient-enp0s3.conf
echo "send fqdn.encoded on;" >> /etc/dhcp/dhclient-enp0s3.conf
echo "send fqdn.server-update off;" >> /etc/dhcp/dhclient-enp0s3.conf
echo "also request fqdn.fqdn;" >> /etc/dhcp/dhclient-enp0s3.conf
fi

ifup enp0s3

useradd -m admin

if [ ! -d ~/.ssh ]
then
scp -r admin@master:/home/admin/.ssh .
fi

############################################
############################################
###############SETTING NFS##################
############################################
############################################

apt-get install -y nfs-common

mkdir -p /export

mount master:/root /root
mount master:/home /home
mount master:/export /export

############################################
############################################
##############SETTING NTP###################
############################################
############################################

apt-get update
apt-get install -y sntp libopts25 ntp

STATUS=`grep "server master.cloud.com" /etc/ntp.conf`
if [ -z "$STATUS" ]
then
`sed -i 's/server 0.ubuntu.pool.ntp.org/server master.cloud.com/' /etc/ntp.conf`
`sed -i 's/server 1.ubuntu.pool.ntp.org//' /etc/ntp.conf`
`sed -i 's/server 2.ubuntu.pool.ntp.org//' /etc/ntp.conf`
`sed -i 's/server 3.ubuntu.pool.ntp.org//' /etc/ntp.conf`
fi

service ntp start

exit 0
STATUS=`grep "master:/root    /root   nfs     _netdev,x-systemd.automount        0 0" /etc/fstab`
if [ -z "$STATUS" ]
then
`sed -i '$a\master:/root    /root   nfs     _netdev,x-systemd.automount        0 0' /etc/fstab`
`sed -i '$a\master:/home    /home   nfs     _netdev,x-systemd.automount        0 0' /etc/fstab`
`sed -i '$a\master:/export    /export   nfs     _netdev,x-systemd.automount        0 0' /etc/fstab`
fi

mount /root
mount /home
mount /export

########################################
########################################
#############SETTING GANGLIA############
########################################
########################################


apt-get install -y ganglia-monitor

`sed -i 's/deaf = no/deaf = yes/' /etc/ganglia/gmond.conf`
`sed -i 's/name = "unspecified"/name = "cloud"/' /etc/ganglia/gmond.conf`
`sed -i '/udp_send_channel {/,/}/ { s/mcast_join/#mcast_join/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_send_channel {/,/}/ { s/.*mcast_join.*/host = master.cloud.com/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/udp_recv_channel/#udp_recv_channel/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/mcast_join/#mcast_join/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/port/#port/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/bind/#bind/ }' /etc/ganglia/gmond.conf`
`sed -i '/udp_recv_channel {/,/}/ { s/\}/#\}/ }' /etc/ganglia/gmond.conf`


service ganglia-monitor restart

########################################
########################################
##########SETTING LDAP CLIENT###########
########################################
########################################

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
echo 'export MOUNT_PATH=/export' >> /etc/bash.bashrc
echo 'iptables -P FORWARD ACCEPT' >> /root/.bashrc
