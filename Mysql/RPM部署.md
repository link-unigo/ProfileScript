安装包下载地址，按照不同的安装方式，下载不同的安装包

[MySQL :: Download MySQL Community Server (Archived Versions)](https://downloads.mysql.com/archives/community/)

### 使用rpm包安装

关闭防火墙

```less
# 查看防火墙状态
systemctl status firewalld.service

# 关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service
```

创建mysql和mysql用户组

```less
# 创建用户组
groupadd mysql

# 创建用户并添加到mysql用户组
useradd -r -g mysql mysql
```

创建mysql数据存储目录并授权给mysql

```less
# 创建mysql数据目录
mkdir -p  /data/mysql

# 目录授权给mysql用户
chown mysql:mysql -R /data/mysql
```

检查系统中是否已经安装了mysql或mariadb（centos默认安装）

```less
rpm -qa | grep -i mysql
rpm -qa | grep -i mariadb
```

卸载mysql或mariadb

```less
rpm -ev mysql* --nodeps
rpm -ev mariadb* --nodeps
```

解压官网下载的rpm压缩包，得到很多不同功能的rpm

```less
tar -xzvf mysql-5.7.34-1.el7.x86_64.rpm-bundle.tar
```

按照需求安装最重要的几个包

```less
rpm -ivh mysql-community-common-5.7.34-1.el7.x86_64.rpm
rpm -ivh mysql-community-libs-5.7.34-1.el7.x86_64.rpm
rpm -ivh mysql-community-client-5.7.34-1.el7.x86_64.rpm
rpm -ivh mysql-community-server-5.7.34-1.el7.x86_64.rpm
```

创建mysql配置文件

```less
vim /etc/my.cnf

[mysqld]
bind-address=0.0.0.0
port=3306
user=mysql
basedir=/usr # 使用rpm方式默认安装路径
datadir=/data/mysql
socket=/tmp/mysql.sock
log-error=/data/mysql/mysql.err
pid-file=/data/mysql/mysql.pid
character_set_server=utf8mb4
symbolic-links=0
explicit_defaults_for_timestamp=true 
lower_case_table_names=1
max_connections=1000
```

mysql服务启动，停止，重启

```less
service mysqld start
service mysqld stop
service mysqld status
```

登录mysql并修改root密码

```less
# mysql服务在第一次启动时，会随机生成一个root，查看这个密码
cat /var/log/mysqld.log | more

# 使用此密码登录mysql
mysql -uroot -p

# 重新设置一个密码
mysql> set password='Pwd@123456';

# 为root用户进行授权外部访问
mysql> update user set host = '%' where user = 'root';
mysql> grant all privileges on *.* to 'root'@'%' identified by 'Pwd@123456';
```