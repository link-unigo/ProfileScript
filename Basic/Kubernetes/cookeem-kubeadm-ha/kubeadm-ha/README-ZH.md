# kubeadm-high-availiability (English / 中文) - 基于kubeadm的kubernetes高可用集群部署，包含 stacked loadbalancer

![k8s logo](images/kubernetes.png)

- 该指引适用于v1.15.x 以上版本的kubernetes集群

- [English version](README.md)
- [中文版本](README-ZH.md)

---

- [GitHub项目地址](https://github.com/cookeem/kubeadm-ha/)
- [OSChina项目地址](https://git.oschina.net/cookeem/kubeadm-ha/)

## 目录

- [kubeadm-high-availiability (English / 中文) - 基于kubeadm的kubernetes高可用集群部署，包含 stacked loadbalancer](#kubeadm-high-availiability-english--中文---基于kubeadm的kubernetes高可用集群部署包含-stacked-loadbalancer)
  - [目录](#目录)
  - [部署架构](#部署架构)
    - [部署架构概要](#部署架构概要)
    - [主机清单](#主机清单)
    - [版本信息](#版本信息)
  - [安装前准备](#安装前准备)
    - [主机名设置](#主机名设置)
    - [更新软件与系统内核](#更新软件与系统内核)
    - [安装基础软件并配置系统](#安装基础软件并配置系统)
    - [安装docker和kubernetes软件](#安装docker和kubernetes软件)
    - [防火墙配置](#防火墙配置)
    - [系统参数设置](#系统参数设置)
    - [设置master节点互信](#设置master节点互信)
    - [拉取相关镜像](#拉取相关镜像)
  - [安装kubernetes高可用集群](#安装kubernetes高可用集群)
    - [初始化kubernetes集群](#初始化kubernetes集群)
    - [创建高可用kubernetes集群](#创建高可用kubernetes集群)
    - [安装metrics-server组件](#安装metrics-server组件)
    - [安装kubernetes-dashboard组件](#安装kubernetes-dashboard组件)
    - [检查高可用kubernetes集群状态](#检查高可用kubernetes集群状态)

## 部署架构

### 部署架构概要

![](images/kubeadm-ha.svg)

- 包含load balancer的高可用master架构，以keepalived和nginx-lb作为高可用集群的load balancer。
- 需要为keepalived分配一个vip（虚拟浮动ip）作为kubernetes高可用集群的访问入口。
- nginx-lb和keepalived以pod形式直接托管在kubernetes集群中，当出现故障的情况下可以实现自动恢复，提高集群可靠性。

### 主机清单

主机名        | IP地址        | 说明            | 组件
:---         | :---         | :---           | :---
k8s-master01 | 172.20.10.4  | master节点      | keepalived、nginx、kubelet、kube-apiserver、kube-scheduler、kube-controller-manager、etcd
k8s-master02 | 172.20.10.5  | master节点      | keepalived、nginx、kubelet、kube-apiserver、kube-scheduler、kube-controller-manager、etcd
k8s-master03 | 172.20.10.6  | master节点      | keepalived、nginx、kubelet、kube-apiserver、kube-scheduler、kube-controller-manager、etcd
k8s-vip      | 172.20.10.10 | keepalived vip | 无

### 版本信息

- 系统和集群版本

```bash
# Linux发行版信息
$ cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)

# Linux内核版本
$ uname -a
Linux k8s-master01 5.11.0-1.el7.elrepo.x86_64 #1 SMP Sun Feb 14 18:10:38 EST 2021 x86_64 x86_64 x86_64 GNU/Linux

# kubernetes版本
$ kubelet --version
Kubernetes v1.20.2

# docker-ce版本信息
$ docker version
Client: Docker Engine - Community
 Version:           20.10.3
 API version:       1.41
 Go version:        go1.13.15
 Git commit:        48d30b5
 Built:             Fri Jan 29 14:34:14 2021
 OS/Arch:           linux/amd64
 Context:           default
 Experimental:      true

Server: Docker Engine - Community
 Engine:
  Version:          20.10.3
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.13.15
  Git commit:       46229ca
  Built:            Fri Jan 29 14:32:37 2021
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.4.3
  GitCommit:        269548fa27e0089a8b8278fc4fc781d7f65a939b
 runc:
  Version:          1.0.0-rc92
  GitCommit:        ff819c7e9184c13b7c2607fe6c30ae19403a7aff
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0

# docker-compose版本
$ docker-compose version
docker-compose version 1.18.0, build 8dd22a9
docker-py version: 2.6.1
CPython version: 3.6.8
OpenSSL version: OpenSSL 1.0.2k-fips  26 Jan 2017
```

- 组件版本信息

组件                   | 版本      | 备注
:---                  | :---     | :---
calico                | v3.17.2  | 网络组件
metrics-server        | v0.4.2   | 性能采集组件
kubernetes-dashboard  | v2.2.0   | kubernetes管理控制面板

## 安装前准备

### 主机名设置

- 请根据实际情况配置主机名和IP地址，请提前分配一个vip（浮动IP）给keepalived

```bash
#######################
# 非常重要，请务必按照实际情况设置主机名
#######################

# 在k8s-master01节点上设置主机名
$ hostnamectl set-hostname k8s-master01

# 在k8s-master02节点上设置主机名
$ hostnamectl set-hostname k8s-master02

# 在k8s-master03节点上设置主机名
$ hostnamectl set-hostname k8s-master03

#######################
# 非常重要，请务必按照实际情况设置/etc/hosts文件
#######################
# 在所有节点上设置/etc/hosts主机名配置
$ echo '172.20.10.4 k8s-master01' >> /etc/hosts
$ echo '172.20.10.5 k8s-master02' >> /etc/hosts
$ echo '172.20.10.6 k8s-master03' >> /etc/hosts
$ echo '172.20.10.10 k8s-vip' >> /etc/hosts

# 查看/etc/hosts设置
$ cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.20.10.4 k8s-master01
172.20.10.5 k8s-master02
172.20.10.6 k8s-master03
172.20.10.10 k8s-vip
```

### 更新软件与系统内核

- 在所有节点上更新yum源`（本步骤可选）`

```bash
# 备份旧的yum.repos.d
$ mkdir -p /etc/yum.repos.d/bak
$ cd /etc/yum.repos.d
$ mv * bak

# 设置阿里云 centos yum源
$ curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

# 设置阿里云 epel yum源
$ curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# 设置禁用gpgcheck
$ cd /etc/yum.repos.d/
$ find . -name "*.repo" -exec sed -i 's/gpgcheck=1/gpgcheck=0/g' {} \;
```

- 在所有节点上更新软件版本与操作系统内核

```bash
# 在所有节点上更新软件
$ yum -y update

# 在所有节点上设置elrepo的yum源
$ rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
$ rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

# 在所有节点上安装新内核
$ yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
$ yum --enablerepo=elrepo-kernel install -y kernel-ml

# 在所有节点上设置启动选项并重启
$ grub2-mkconfig -o /boot/grub2/grub.cfg
$ grub2-set-default 0
$ reboot

# 确认内核版本
$ uname -a
Linux k8s-master01 5.11.0-1.el7.elrepo.x86_64 #1 SMP Sun Feb 14 18:10:38 EST 2021 x86_64 x86_64 x86_64 GNU/Linux
```

### 安装基础软件并配置系统

- 在所有节点上更新yum源`（本步骤可选）`

```bash
# 备份旧的yum.repos.d
$ mkdir -p /etc/yum.repos.d/bak
$ cd /etc/yum.repos.d
$ mv CentOS-* bak

# 设置阿里云 centos yum源
$ curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

# 设置阿里云 epel yum源
$ curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# 设置阿里云 docker yum源
$ yum install -y yum-utils device-mapper-persistent-data lvm2
$ yum-config-manager -y --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
$ sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo

# 设置阿里云 kubernetes yum源
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# 设置禁用gpgcheck
$ cd /etc/yum.repos.d/
$ find . -name "*.repo" -exec sed -i 's/gpgcheck=1/gpgcheck=0/g' {} \;
```

- 在所有节点上安装基础软件并配置系统

```bash
# 安装基础软件
$ yum install -y htop tree wget jq git net-tools ntpdate nc

# 更新时区
$ timedatectl set-timezone Asia/Shanghai && date && echo 'Asia/Shanghai' > /etc/timezone

# 设置对journal进行持久化
$ sed -i 's/#Storage=auto/Storage=auto/g' /etc/systemd/journald.conf && mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal
$ systemctl restart systemd-journald.service
$ ls -al /var/log/journal

# 设置history显示时间戳
$ echo 'export HISTTIMEFORMAT="%Y-%m-%d %T "' >> ~/.bashrc && source ~/.bashrc
```

### 安装docker和kubernetes软件

- 在所有节点上安装docker和kubernetes软件

```bash
# 安装docker
$ yum search docker-ce --showduplicates
$ yum search docker-compose --showduplicates
$ yum install docker-ce-20.10.3-3.el7.x86_64 docker-compose-1.18.0-4.el7.noarch 
$ systemctl enable docker && systemctl start docker && systemctl status docker

# 重启docker
$ systemctl restart docker

# 检查docker安装情况
$ docker info

# 安装kubernetes
$ yum search kubeadm kubelet --showduplicates
$ yum install -y kubeadm-1.20.2-0.x86_64 kubelet-1.20.2-0.x86_64 kubectl-1.20.2-0.x86_64
$ systemctl enable kubelet && systemctl start kubelet && systemctl status kubelet
```

### 防火墙配置

```bash
########################
# master节点防火墙设置
########################

# 所有master节点开放相关防火墙端口
$ firewall-cmd --zone=public --add-port=6443/tcp --permanent
$ firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=10251/tcp --permanent
$ firewall-cmd --zone=public --add-port=10252/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

# 所有master节点必须开启firewalld该设置，否则dns无法解释
$ firewall-cmd --add-masquerade --permanent
$ firewall-cmd --reload
$ firewall-cmd --list-all --zone=public

########################
# worker节点防火墙设置
########################

# 所有worker节点开放相关防火墙端口
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

# 所有worker节点必须开启firewalld该设置，否则dns无法解释
$ firewall-cmd --add-masquerade --permanent
$ firewall-cmd --reload
$ firewall-cmd --list-all --zone=public

# 所有节点清除iptables规则，解决firewalld引起nodeport无法访问问题
$ iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited

# 所有节点设置root的crontab，每十分钟设置一次
$ echo '5,15,25,35,45,55 * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited' >> /var/spool/cron/root && crontab -l
```

### 系统参数设置

- 所有节点上进行系统参数设置

```bash
# 设置selinux
$ sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
$ setenforce 0
$ getenforce

# 设置sysctl
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# 设置启用sysctl
$ sysctl --system

# 加载br_netfilter模块
$ modprobe br_netfilter

# 禁用swap
$ cat /proc/swaps
$ swapoff -a
$ cat /proc/swaps

# 删除/etc/fstab中的swap分区设置
$ sed -i '/swap/d' /etc/fstab
$ cat /etc/fstab
```

### 设置master节点互信

- master节点设置互信

```bash
# 在所有master节点安装sshpass
$ yum install -y sshpass

# 在所有master节点执行一次ssh，自动创建~/.ssh/known_hosts文件，保证sshpass能够正常运行
$ ssh k8s-master01
$ ssh k8s-master02
$ ssh k8s-master03

# 在k8s-master01上执行
$ export SSHHOST=k8s-master02
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER02 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER02 PASSWORD>" ssh ${SSHHOST}

# 在k8s-master02上执行
$ export SSHHOST=k8s-master03
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER03 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER03 PASSWORD>" ssh ${SSHHOST}

# 在k8s-master03上执行
$ export SSHHOST=k8s-master01
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER01 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER01 PASSWORD>" ssh ${SSHHOST}

# 在k8s-master01上执行，把互信文件复制到所有master节点
$ scp ~/.ssh/authorized_keys k8s-master01:/root/.ssh/
$ scp ~/.ssh/authorized_keys k8s-master02:/root/.ssh/
$ scp ~/.ssh/authorized_keys k8s-master03:/root/.ssh/

# 在所有master节点上验证互信
$ ssh k8s-master01 "hostname && pwd" && \
ssh k8s-master02 "hostname && pwd" && \
ssh k8s-master03 "hostname && pwd" && \
pwd
```

### 拉取相关镜像

```bash
# 查看kubernetes v1.20.2版本所需的所有镜像
$ kubeadm config images list --kubernetes-version=v1.20.2
k8s.gcr.io/kube-apiserver:v1.20.2
k8s.gcr.io/kube-controller-manager:v1.20.2
k8s.gcr.io/kube-scheduler:v1.20.2
k8s.gcr.io/kube-proxy:v1.20.2
k8s.gcr.io/pause:3.2
k8s.gcr.io/etcd:3.4.13-0
k8s.gcr.io/coredns:1.7.0

# 拉取kubernetes相关镜像
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.4.13-0
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.7.0

# 拉取calico相关镜像
$ docker pull quay.io/tigera/operator:v1.13.5
$ docker pull calico/cni:v3.17.2
$ docker pull calico/kube-controllers:v3.17.2
$ docker pull calico/node:v3.17.2
$ docker pull calico/pod2daemon-flexvol:v3.17.2
$ docker pull calico/typha:v3.17.2

# nginx-lb keepalived相关镜像
$ docker pull osixia/keepalived:2.0.20
$ docker pull nginx:1.19.7-alpine

# metrics-server相关镜像
$ docker pull k8s.gcr.io/metrics-server/metrics-server:v0.4.2

# kubernetes-dashboard相关镜像
$ docker pull kubernetesui/dashboard:v2.2.0
$ docker pull kubernetesui/metrics-scraper:v1.0.6
```

## 安装kubernetes高可用集群

### 初始化kubernetes集群

```bash
# 在k8s-master01上拉取kubeadm-ha
$ git clone https://github.com/cookeem/kubeadm-ha.git
$ cd kubeadm-ha

# 在k8s-master01上安装helm
$ cd binary
$ tar zxvf helm-v2.17.0-linux-amd64.tar.gz
$ mv linux-amd64/helm /usr/bin/
$ rm -rf linux-amd64
$ helm --help

# 在k8s-master01上配置k8s-install-info.yaml文件
#######################
# 非常重要，请务必按照实际情况设置k8s-install-info.yaml文件
# 详细说明参见k8s-install-info.yaml文件的备注
#######################
$ cd kubeadm-ha
$ vi k8s-install-info.yaml

# 在k8s-master01上使用helm生成安装配置文件
$ mkdir -p output
$ helm template k8s-install --output-dir output -f k8s-install-info.yaml
$ cd output/k8s-install/templates/

# 在k8s-master01上自动启动所有master节点的keepalived和nginx-lb
$ sed -i '1,2d' create-config.sh
$ sh create-config.sh

# 在所有master节点上检查nginx-lb和keepalived的状态
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED          STATUS          PORTS     NAMES
5b315d2e16a8   nginx:1.19.7-alpine        "/docker-entrypoint.…"   19 seconds ago   Up 19 seconds             nginx-lb
8207dff83965   osixia/keepalived:2.0.20   "/container/tool/run…"   23 seconds ago   Up 22 seconds             keepalived

# k8s-master01上初始化集群
$ kubeadm init --config=kubeadm-config.yaml --upload-certs

# 执行后输出如下内容:
# 记录以下内容，用于master节点和worker节点加入集群
You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 172.20.10.10:16443 --token x9ebjl.ar0xzaygl06ofol5 \
    --discovery-token-ca-cert-hash sha256:2f0d35eb797088593a5c6cdaf817c2936339da6c38f27cfe8c2781aa8638c262 \
    --control-plane --certificate-key 2ff8f25d4e2e4adf495c2438fe98761336f6b5fdf8d3eee3092f6e0bdfc28b07

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.20.10.10:16443 --token x9ebjl.ar0xzaygl06ofol5 \
    --discovery-token-ca-cert-hash sha256:2f0d35eb797088593a5c6cdaf817c2936339da6c38f27cfe8c2781aa8638c262 

# 所有master节点设置KUBECONFIG环境变量
$ cat <<EOF >> ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF
$ source ~/.bashrc

# 等待除coredns外所有pod Running
# 未安装网络组件coredns会处于ContainerCreating状态
$ kubectl get pods -A
NAMESPACE     NAME                                   READY   STATUS              RESTARTS   AGE
kube-system   coredns-54d67798b7-b4g55               0/1     ContainerCreating   0          93s
kube-system   coredns-54d67798b7-sflfm               0/1     ContainerCreating   0          93s
kube-system   etcd-k8s-master01                      1/1     Running             0          89s
kube-system   kube-apiserver-k8s-master01            1/1     Running             0          89s
kube-system   kube-controller-manager-k8s-master01   1/1     Running             0          89s
kube-system   kube-proxy-n8g5l                       1/1     Running             0          93s
kube-system   kube-scheduler-k8s-master01            1/1     Running             0          89s

# k8s-master01上安装calico网络
$ kubectl apply -f calico-v3.17.2/tigera-operator.yaml
$ sleep 1
$ kubectl apply -f calico-v3.17.2/custom-resources.yaml

# 安装calico网络组件后，所有pods处于Running
$ kubectl get pods -A
NAMESPACE         NAME                                      READY   STATUS    RESTARTS   AGE
calico-system     calico-kube-controllers-56689cf96-j2j6x   1/1     Running   0          28s
calico-system     calico-node-dhzlb                         1/1     Running   0          28s
calico-system     calico-typha-6465c44b98-t2zkg             1/1     Running   0          29s
kube-system       coredns-54d67798b7-b4g55                  1/1     Running   0          3m10s
kube-system       coredns-54d67798b7-sflfm                  1/1     Running   0          3m10s
kube-system       etcd-k8s-master01                         1/1     Running   0          3m6s
kube-system       kube-apiserver-k8s-master01               1/1     Running   0          3m6s
kube-system       kube-controller-manager-k8s-master01      1/1     Running   0          3m6s
kube-system       kube-proxy-n8g5l                          1/1     Running   0          3m10s
kube-system       kube-scheduler-k8s-master01               1/1     Running   0          3m6s
tigera-operator   tigera-operator-7c5d47c4b5-mh228          1/1     Running   0          39s
```

### 创建高可用kubernetes集群

```bash
# k8s-master02和k8s-master03节点上，执行命令，加入到kubernetes集群的control-plane
# 一个一个master节点执行，等待所有pods处于Running状态后再执行下一个节点
$ kubeadm join xxxx --token xxxx \
  --discovery-token-ca-cert-hash xxxx \
  --control-plane --certificate-key xxxx

# 等待所有节点的pods正常
$ kubectl get pods -A
NAMESPACE         NAME                                      READY   STATUS    RESTARTS   AGE
calico-system     calico-kube-controllers-56689cf96-7kg7m   1/1     Running   0          5m15s
calico-system     calico-node-7rmx5                         1/1     Running   0          100s
calico-system     calico-node-b2zgm                         1/1     Running   0          4m9s
calico-system     calico-node-cvhjh                         1/1     Running   0          5m15s
calico-system     calico-typha-7d575cf88c-2fx47             1/1     Running   0          3m22s
calico-system     calico-typha-7d575cf88c-9zh72             1/1     Running   0          5m16s
calico-system     calico-typha-7d575cf88c-w5qmz             1/1     Running   0          90s
kube-system       coredns-54d67798b7-pqwl6                  1/1     Running   0          7m1s
kube-system       coredns-54d67798b7-x7gvn                  1/1     Running   0          7m1s
kube-system       etcd-k8s-master01                         1/1     Running   0          6m57s
kube-system       etcd-k8s-master02                         1/1     Running   0          4m4s
kube-system       etcd-k8s-master03                         1/1     Running   0          98s
kube-system       kube-apiserver-k8s-master01               1/1     Running   0          6m57s
kube-system       kube-apiserver-k8s-master02               1/1     Running   0          4m9s
kube-system       kube-apiserver-k8s-master03               1/1     Running   0          100s
kube-system       kube-controller-manager-k8s-master01      1/1     Running   1          6m57s
kube-system       kube-controller-manager-k8s-master02      1/1     Running   0          4m9s
kube-system       kube-controller-manager-k8s-master03      1/1     Running   0          100s
kube-system       kube-proxy-gdskl                          1/1     Running   0          4m9s
kube-system       kube-proxy-wq8vt                          1/1     Running   0          7m1s
kube-system       kube-proxy-xxtcw                          1/1     Running   0          100s
kube-system       kube-scheduler-k8s-master01               1/1     Running   1          6m57s
kube-system       kube-scheduler-k8s-master02               1/1     Running   0          4m4s
kube-system       kube-scheduler-k8s-master03               1/1     Running   0          100s
tigera-operator   tigera-operator-7c5d47c4b5-nmb8b          1/1     Running   1          5m24s

# 等待所有nodes正常
$ kubectl get nodes
NAME           STATUS   ROLES                  AGE     VERSION
k8s-master01   Ready    control-plane,master   6m56s   v1.20.2
k8s-master02   Ready    control-plane,master   3m59s   v1.20.2
k8s-master03   Ready    control-plane,master   90s     v1.20.2

# 所有master节点上设置kubectl自动完成
$ kubectl get pods
$ yum install -y bash-completion && mkdir -p ~/.kube/
$ kubectl completion bash > ~/.kube/completion.bash.inc
$ printf "
# Kubectl shell completion
source '$HOME/.kube/completion.bash.inc'
" >> $HOME/.bash_profile
$ source $HOME/.bash_profile

# 所有master节点需要退出登录，然后重新登录
$ exit

# 在k8s-master01节点上允许master部署pod
$ kubectl taint nodes --all node-role.kubernetes.io/master-

# 在所有master节点上使用kubelet自动创建keepalived和nginx-lb的pod
$ mv /etc/kubernetes/keepalived/ /etc/kubernetes/manifests/
$ mv /etc/kubernetes/manifests/keepalived/keepalived.yaml /etc/kubernetes/manifests/
$ mv /etc/kubernetes/nginx-lb/ /etc/kubernetes/manifests/
$ mv /etc/kubernetes/manifests/nginx-lb/nginx-lb.yaml /etc/kubernetes/manifests/

# 查看/etc/kubernetes/manifests/下的配置文件
$ tree /etc/kubernetes/manifests/
/etc/kubernetes/manifests/
├── etcd.yaml
├── keepalived
│   ├── check_apiserver.sh
│   ├── docker-compose.yaml
│   └── keepalived.conf
├── keepalived.yaml
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
├── kube-scheduler.yaml
├── nginx-lb
│   ├── docker-compose.yaml
│   └── nginx-lb.conf
└── nginx-lb.yaml

#######################
# 非常重要，请务必等待nginx-lb-k8s-masterX和keepalived-k8s-masterX的pod都处于Running状态
#######################
$ kubectl get pods -n kube-system
NAME                                   READY   STATUS    RESTARTS   AGE
keepalived-k8s-master01                1/1     Running   0          13s
keepalived-k8s-master02                1/1     Running   0          11s
keepalived-k8s-master03                1/1     Running   0          8s
nginx-lb-k8s-master01                  1/1     Running   0          13s
nginx-lb-k8s-master02                  1/1     Running   0          11s
nginx-lb-k8s-master03                  1/1     Running   0          8s

# 在所有master节点上检查master节点的keepalived和nginx-lb的pod已经自动创建后，再进行以下操作
$ systemctl stop kubelet
$ docker rm -f keepalived nginx-lb
$ systemctl restart kubelet

# 等待并检查pods状态，新增了keepalived和nginx-lb的pods
$ kubectl get pods -n kube-system
NAME                                   READY   STATUS    RESTARTS   AGE
coredns-54d67798b7-pqwl6               1/1     Running   0          10m
coredns-54d67798b7-x7gvn               1/1     Running   0          10m
etcd-k8s-master01                      1/1     Running   0          10m
etcd-k8s-master02                      1/1     Running   0          7m14s
etcd-k8s-master03                      1/1     Running   0          4m48s
keepalived-k8s-master01                1/1     Running   0          2m21s
keepalived-k8s-master02                1/1     Running   0          2m19s
keepalived-k8s-master03                1/1     Running   0          2m17s
kube-apiserver-k8s-master01            1/1     Running   0          10m
kube-apiserver-k8s-master02            1/1     Running   0          7m19s
kube-apiserver-k8s-master03            1/1     Running   0          4m50s
kube-controller-manager-k8s-master01   1/1     Running   1          10m
kube-controller-manager-k8s-master02   1/1     Running   0          7m19s
kube-controller-manager-k8s-master03   1/1     Running   0          4m50s
kube-proxy-gdskl                       1/1     Running   0          7m19s
kube-proxy-wq8vt                       1/1     Running   0          10m
kube-proxy-xxtcw                       1/1     Running   0          4m50s
kube-scheduler-k8s-master01            1/1     Running   1          10m
kube-scheduler-k8s-master02            1/1     Running   0          7m14s
kube-scheduler-k8s-master03            1/1     Running   0          4m50s
nginx-lb-k8s-master01                  1/1     Running   0          2m21s
nginx-lb-k8s-master02                  1/1     Running   0          2m19s
nginx-lb-k8s-master03                  1/1     Running   0          2m17s

# 测试nginx-lb和keepalived
$ curl -k https://k8s-vip:16443
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Failure",
  "message": "forbidden: User \"system:anonymous\" cannot get path \"/\"",
  "reason": "Forbidden",
  "details": {

  },
  "code": 403
}

# 在所有master节点上修改/etc/kubernetes/admin.conf
$ sed -i 's/:16443/:6443/g' /etc/kubernetes/admin.conf

# 在所有worker节点上执行join
$ kubeadm join xxxx --token xxxx \
    --discovery-token-ca-cert-hash xxxx
```

### 安装metrics-server组件

```bash
# 安装metrics-server
$ cd kubeadm-ha
$ kubectl apply -f addons/metrics-server.yaml

# 等待一分钟左右后，查看pods的性能度量
$ kubectl top pods -A
NAMESPACE         NAME                                      CPU(cores)   MEMORY(bytes)   
calico-system     calico-kube-controllers-56689cf96-7kg7m   4m           11Mi            
calico-system     calico-node-7rmx5                         61m          55Mi            
calico-system     calico-node-b2zgm                         58m          50Mi            
calico-system     calico-node-cvhjh                         51m          57Mi            
calico-system     calico-typha-7d575cf88c-2fx47             4m           17Mi            
calico-system     calico-typha-7d575cf88c-9zh72             9m           19Mi            
calico-system     calico-typha-7d575cf88c-w5qmz             14m          18Mi            
kube-system       coredns-54d67798b7-pqwl6                  12m          10Mi            
kube-system       coredns-54d67798b7-x7gvn                  14m          9Mi             
kube-system       etcd-k8s-master01                         170m         67Mi            
kube-system       etcd-k8s-master02                         99m          68Mi            
kube-system       etcd-k8s-master03                         124m         57Mi            
kube-system       keepalived-k8s-master01                   1m           8Mi             
kube-system       keepalived-k8s-master02                   1m           7Mi             
kube-system       keepalived-k8s-master03                   1m           7Mi             
kube-system       kube-apiserver-k8s-master01               581m         329Mi           
kube-system       kube-apiserver-k8s-master02               726m         348Mi           
kube-system       kube-apiserver-k8s-master03               181m         244Mi           
kube-system       kube-controller-manager-k8s-master01      7m           18Mi            
kube-system       kube-controller-manager-k8s-master02      71m          50Mi            
kube-system       kube-controller-manager-k8s-master03      7m           18Mi            
kube-system       kube-proxy-gdskl                          34m          14Mi            
kube-system       kube-proxy-wq8vt                          58m          12Mi            
kube-system       kube-proxy-xxtcw                          2m           14Mi            
kube-system       kube-scheduler-k8s-master01               12m          16Mi            
kube-system       kube-scheduler-k8s-master02               8m           17Mi            
kube-system       kube-scheduler-k8s-master03               9m           14Mi            
kube-system       metrics-server-5bb577dbd8-vn266           0m           0Mi             
kube-system       nginx-lb-k8s-master01                     7m           1Mi             
kube-system       nginx-lb-k8s-master02                     1m           1Mi             
kube-system       nginx-lb-k8s-master03                     1m           1Mi             
tigera-operator   tigera-operator-7c5d47c4b5-nmb8b          6m           22Mi            
```

### 安装kubernetes-dashboard组件

```bash
# 安装kubernetes-dashboard
$ cd kubeadm-ha
$ cd addons

# 设置kubernetes-dashboard证书
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/CN=dashboard"
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout dashboard.key -out dashboard.csr -subj "/CN=dashboard"
# 注意设置vip的ip地址和主机名
$ export VIPADDR=172.20.10.10
$ export VIPHOST=k8s-vip
$ echo "subjectAltName = DNS: dashboard, DNS: ${VIPHOST}, IP: ${VIPADDR}" > extfile.cnf
$ openssl x509 -req -days 3650 -in dashboard.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out dashboard.crt

# 创建kubernetes-dashboard证书
$ kubectl create namespace kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
$ kubectl create secret generic kubernetes-dashboard-certs --from-file=dashboard.key --from-file=dashboard.crt -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -

# 安装kubernetes-dashboard
$ kubectl apply -f kubernetes-dashboard.yaml

# 检查kubernetes-dashboard安装情况
$ kubectl -n kubernetes-dashboard get pods,services
NAME                                             READY   STATUS    RESTARTS   AGE
pod/dashboard-metrics-scraper-79c5968bdc-xxf45   1/1     Running   0          22s
pod/kubernetes-dashboard-7cb9fd9999-lqgw9        1/1     Running   0          22s

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
service/dashboard-metrics-scraper   ClusterIP   10.109.137.59    <none>        8000/TCP        22s
service/kubernetes-dashboard        NodePort    10.108.252.248   <none>        443:30000/TCP   23s

# 获取admin-user的token，用于登录kubernetes-dashboard
$ kubectl -n kube-system get secrets $(kubectl -n kube-system get serviceaccounts admin-user -o=jsonpath='{.secrets[0].name}') -o=jsonpath='{.data.token}' | base64 -d
```

- 使用token登录kubernetes-dashboard

kubernetes-dashboard访问URL: https://k8s-vip:30000

- 打开浏览器，使用token登录kubernetes-dashboard

![](images/kubernetes-dashboard-login.png)

- 打开浏览器查看kubernetes-dashboard

![](images/kubernetes-dashboard-pods.png)

### 检查高可用kubernetes集群状态

```bash
# 查看所有pods的状态信息
$ kubectl get pods -A -o wide
NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE     IP                NODE           NOMINATED NODE   READINESS GATES
calico-system          calico-kube-controllers-56689cf96-7kg7m      1/1     Running   0          43m     193.169.32.129    k8s-master01   <none>           <none>
calico-system          calico-node-7rmx5                            1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
calico-system          calico-node-b2zgm                            1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
calico-system          calico-node-cvhjh                            1/1     Running   0          43m     172.20.10.4       k8s-master01   <none>           <none>
calico-system          calico-typha-7d575cf88c-2fx47                1/1     Running   0          41m     172.20.10.5       k8s-master02   <none>           <none>
calico-system          calico-typha-7d575cf88c-9zh72                1/1     Running   0          43m     172.20.10.4       k8s-master01   <none>           <none>
calico-system          calico-typha-7d575cf88c-w5qmz                1/1     Running   0          39m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            coredns-54d67798b7-pqwl6                     1/1     Running   0          45m     193.169.32.130    k8s-master01   <none>           <none>
kube-system            coredns-54d67798b7-x7gvn                     1/1     Running   0          45m     193.169.32.131    k8s-master01   <none>           <none>
kube-system            etcd-k8s-master01                            1/1     Running   0          45m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            etcd-k8s-master02                            1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            etcd-k8s-master03                            1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            keepalived-k8s-master01                      1/1     Running   0          37m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            keepalived-k8s-master02                      1/1     Running   0          37m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            keepalived-k8s-master03                      1/1     Running   0          37m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            kube-apiserver-k8s-master01                  1/1     Running   0          45m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            kube-apiserver-k8s-master02                  1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            kube-apiserver-k8s-master03                  1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            kube-controller-manager-k8s-master01         1/1     Running   1          45m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            kube-controller-manager-k8s-master02         1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            kube-controller-manager-k8s-master03         1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            kube-proxy-gdskl                             1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            kube-proxy-wq8vt                             1/1     Running   0          45m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            kube-proxy-xxtcw                             1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            kube-scheduler-k8s-master01                  1/1     Running   1          45m     172.20.10.4       k8s-master01   <none>           <none>
kube-system            kube-scheduler-k8s-master02                  1/1     Running   0          42m     172.20.10.5       k8s-master02   <none>           <none>
kube-system            kube-scheduler-k8s-master03                  1/1     Running   0          40m     172.20.10.6       k8s-master03   <none>           <none>
kube-system            metrics-server-5bb577dbd8-vn266              1/1     Running   0          34m     193.169.122.130   k8s-master02   <none>           <none>
kube-system            nginx-lb-k8s-master01                        1/1     Running   0          37m     193.169.32.132    k8s-master01   <none>           <none>
kube-system            nginx-lb-k8s-master02                        1/1     Running   0          37m     193.169.122.129   k8s-master02   <none>           <none>
kube-system            nginx-lb-k8s-master03                        1/1     Running   0          37m     193.169.195.1     k8s-master03   <none>           <none>
kubernetes-dashboard   dashboard-metrics-scraper-79c5968bdc-xxf45   1/1     Running   0          8m39s   193.169.122.133   k8s-master02   <none>           <none>
kubernetes-dashboard   kubernetes-dashboard-7cb9fd9999-lqgw9        1/1     Running   0          8m39s   193.169.195.6     k8s-master03   <none>           <none>
tigera-operator        tigera-operator-7c5d47c4b5-nmb8b             1/1     Running   1          43m     172.20.10.4       k8s-master01   <none>           <none>

# 查看所有nodes的状态信息
$ kubectl get nodes -o wide
NAME           STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION               CONTAINER-RUNTIME
k8s-master01   Ready    control-plane,master   23m   v1.20.2   172.20.10.4   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
k8s-master02   Ready    control-plane,master   20m   v1.20.2   172.20.10.5   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
k8s-master03   Ready    control-plane,master   18m   v1.20.2   172.20.10.6   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
```
