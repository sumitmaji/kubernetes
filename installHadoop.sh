#!/bin/bash

echo "Installing Java!!!!!!"
if [ ! -d /usr/local/jdk1.7.0_79 ]
then
	cp /home/sumit/jdk-7u79-linux-x64.tar.gz /usr/local/
	tar -xzvf /usr/local/jdk-7u79-linux-x64.tar.gz -C /usr/local/
	rm -rf /usr/local/jdk-7u79-linux-x64.tar.gz
fi

echo "Adding hadoop users!!!!!!"
sudo addgroup hadoop
sudo adduser --ingroup hadoop hduser
sudo adduser hduser sudo
#su hduser

echo "Enabling SSH!!!!!!!"
ssh-keygen -t rsa -P ""
cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
cp ~/.ssh/ /home/hduser/ -r
chown -R hduser:hadoop /home/hduser/.ssh
#cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys

echo "Installing hadoop"
if [ ! -d /usr/local/hadoop ]
then
sudo -u hduser sudo cp /home/sumit/hadoop-2.5.2.tar.gz /usr/local/
sudo -u hduser sudo tar -xzvf /usr/local/hadoop-2.5.2.tar.gz -C /usr/local/
sudo -u hduser sudo mv /usr/local/hadoop-2.5.2 /usr/local/hadoop 
sudo -u hduser sudo rm -rf /usr/local/hadoop-2.5.2.tar.gz
sudo chown -R hduser:hadoop /usr/local/hadoop
fi

status=`sudo -u hduser grep "export HADOOP_INSTALL" /home/hduser/.bashrc`

if [ -z "$status" ]
then
#HADOOP VARIABLES START"
sudo -u hduser echo 'export JAVA_HOME=/usr/local/jdk1.7.0_79' >> /home/hduser/.bashrc
sudo -u hduser echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_INSTALL=/usr/local/hadoop' >> /home/hduser/.bashrc
sudo -u hduser echo 'export PATH=$PATH:$HADOOP_INSTALL/bin' >> /home/hduser/.bashrc
sudo -u hduser echo 'export PATH=$PATH:$HADOOP_INSTALL/sbin' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_MAPRED_HOME=$HADOOP_INSTALL' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_COMMON_HOME=$HADOOP_INSTALL' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_HDFS_HOME=$HADOOP_INSTALL' >> /home/hduser/.bashrc
sudo -u hduser echo 'export YARN_HOME=$HADOOP_INSTALL' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_INSTALL/lib/native' >> /home/hduser/.bashrc
sudo -u hduser echo 'export HADOOP_OPTS="-Djava.library.path=$HADOOP_INSTALL/lib"' >> /home/hduser/.bashrc
#HADOOP VARIABLES END"
fi

export JAVA_HOME=/usr/local/jdk1.7.0_79
export PATH=$PATH:$JAVA_HOME/bin
java -version

STATUS=`grep "/usr/local/jdk1.7.0_79" /usr/local/hadoop/etc/hadoop/hadoop-env.sh`
if [ -z "$STATUS" ]
then
        sudo -u hduser sudo sed -i 's/\(export JAVA_HOME=${JAVA_HOME}\)/#\1/' /usr/local/hadoop/etc/hadoop/hadoop-env.sh
        sudo -u hduser sudo sed -i '/export JAVA_HOME/ a\\nexport JAVA_HOME=/usr/local/jdk1.7.0_79' /usr/local/hadoop/etc/hadoop/hadoop-env.sh
fi

sudo mkdir -p /app/hadoop/tmp
sudo chown hduser:hadoop /app/hadoop/tmp

if [ ! -f /usr/local/hadoop/etc/hadoop/core-site.xml_bk ]
then
sudo -u hduser sudo cp /usr/local/hadoop/etc/hadoop/core-site.xml /usr/local/hadoop/etc/hadoop/core-site.xml_bk
sudo -u hduser sudo sed -i '/<configuration>/ a\\n\t<property>\n\t\t<name>hadoop.tmp.dir<\/name>\n\t\t<value>/app/hadoop/tmp<\/value>\n\t\t<description>A base for other temporary directories.<\/description>\n\t<\/property>\n\t<property>\n\t\t<name>fs.default.name<\/name>\n\t\t<value>hdfs:\/\/localhost:54310<\/value>\n\t\t<description>The name of the default file system.  A URI whose\n\t\tscheme and authority determine the FileSystem implementation.  The\n\t\turis scheme determines the config property (fs.SCHEME.impl) naming\n\t\tthe FileSystem implementation class.  The uris authority is used to\n\t\tdetermine the host, port, etc. for a filesystem.<\/description>\n\t<\/property>\n
' /usr/local/hadoop/etc/hadoop/core-site.xml
fi 


if [ ! -f /usr/local/hadoop/etc/hadoop/mapred-site.xml ]
then
sudo -u hduser sudo cp /usr/local/hadoop/etc/hadoop/mapred-site.xml.template /usr/local/hadoop/etc/hadoop/mapred-site.xml
sudo -u hduser sudo sed -i '/<configuration>/ a\\n\t<property>\n\t\t<name>mapred.job.tracker<\/name>\n\t\t<value>localhost:54311<\/value>\n\t\t<description>The host and port that the MapReduce job tracker runs\n\t\tat.  If "local", then jobs are run in-process as a single map\n\t\tand reduce task.\n\t\t<\/description>\n\t<\/property>\n
' /usr/local/hadoop/etc/hadoop/mapred-site.xml
fi

sudo mkdir -p /usr/local/hadoop_store/hdfs/namenode
sudo mkdir -p /usr/local/hadoop_store/hdfs/datanode
sudo chown -R hduser:hadoop /usr/local/hadoop_store

if [ ! -f /usr/local/hadoop/etc/hadoop/hdfs-site.xml_bk ]
then
sudo -u hduser sudo cp /usr/local/hadoop/etc/hadoop/hdfs-site.xml /usr/local/hadoop/etc/hadoop/hdfs-site.xml_bk
sudo -u hduser sudo sed -i '/<configuration>/ a\\n\t<property>\n\t\t<name>dfs.replication<\/name>\n\t\t<value>1<\/value>\n\t\t<description>Default block replication.\n\t\tThe actual number of replications can be specified when the file is created.\n\t\tThe default is used if replication is not specified in create time.\n\t\t<\/description>\n\t\t<\/property>\n\t<property>\n\t\t<name>dfs.namenode.name.dir<\/name>\n\t\t<value>file:\/usr\/local\/hadoop_store\/hdfs\/namenode<\/value>\n\t\t<\/property>\n\t<property>\n\t\t<name>dfs.datanode.data.dir<\/name>\n\t\t<value>file:\/usr\/local\/hadoop_store\/hdfs\/datanode<\/value>\n\t<\/property>\n
' /usr/local/hadoop/etc/hadoop/hdfs-site.xml
fi



