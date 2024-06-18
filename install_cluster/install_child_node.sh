#!/bin/bash
[[ "$TRACE" ]] && set -x

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
  -e | --env)
    shift
    ENV=$1
    ;;
  -m | --master)
     shift
     MASTER_NODE=$1
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
sed -i "s@node@${NODE_NAME}@" /etc/hosts

apt-get update
apt-get install -y net-tools ifupdown openssh-client openssh-server figlet

figlet "Worker Node Installation"

getIp(){
  echo "$IP_ADDRESS"
}

getMasterNodeIp(){
  echo "$MASTER_NODE"
}

append_if_not_exists() {
  local file=$1
  local line=$2

  if ! grep -q "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

setupPrivateNetwork(){
if [ "$ENV" == "LOCAL" ]
then
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


  STATUS=$(grep -i "send fqdn.fqdn $NODE_NAME;" /etc/dhcp/dhclient-enp0s3.conf)
  if [ -z "$STATUS" ]; then
    append_if_not_exists "/etc/dhcp/dhclient-enp0s3.conf" "send fqdn.fqdn $NODE_NAME;"
    append_if_not_exists "/etc/dhcp/dhclient-enp0s3.conf" "send fqdn.encoded on;"
    append_if_not_exists "/etc/dhcp/dhclient-enp0s3.conf" "send fqdn.server-update off;"
    append_if_not_exists "/etc/dhcp/dhclient-enp0s3.conf" "also request fqdn.fqdn;"
  fi
elif [ "$ENV" == "CLOUD" ]; then
    sudo touch /etc/systemd/network/eth2.netdev
    sudo touch /etc/systemd/network/eth2.network
    cat <<EOF >/etc/systemd/network/eth2.network
[Match]
Name=eth2
[Network]
Address=$(getIp)
Mask=255.255.255.0
EOF
    cat <<EOF >/etc/systemd/network/eth2.netdev
[NetDev]
Name=eth2
Kind=dummy
EOF
  systemctl restart systemd-networkd
  cat <<EOF > /etc/netplan/00-private-ethernet.yaml
network:
  version: 2
  ethernets:
    eth2:                          # Private network interface
      addresses:
        - $(getIp)/24
      mtu: 1500
      dhcp4: no
      nameservers:
        addresses:
          - 11.0.0.1            # Private IP for ns1
        search: [ cloud.com ]    # DNS zone
EOF
  netplan apply
  route add -net 11.0.0.0 netmask 255.255.255.0 gw 10.108.0.2
fi
}

if [ "$ENV" == "LOCAL" ]; then
    setupPrivateNetwork
fi

addRoutes(){
  IP=$(ifconfig eth2 2>/dev/null | awk '/inet / {print $2}' | sed 's/addr://')
  if [ "$IP" == "11.0.0.1" ]; then
    route add -net 11.0.0.2 netmask 255.255.255.255 gw 10.108.0.3
    route add -net 11.0.0.3 netmask 255.255.255.255 gw 10.108.0.4
    route add -net 11.0.0.4 netmask 255.255.255.255 gw 10.108.0.5
  elif [ "$IP" == "11.0.0.2" ]; then
    route add -net 11.0.0.1 netmask 255.255.255.255 gw 10.108.0.2
    route add -net 11.0.0.3 netmask 255.255.255.255 gw 10.108.0.4
    route add -net 11.0.0.4 netmask 255.255.255.255 gw 10.108.0.5
  elif [ "$IP" == "11.0.0.3" ]; then
    route add -net 11.0.0.1 netmask 255.255.255.255 gw 10.108.0.2
    route add -net 11.0.0.2 netmask 255.255.255.255 gw 10.108.0.3
    route add -net 11.0.0.4 netmask 255.255.255.255 gw 10.108.0.5
  elif [ "$IP" == "11.0.0.4" ]; then
    route add -net 11.0.0.1 netmask 255.255.255.255 gw 10.108.0.2
    route add -net 11.0.0.3 netmask 255.255.255.255 gw 10.108.0.4
    route add -net 11.0.0.2 netmask 255.255.255.255 gw 10.108.0.3
  fi
}

if [ "$ENV" == "CLOUD" ]; then
    echo "Dummy log"
    #Using routes of private network provided by cloud
    #addRoutes
fi


nameserver(){
  chattr -i /etc/resolv.conf
  sed -i "/nameserver/ i nameserver $(getMasterNodeIp)" /etc/resolv.conf
  sed -i 's/search.*/search cloud.com ./' /etc/resolv.conf
  chattr +i /etc/resolv.conf
}

nameserver

useradd -m -g admin admin

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

replace_ntp_server() {
  local file=$1
  local old_server=$2
  local new_server=$3

  sed -i "s/$old_server/$new_server/" "$file"
}

STATUS=$(grep "server master.cloud.com" /etc/ntpsec/ntp.conf)
if [ -z "$STATUS" ]; then
  replace_ntp_server "/etc/ntpsec/ntp.conf" "server ntp.ubuntu.com" "server master.cloud.com"
  replace_ntp_server "/etc/ntpsec/ntp.conf" "pool 0.ubuntu.pool.ntp.org iburst" ""
  replace_ntp_server "/etc/ntpsec/ntp.conf" "pool 1.ubuntu.pool.ntp.org iburst" ""
  replace_ntp_server "/etc/ntpsec/ntp.conf" "pool 2.ubuntu.pool.ntp.org iburst" ""
  replace_ntp_server "/etc/ntpsec/ntp.conf" "pool 3.ubuntu.pool.ntp.org iburst" ""
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