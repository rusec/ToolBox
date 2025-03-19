sed -i -e 's/mirror.centos.org/vault.centos.org/g' -e 's/^#.*baseurl=http/baseurl=http/g' -e 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/CentOS-*.repo
sudo yum update -y
sudo yum install -y epel-release
sudo yum update -y
sudo yum install -y git
sudo yum install -y inotify-tools
sudo yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
sudo yum install -y git

# installing python3.7

sudo yum -y install wget make gcc openssl-devel bzip2-devel
cd /tmp/
wget https://www.python.org/ftp/python/3.7.9/Python-3.7.9.tgz
tar xzf Python-3.7.9.tgz
cd Python-3.7.9
./configure --enable-optimizations
sudo make altinstall

sudo ln -sfn /usr/local/bin/python3.7 /usr/bin/python3.7
sudo ln -sfn /usr/local/bin/pip3.7 /usr/bin/pip3.7

rm -rf /tmp/Python-3.7.9
rm -f /tmp/Python-3.7.9.tgz

cd -
