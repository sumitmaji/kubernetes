#!/bin/bash
[[ "TRACE" ]] && set -x

while [ $# -gt 0 ]; do
  case "$1" in
  -n | --node)
    shift
    NODE_NAME=$1
    ;;
  -i | --ipaddress)
    shift
    IP_ADDRESS=$1
    ;;
  esac
  shift
done

if [ -z "$NODE_NAME" ]; then
  echo "Please provide node name"
  exit 0
fi


# Keep upstart from complaining
dpkg-divert --local --rename --add /sbin/initctl
ln -sf /bin/true /sbin/initctl
DEBIAN_FRONTEND noninteractive
apt-get update
apt-get install -yq apt debconf
apt-get upgrade -yq
apt-get -y -o Dpkg::Options::="--force-confdef" upgrade
apt-get -y dist-upgrade


hostnamectl set-hostname "${NODE_NAME}".cloud.com
echo "${NODE_NAME}".cloud.com > /etc/hostname

apt-get update
apt-get install -y net-tools ifupdown openssh-client openssh-server

rm /etc/netplan/00-installer-config.yaml
touch /etc/netplan/00-installer-config.yaml
cat >>/etc/netplan/00-installer-config.yaml <<EOF
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

if [ ! -f /etc/dhcp/dhclient-enp0s3.conf ]; then
  touch /etc/dhcp/dhclient-enp0s3.conf
fi

STATUS=$(grep -i "send fqdn.fqdn "$NODE_NAME";" /etc/dhcp/dhclient-enp0s3.conf)
if [ -z "$STATUS" ]; then
  echo "send fqdn.fqdn \"$NODE_NAME\";" >/etc/dhcp/dhclient-enp0s3.conf
  echo "send fqdn.encoded on;" >>/etc/dhcp/dhclient-enp0s3.conf
  echo "send fqdn.server-update off;" >>/etc/dhcp/dhclient-enp0s3.conf
  echo "also request fqdn.fqdn;" >>/etc/dhcp/dhclient-enp0s3.conf
fi

chattr -i /etc/resolv.conf
sed -i '/nameserver/ i nameserver 11.0.0.1' /etc/resolv.conf
sed -i '/nameserver 11.0.0.1/ a\nameserver 192.168.0.1' /etc/resolv.conf
sed -i 's/serach.*/serach cloud.com ./' /etc/resolv.conf
chattr +i /etc/resolv.conf

useradd -m admin

if [ ! -d ~/.ssh ]; then
  scp -r admin@master:/home/admin/.ssh .
fi

############################################
############################################
##############SETTING NTP###################
############################################
############################################

apt-get update
apt-get install -y sntp libopts25 ntp

STATUS=$(grep "server master.cloud.com" /etc/ntp.conf)
if [ -z "$STATUS" ]; then
  $(sed -i 's/server 0.ubuntu.pool.ntp.org/server master.cloud.com/' /etc/ntp.conf)
  $(sed -i 's/server 1.ubuntu.pool.ntp.org//' /etc/ntp.conf)
  $(sed -i 's/server 2.ubuntu.pool.ntp.org//' /etc/ntp.conf)
  $(sed -i 's/server 3.ubuntu.pool.ntp.org//' /etc/ntp.conf)
fi

service ntp start

############################################
############################################
###############SETTING NFS##################
############################################
############################################

apt-get install -y nfs-common

mkdir -p /export
STATUS=$(grep "master:/export    /export   nfs     defaults,_netdev,x-systemd.automount,timeo=14,retry=0        0 0" /etc/fstab)
if [ -z "$STATUS" ]; then
  sed -i '$a\master:/export    /export   nfs     defaults,_netdev,x-systemd.automount,timeo=14,retry=0        0 0' /etc/fstab
fi
mount -a

echo "$NODE_NAME" >/etc/hostname

echo 'export MOUNT_PATH=/export' >>/etc/bash.bashrc
echo 'iptables -P FORWARD ACCEPT' >>/root/.bashrc

#################################
#################################
##########SETTING SSHD############
#################################
#################################

mkdir -p /var/run/sshd
echo 'root:root' | chpasswd
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

cp /container/scripts/ssh_config /root/.ssh/
cat >/root/.ssh/config <<EOF
Host *
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  LogLevel quiet
EOF
chmod 600 /root/.ssh/config
chown root:root /root/.ssh/config

# fix the 254 error code
sed -i "/^[^#]*UsePAM/ s/.*/#&/" /etc/ssh/sshd_config
echo "UsePAM no" >>/etc/ssh/sshd_config

export NOTVISIBLE="in users profile"
echo "export VISIBLE=now" >>/etc/profile

reboot
