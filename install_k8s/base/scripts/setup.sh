#/bin/bash

mkdir /var/run/sshd
echo 'root:root' | chpasswd
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# passwordless ssh
ssh-keygen -qy -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
ssh-keygen -qy -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
mkdir /root/.ssh
ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

cp /container/scripts/ssh_config /root/.ssh/
mv /root/.ssh/ssh_config /root/.ssh/config
chmod 600 /root/.ssh/config
chown root:root /root/.ssh/config

# fix the 254 error code
sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
echo "UsePAM no" >> /etc/ssh/sshd_config
echo "Port 2122" >> /etc/ssh/sshd_config

export NOTVISIBLE="in users profile"
echo "export VISIBLE=now" >> /etc/profile


