##############################DEPENDENCIES################################
if ! type ssh > /dev/null 2>&1 || ! type ssh-keygen > /dev/null 2>&1; then
	echo -e "\n\e[31mInstall \"openssl\" then come back\e[0m\n"
	exit
fi
if [[ ! -d /usr/lib/jvm/default-java ]]; then
	echo -e "\n\e[31mInstall \"openjdk\" then come back\e[0m\n"
	exit
fi
if ! type wget > /dev/null 2>&1; then
	echo -e "\n\e[31mInstall \"wget\" then come back\e[0m\n"
	exit
fi
##########################################################################

sudo addgroup hadoop
sudo adduser --ingroup hadoop hduser
mkdir /home/hduser/.ssh
sudo -u hduser ssh-keygen -f /home/hduser/.ssh/hduser_rsa -t rsa -P ""
cat /home/hduser/.ssh/hduser_rsa.pub >> /home/hduser/.ssh/authorized_keys
chown -R hduser:hadoop /home/hduser/.ssh
sudo service ssh restart
wget http://mirror.evowise.com/apache/hadoop/core/hadoop-2.7.3/hadoop-2.7.3.tar.gz  ###current stable, should change with time
echo "Extracting Hadoop, might take a while ..."
tar -xzf hadoop-2.7.3.tar.gz ###
echo "Extraction done"
mv hadoop-2.7.3 /usr/local/hadoop ###
echo "Extracted file was moved to /usr/local/hadoop to allow multiple users easy access"
mkdir /usr/local/hadoop/tmp
chown -R hduser:hadoop /usr/local/hadoop
###########################################################################
echo '
# Set Hadoop-related environment variables
export HADOOP_HOME=/usr/local/hadoop

# Set JAVA_HOME (we will also configure JAVA_HOME directly for Hadoop later on)
export JAVA_HOME=/usr/lib/jvm/default-java

# Some convenient aliases and functions for running Hadoop-related commands
unalias fs &> /dev/null
alias fs="hadoop fs"
unalias hls &> /dev/null
alias hls="fs -ls"

# If you have LZO compression enabled in your Hadoop cluster and
# compress job outputs with LZOP (not covered in this tutorial):
# Conveniently inspect an LZOP compressed file from the command
# line; run via:
#
# $ lzohead /hdfs/path/to/lzop/compressed/file.lzo
#
# Requires installed "lzop" command.
#
lzohead () {
    hadoop fs -cat $1 | lzop -dc | head -1000 | less
}

# Add Hadoop bin/ directory to PATH
export PATH=$PATH:$HADOOP_HOME/bin' >> /home/hduser/.bashrc
###############################################################################
sed -i 's/export JAVA_HOME=${JAVA_HOME}/export JAVA_HOME=\/usr\/lib\/jvm\/default-java/' /usr/local/hadoop/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_OPTS=-Djava.net.preferIPv4Stack=true' >> /usr/local/hadoop/etc/hadoop/hadoop-env.sh
###############################################################################
sed -i '/<configuration>/,/<\/configuration>/c\
<configuration>\
\
<property>\
  <name>hadoop.tmp.dir<\/name>\
  <value>\/usr\/local\/hadoop\/tmp<\/value>\
  <description>A base for other temporary directories.<\/description>\
<\/property>\
\
<property>\
  <name>fs.defaultFS<\/name>\
  <value>hdfs\:\/\/localhost\:54310<\/value>\
  <description>The name of the default file system.  A URI whose\
  scheme and authority determine the FileSystem implementation.  The\
  uri scheme determines the config property \(fs.SCHEME.impl\) naming\
  the FileSystem implementation class.  The uri authority is used to\
  determine the host, port, etc. for a filesystem.<\/description>\
<\/property>\
\
<\/configuration>' /usr/local/hadoop/etc/hadoop/core-site.xml
################################################################################
cp /usr/local/hadoop/etc/hadoop/mapred-site.xml.template /usr/local/hadoop/etc/hadoop/mapred-site.xml
sed -i '/<configuration>/,/<\/configuration>/c\
<configuration>\
\
<property>\
  <name>mapred.job.tracker<\/name>\
  <value>localhost\:54311<\/value>\
  <description>The host and port that the MapReduce job tracker runs\
  at.  If "local", then jobs are run in-process as a single map\
  and reduce task.\
  <\/description>\
<\/property>\
\
<\/configuration>' /usr/local/hadoop/etc/hadoop/mapred-site.xml
#################################################################################
sed -i '/<configuration>/,/<\/configuration>/c\
<configuration>\
\
<property>\
  <name>dfs.replication<\/name>\
  <value>1<\/value>\
  <description>Default block replication.\
  The actual number of replications can be specified when the file is created.\
  The default is used if replication is not specified in create time.\
  <\/description>\
<\/property>\
\
<\/configuration>' /usr/local/hadoop/etc/hadoop/hdfs-site.xml
##################################################################################

/usr/local/hadoop/bin/hdfs namenode -format
echo -e "\n\e[32mStarting up hadoop server...\e[0m\n"
sudo -u hduser /usr/local/hadoop/sbin/start-dfs.sh
services=$(jps)
if [[ $services == *'NameNode'* ]] && [[ $services == *'DataNode'* ]] && [[ $services == *'SecondaryNameNode'* ]]; then
	echo -e "\n\e[32mAll seems to be running well\e[0m\n"
else
	echo -e "\n\e[31mWell something went wrong with the startup\e[0m\n"
	echo $(jps)
	exit
fi

echo -e "\n\e[32mStopping hadoop server...\e[0m\n"
sudo -u hduser /usr/local/hadoop/sbin/stop-dfs.sh
services=$(jps)
if [[ $services == *'NameNode'* ]] || [[ $services == *'DataNode'* ]] || [[ $services == *'SecondaryNameNode'* ]]; then
	echo -e "\n\e[31mThings seem to be running still\e[0m\n"
	echo $(jps)
else
	echo -e "\n\e[32mHadoop stopped gracefully\e[0m\n"
fi