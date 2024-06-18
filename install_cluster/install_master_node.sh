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


installPkg(){
  apt-get update
  apt-get install -y net-tools
  # Keep upstart from complaining
  dpkg-divert --local --rename --add /sbin/initctl
  ln -sf /bin/true /sbin/initctl
  DEBIAN_FRONTEND noninteractive
  apt-get update
  apt-get install -yq apt debconf
  apt-get upgrade -yq
  apt-get -y -o Dpkg::Options::="--force-confdef" upgrade
  apt-get -y dist-upgrade

  apt-get update
  apt-get install -y isc-dhcp-server wget nfs-common bind9 bind9utils bind9-doc figlet \
          gcc make ifupdown net-tools openssh-server openssh-client
  apt-get -y install ntp
  hostnamectl set-hostname master.cloud.com

}

figlet "Master Node Installation"

: ${CLOUD_HOST_IP:=$(ip -4 addr show eth1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')}

if [ -z "$CLOUD_HOST_IP" ]; then
    CLOUD_HOST_IP=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
fi

if [ -z "$CLOUD_HOST_IP" ]; then
    echo "Please provide master host ip"
    exit 1
fi

CHILD_NODES=("node01:10.108.0.3" "node02:10.108.0.4" "node03:10.108.0.5")

getIp(){
  echo "11.0.0"
}

getRevIp(){
  echo "0.0.11"
}

getMasterIp(){
  echo "10.108.0.2"
}




echoSuccess(){
  echo -e "\e[32m$1\e[0m"
}

echoFailed(){
  echo -e "\e[31m$1\e[0m"
}

echoWarning(){
  echo -e "\e[32m$1\e[0m"
}

setupPrivateNetwork(){
if [ "$ENV" == "LOCAL" ]
then
rm /etc/netplan/00-installer-config.yaml
touch /etc/netplan/00-installer-config.yaml
cat > /etc/netplan/00-installer-config.yaml << EOF
network:
  ethernets:
    enp0s3:
      dhcp4: false
      addresses: [$(getIp).1/24]
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
Address=$(getIp).1
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
        - $(getIp).1/24
      routes:
        - to: default
          via: $(getIp).254
      mtu: 1500
      dhcp4: no
      nameservers:
        addresses:
          - $(getIp).1            # Private IP for ns1
        search: [ cloud.com ]    # DNS zone
EOF
  netplan apply
fi
}

#Remove eth
rmEth(){
  eth=$1
  sudo ip link delete $eth type dummy
  sudo rmmod dummy
}

#Add Route for a subnet
addSubRoute(){
  #All the request for ips 192.168.0.0 to 192.168.0.255 will go via 10.108.0.2 gateway(vm that know how to reach the target)
  echo "route add -net 192.168.0.0 netmask 255.255.255.0 gw 10.108.0.2"
}

#Add route for an ip
addIpRoute(){
  #All request for ip 11.0.0.2 will go via 10.108.0.2 gateway(vm that knows how to reach the target)
  echo "route add -net 11.0.0.2 netmask 255.255.255.255 gw 10.108.0.3"
}

#Delete route for subnet
delSubRoute(){
  echo "ip route del 11.0.0.0/24"
}

addRoutes(){
  IP=$(ip -4 addr show eth2 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ "$IP" == "11.0.0.1" ]; then
    ip route add 11.0.0.2/32 via 10.108.0.3
    ip route add 11.0.0.3/32 via 10.108.0.4
    ip route add 11.0.0.4/32 via 10.108.0.5
  elif [ "$IP" == "11.0.0.2" ]; then
    ip route add 11.0.0.1/32 via 10.108.0.2
    ip route add 11.0.0.3/32 via 10.108.0.4
    ip route add 11.0.0.4/32 via 10.108.0.5
  elif [ "$IP" == "11.0.0.3" ]; then
    ip route add 11.0.0.1/32 via 10.108.0.2
    ip route add 11.0.0.2/32 via 10.108.0.3
    ip route add 11.0.0.4/32 via 10.108.0.5
  elif [ "$IP" == "11.0.0.4" ]; then
    ip route add 11.0.0.1/32 via 10.108.0.2
    ip route add 11.0.0.3/32 via 10.108.0.4
    ip route add 11.0.0.2/32 via 10.108.0.3
  fi
}

#https://www.digitalocean.com/community/tutorials/how-to-configure-bind-as-a-private-network-dns-server-on-ubuntu-18-04
#https://www.digitalocean.com/community/tutorials/how-to-configure-bind-as-a-private-network-dns-server-on-ubuntu-14-04
bindInst(){
  figlet "Setting DNS Server"
  if ! grep -q "##zone append end" /etc/bind/named.conf.default-zones; then
    cat >>  /etc/bind/named.conf.default-zones << EOF
##zone append begin
zone "cloud.com" {
	type master;
	file "/etc/bind/cloud.com.fwd";
	allow-update { key rndc-key; };
};

zone "$(getRevIp).in-addr.arpa" {
	type master;
	file "/etc/bind/cloud.com.rev";
	allow-update { key rndc-key; };
};
##zone append end
EOF
  fi

  if ! grep -q "##rndc-key copy end" ./rndc-key; then
    echo '##rndc-key copy begin' >  ./rndc-key
    grep -A 3 "key \"rndc-key\"" /etc/bind/rndc.key >> ./rndc-key
    echo '##rndc-key copy end' >> ./rndc-key
  fi

  if ! grep -q "##rndc-key copy end" /etc/bind/named.conf.options; then
    cat ./rndc-key >> /etc/bind/named.conf.options
  fi

  if [[ "${ENV}" == "CLOUD" ]] && ! grep -q "#trusted acl" /etc/bind/named.conf.options; then
    cat <<EOF >> /etc/bind/named.conf.options
#trusted acl
acl "trusted" {
$(for server in ${CHILD_NODES[@]}; do
  IFS=':'
  read -r node ip <<< $server
  echo "        $ip;"
  IFS=$oifs
done)
};
EOF
  fi

  sed -i 's_/etc/bind/\*\* r,_/etc/bind/\*\* rw,_' /etc/apparmor.d/usr.sbin.named
  service apparmor restart

  cat > /etc/bind/cloud.com.fwd << EOF
\$TTL	86400
@	IN 		SOA 	master.cloud.com.		root.cloud.com. (
	1		;Serial
	604800	;Refresh
	86400	;Retry
	2419200	;Expire
	86400	;minimum
)
@	IN		NS		master.cloud.com.
master		IN		A	$(getMasterIp)
$(if [[ "$ENV" == "CLOUD" ]]; then
for server in ${CHILD_NODES[@]}; do
  IFS=':'
  read -r node ip <<< $server
  echo "$node		IN		A	$ip"
  IFS=$oifs
done
fi)
EOF

  cat > /etc/bind/cloud.com.rev << EOF
\$TTL    86400
@       IN              SOA     master.cloud.com.         root.cloud.com. (
        1               ;Serial
        3600            ;Refresh
        1800            ;Retry
        604800          ;Expire
        86400           ;minimum ttl
)
@       IN      NS      master.cloud.com
master.cloud.com  IN      A       $(getMasterIp)
1       IN      PTR     master.cloud.com
$(if [[ "$ENV" == "CLOUD" ]]; then
for server in ${CHILD_NODES[@]}; do
IFS=':'
read -r node ip <<< "$server"
echo "$ip       IN      PTR     ${node}.cloud.com"
done
fi)
EOF

  chmod 775 -R /etc/bind
  chown -R bind /etc/bind
  service bind9 restart

  named-checkzone cloud.com /etc/bind/cloud.com.fwd
  [[ $? -eq 0 ]] && echoSuccess "Forward Bind looking good!!" || echoFailed "Bind Installation Failed!!"
  named-checkzone $(getIp).in-addr.arpa /etc/bind/cloud.com.rev
  [[ $? -eq 0 ]] && echoSuccess "Reverse Bind looking good!!" || echoFailed "Bind Installation Failed!!"
}

dhcpInst(){
  figlet "Setting DHCP Server"
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

zone $(getRevIp).in-addr.arpa. {
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
    sed -i "s/option domain-name-servers ns1.example.org, ns2.example.org;/option domain-name-servers $(getIp).1, 192.168.0.1;/" /etc/dhcp/temp-local-zones
    sed -i "/^max-lease-time 7200;/ a\subnet $(getIp).0 netmask 255.255.255.0 {" /etc/dhcp/temp-local-zones
    sed -i "/subnet $(getIp).0 netmask 255.255.255.0 {/ a\option routers $(getIp).1;"  /etc/dhcp/temp-local-zones
    sed -i "/option routers $(getIp).1;/ a\option subnet-mask 255.255.255.0;" /etc/dhcp/temp-local-zones
    sed -i "/option subnet-mask 255.255.255.0;/ a\option time-offset -18000;" /etc/dhcp/temp-local-zones
    sed -i "/option time-offset -18000;/ a\range $(getIp).1 $(getIp).254;" /etc/dhcp/temp-local-zones
    sed -i "/range $(getIp).1 $(getIp).254;/ a\}" /etc/dhcp/temp-local-zones

    cat /etc/dhcp/temp-local-zones > /etc/dhcp/dhcpd.conf
  fi

  service isc-dhcp-server restart
}


nameserver(){
  chattr -i /etc/resolv.conf
  sed -i "/nameserver/ i nameserver $(getMasterIp)" /etc/resolv.conf
  sed -i 's/search.*/search cloud.com ./' /etc/resolv.conf
  chattr +i /etc/resolv.conf
}


natInst(){
  figlet "Setting NAT"
  apt-get install -y iptables-persistent <<EOF
YES
YES
EOF
  echo "1" > /proc/sys/net/ipv4/ip_forward
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  if [ "$ENV" == "LOCAL" ]; then
    iptables -t nat -A POSTROUTING -o enp0s8 -j MASQUERADE
  elif [ "$ENV" == "CLOUD" ]; then
     iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  fi
  iptables-save > /etc/iptables/rules.v4

  if [ "$ENV" == "LOCAL" ]; then
    ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa
    cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

    useradd -m -g admin admin
    cp ~/.ssh/ /home/admin/ -r
    chown -R admin /home/admin/
  fi
}

ntpInst(){

  figlet "Setting NTP"

  sed -i "/^restrict ::1$/a\ restrict $(getMasterIp) mask 255.255.255.0 nomodify notrap" /etc/ntpsec/ntp.conf
  service ntp start
}

nfsInst(){
  figlet "Setting NFS"

  apt-get install -y nfs-kernel-server

  echo "/export $(getMasterIp)/24(rw,async,no_root_squash)" >> /etc/exports
  mkdir -p /export
  chmod 777 /export
  exportfs -va
  systemctl start nfs-kernel-server
  systemctl enable nfs-kernel-server
  mount $(getMasterIp):/export /export


  echo 'export MOUNT_PATH=/export' >> /etc/bash.bashrc
  echo 'iptables -P FORWARD ACCEPT' >> /root/.bashrc

  rm -rf rndc-key
}

sshdInst(){
  figlet "Setting SSHD"
  mkdir -p /var/run/sshd
  echo 'root:root' | chpasswd
  sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

  # SSH login fix. Otherwise user is kicked off after login
  sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

  cat > /root/.ssh/config <<EOF
Host *
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  LogLevel quiet
EOF
  chmod 600 /root/.ssh/config
  chown root:root /root/.ssh/config

  # fix the 254 error code
  sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
  echo "UsePAM no" >> /etc/ssh/sshd_config

  export NOTVISIBLE="in users profile"
  echo "export VISIBLE=now" >> /etc/profile
}

case "$ENV" in
  "CLOUD")
    installPkg
    bindInst
    nameserver
    natInst
    ntpInst
    nfsInst
    sshdInst
    # addRoutes
    reboot
    ;;
  "LOCAL")
    installPkg
    setupPrivateNetwork
    bindInst
    dhcpInst
    nameserver
    natInst
    ntpInst
    nfsInst
    sshdInst
    reboot
    ;;
  *)
    echo "Invalid environment. Please set ENV to either 'CLOUD' or 'LOCAL'."
    ;;
esac

