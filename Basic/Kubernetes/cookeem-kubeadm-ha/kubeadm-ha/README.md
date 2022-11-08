# kubeadm-high-availiability (English / 中文) - kubernetes high availiability deployment based on kubeadm, stacked loadbalancer included

![k8s logo](images/kubernetes.png)

- For kubernetes v1.15+

- [English version](README.md)
- [中文 version ](README-ZH.md)

---

- [GitHub project URL](https://github.com/cookeem/kubeadm-ha/)
- [OSChina project URL](https://git.oschina.net/cookeem/kubeadm-ha/)

## category

- [kubeadm-high-availiability (English / 中文) - kubernetes high availiability deployment based on kubeadm, stacked loadbalancer included](#kubeadm-high-availiability-english--中文---kubernetes-high-availiability-deployment-based-on-kubeadm-stacked-loadbalancer-included)
  - [category](#category)
  - [deployment architecture](#deployment-architecture)
    - [deployment architecture summary](#deployment-architecture-summary)
    - [hosts list](#hosts-list)
    - [version info](#version-info)
  - [prerequisites](#prerequisites)
    - [hostname settings](#hostname-settings)
    - [update software and linux kernel](#update-software-and-linux-kernel)
    - [install required softwares and configurate linux](#install-required-softwares-and-configurate-linux)
    - [install docker and kubernetes softwares](#install-docker-and-kubernetes-softwares)
    - [firewalld configuration](#firewalld-configuration)
    - [linux system configuration](#linux-system-configuration)
    - [master nodes mutual trust](#master-nodes-mutual-trust)
    - [pull relative docker images](#pull-relative-docker-images)
  - [install kubernetes high-availiability cluster](#install-kubernetes-high-availiability-cluster)
    - [initial kubernetes cluster](#initial-kubernetes-cluster)
    - [bootstrap high-availiability kubernetes cluster](#bootstrap-high-availiability-kubernetes-cluster)
    - [install metrics-server component](#install-metrics-server-component)
    - [install kubernetes-dashboard component](#install-kubernetes-dashboard-component)
    - [check kubernetes cluster status](#check-kubernetes-cluster-status)

## deployment architecture

### deployment architecture summary

![](images/kubeadm-ha.svg)

- load balancer included high-availiability architecture, use keepalived and nginx as cluster load balancer.
- require one vip(virtual IP address) for keepalived, this vip is the access point of kubernetes high-availability cluster.
- nginx-lb and keepalived self-hosted in kubernetes cluster as pods, in case of failure, it can realize automatic recovery and improve cluster reliability.

### hosts list

Hostname     | IP address   | Comments       | Components
:---         | :---         | :---           | :---
k8s-master01 | 172.20.10.4  | master node    | keepalived, nginx, kubelet, apiserver, scheduler, controller-manager, etcd
k8s-master02 | 172.20.10.5  | master node    | keepalived, nginx, kubelet, apiserver, scheduler, controller-manager, etcd
k8s-master03 | 172.20.10.6  | master node    | keepalived, nginx, kubelet, apiserver, scheduler, controller-manager, etcd
k8s-vip      | 172.20.10.10 | keepalived vip | None

### version info

- Linux and cluster version info

```bash
# Linux release version
$ cat /etc/redhat-release
CentOS Linux release 7.9.2009 (Core)

# Linux kernel version
$ uname -a
Linux k8s-master01 5.11.0-1.el7.elrepo.x86_64 #1 SMP Sun Feb 14 18:10:38 EST 2021 x86_64 x86_64 x86_64 GNU/Linux

# kubernetes version
$ kubelet --version
Kubernetes v1.20.2

# docker-ce version
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

# docker-compose version 
$ docker-compose version
docker-compose version 1.18.0, build 8dd22a9
docker-py version: 2.6.1
CPython version: 3.6.8
OpenSSL version: OpenSSL 1.0.2k-fips  26 Jan 2017
```

- components version

Components            | Version  | Comments
:---                  | :---     | :---
calico                | v3.17.2  | network components
metrics-server        | v0.4.2   | metrics collection components
kubernetes-dashboard  | v2.2.0   | kubernetes dashboard webUI

## prerequisites

### hostname settings

- please configure the hostname and IP address according to the actual situation, please assign a vip (virtual IP address) to keepalived in advance.

```bash
#######################
# Very important, please be sure to set the hostname according to the actual situation
#######################

# execute on k8s-master01: set hostname
$ hostnamectl set-hostname k8s-master01

# execute on k8s-master02: set hostname
$ hostnamectl set-hostname k8s-master02

# execute on k8s-master03: set hostname
$ hostnamectl set-hostname k8s-master03

#######################
# Very important, please be sure to set /etc/hosts file
#######################
# execute on all nodes: set /etc/hosts
$ echo '172.20.10.4 k8s-master01' >> /etc/hosts
$ echo '172.20.10.5 k8s-master02' >> /etc/hosts
$ echo '172.20.10.6 k8s-master03' >> /etc/hosts
$ echo '172.20.10.10 k8s-vip' >> /etc/hosts

# view /etc/hosts file
$ cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.20.10.4 k8s-master01
172.20.10.5 k8s-master02
172.20.10.6 k8s-master03
172.20.10.10 k8s-vip
```

### update software and linux kernel

- execute on all nodes: update yum repositories `(Optional)`

```bash
# backup old yum.repos.d files
$ mkdir -p /etc/yum.repos.d/bak
$ cd /etc/yum.repos.d
$ mv * bak

# set aliyun centos yum repos
$ curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

# set aliyun epel yum repos
$ curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# disabled gpgcheck
$ cd /etc/yum.repos.d/
$ find . -name "*.repo" -exec sed -i 's/gpgcheck=1/gpgcheck=0/g' {} \;
```

- execute on all nodes: upgrade all softwares and linux kernel

```bash
# execute on all nodes: upgrade all softwares
$ yum -y update

# execute on all nodes: set elrepo yum repos
$ rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
$ rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

# execute on all nodes: upgrade linux kernel
$ yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
$ yum --enablerepo=elrepo-kernel install -y kernel-ml

# execute on all nodes: set startup options then reboot
$ grub2-mkconfig -o /boot/grub2/grub.cfg
$ grub2-set-default 0
$ reboot

# verify linux kernel version 
$ uname -a
Linux k8s-master01 5.11.0-1.el7.elrepo.x86_64 #1 SMP Sun Feb 14 18:10:38 EST 2021 x86_64 x86_64 x86_64 GNU/Linux
```

### install required softwares and configurate linux

- execute on all nodes: update yum repositories `(Optional)`

```bash
# backup old yum.repos.d files
$ mkdir -p /etc/yum.repos.d/bak
$ cd /etc/yum.repos.d
$ mv CentOS-* bak

# set aliyun centos yum repos
$ curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

# set aliyun epel yum repos
$ curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo

# set aliyun docker yum repos
$ yum install -y yum-utils device-mapper-persistent-data lvm2
$ yum-config-manager -y --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
$ sudo sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo

# set aliyun kubernetes yum repos
$ cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# disabled gpgcheck
$ cd /etc/yum.repos.d/
$ find . -name "*.repo" -exec sed -i 's/gpgcheck=1/gpgcheck=0/g' {} \;
```

- execute on all nodes: install basic softwares and configure the system

```bash
# install basic softwares
$ yum install -y htop tree wget jq git net-tools ntpdate nc

# update system timezone
$ timedatectl set-timezone Asia/Shanghai && date && echo 'Asia/Shanghai' > /etc/timezone

# persistence of the journal logs
$ sed -i 's/#Storage=auto/Storage=auto/g' /etc/systemd/journald.conf && mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal
$ systemctl restart systemd-journald.service
$ ls -al /var/log/journal

# set history to show timestamp
$ echo 'export HISTTIMEFORMAT="%Y-%m-%d %T "' >> ~/.bashrc && source ~/.bashrc
```

### install docker and kubernetes softwares

- execute on all nodes: install docker and kubernetes softwares

```bash
# install docker software
$ yum search docker-ce --showduplicates
$ yum search docker-compose --showduplicates
$ yum install docker-ce-20.10.3-3.el7.x86_64 docker-compose-1.18.0-4.el7.noarch 
$ systemctl enable docker && systemctl start docker && systemctl status docker

# restart docker daemon
$ systemctl restart docker

# verify docker status
$ docker info

# install kubernetes software
$ yum search kubeadm kubelet --showduplicates
$ yum install -y kubeadm-1.20.2-0.x86_64 kubelet-1.20.2-0.x86_64 kubectl-1.20.2-0.x86_64
$ systemctl enable kubelet && systemctl start kubelet && systemctl status kubelet
```

### firewalld configuration

```bash
########################
# master nodes firewalld settings
########################

# execute on all master nodes: enable relative firewall ports
$ firewall-cmd --zone=public --add-port=6443/tcp --permanent
$ firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=10251/tcp --permanent
$ firewall-cmd --zone=public --add-port=10252/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

# execute on all master nodes: enable masquerade to make dns works
$ firewall-cmd --add-masquerade --permanent
$ firewall-cmd --reload
$ firewall-cmd --list-all --zone=public

########################
# worker nodes firewalld settings
########################

# execute on all worker nodes: nable relative firewall ports
$ firewall-cmd --zone=public --add-port=10250/tcp --permanent
$ firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent

# execute on all worker nodes: enable masquerade to make dns works
$ firewall-cmd --add-masquerade --permanent
$ firewall-cmd --reload
$ firewall-cmd --list-all --zone=public

# execute on all nodes: remove iptables rules
$ iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited

# execute on all nodes: set root crontab, set once every 10 minutes
$ echo '5,15,25,35,45,55 * * * * /usr/sbin/iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited' >> /var/spool/cron/root && crontab -l
```

### linux system configuration

- linux system settings on all nodes

```bash
# selinux settings
$ sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
$ setenforce 0
$ getenforce

# sysctl settings
$ cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# write sysctl
$ sysctl --system

# load br_netfilter module
$ modprobe br_netfilter

# disable swap
$ cat /proc/swaps
$ swapoff -a
$ cat /proc/swaps

# remove swap partition settings in /etc/fstab files
$ sed -i '/swap/d' /etc/fstab
$ cat /etc/fstab
```

### master nodes mutual trust

- master nodes setting mutual trust

```bash
# execute on all master nodes: install sshpass software
$ yum install -y sshpass

# execute on all master nodes: run ssh command first, before run sshpass command
$ ssh k8s-master01
$ ssh k8s-master02
$ ssh k8s-master03

# execute on k8s-master01: generate authorized keys
$ export SSHHOST=k8s-master02
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER02 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER02 PASSWORD>" ssh ${SSHHOST}

# execute on k8s-master02: generate authorized keys
$ export SSHHOST=k8s-master03
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER03 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER03 PASSWORD>" ssh ${SSHHOST}

# execute on k8s-master03: generate authorized keys
$ export SSHHOST=k8s-master01
$ ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
$ sshpass -p "<MASTER01 PASSWORD>" scp ~/.ssh/authorized_keys root@${SSHHOST}:~/.ssh/
$ sshpass -p "<MASTER01 PASSWORD>" ssh ${SSHHOST}

# execute on k8s-master01: copy authorized keys files to all master nodes
$ scp ~/.ssh/authorized_keys k8s-master01:/root/.ssh/
$ scp ~/.ssh/authorized_keys k8s-master02:/root/.ssh/
$ scp ~/.ssh/authorized_keys k8s-master03:/root/.ssh/

# execute on all master nodes: verify mutual trust result
$ ssh k8s-master01 "hostname && pwd" && \
ssh k8s-master02 "hostname && pwd" && \
ssh k8s-master03 "hostname && pwd" && \
pwd
```

### pull relative docker images

```bash
# check kubernetes v1.20.2 all required docker images
$ kubeadm config images list --kubernetes-version=v1.20.2
k8s.gcr.io/kube-apiserver:v1.20.2
k8s.gcr.io/kube-controller-manager:v1.20.2
k8s.gcr.io/kube-scheduler:v1.20.2
k8s.gcr.io/kube-proxy:v1.20.2
k8s.gcr.io/pause:3.2
k8s.gcr.io/etcd:3.4.13-0
k8s.gcr.io/coredns:1.7.0

# pull kubernetes docker images
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.20.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.2
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.4.13-0
$ docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.7.0

# pull calico docker images
$ docker pull quay.io/tigera/operator:v1.13.5
$ docker pull calico/cni:v3.17.2
$ docker pull calico/kube-controllers:v3.17.2
$ docker pull calico/node:v3.17.2
$ docker pull calico/pod2daemon-flexvol:v3.17.2
$ docker pull calico/typha:v3.17.2

# pull nginx-lb keepalived docker images
$ docker pull osixia/keepalived:2.0.20
$ docker pull nginx:1.19.7-alpine

# pull metrics-server docker images
$ docker pull k8s.gcr.io/metrics-server/metrics-server:v0.4.2

# pull kubernetes-dashboard docker images
$ docker pull kubernetesui/dashboard:v2.2.0
$ docker pull kubernetesui/metrics-scraper:v1.0.6
```

## install kubernetes high-availiability cluster

### initial kubernetes cluster

```bash
# execute on k8s-master01: git clone kubeadm-ha repository
$ git clone https://github.com/cookeem/kubeadm-ha.git
$ cd kubeadm-ha

# execute on k8s-master01: install helm
$ cd binary
$ tar zxvf helm-v2.17.0-linux-amd64.tar.gz
$ mv linux-amd64/helm /usr/bin/
$ rm -rf linux-amd64
$ helm --help

# execute on k8s-master01: configurate k8s-install-info.yaml file
#######################
# Very important, please set the k8s-install-info.yaml file according to the actual situation
# please read the comments in k8s-install-info.yaml carefully
#######################
$ cd kubeadm-ha
$ vi k8s-install-info.yaml

# execute on k8s-master01: use helm to create all install configuration files
$ mkdir -p output
$ helm template k8s-install --output-dir output -f k8s-install-info.yaml
$ cd output/k8s-install/templates/

# execute on k8s-master01: use docker-compose to bootstrap keepalived and nginx-lb services on all master nodes
$ sed -i '1,2d' create-config.sh
$ sh create-config.sh

# execute on all master nodes: verify nginx-lb and keepalived services status
$ docker ps
CONTAINER ID   IMAGE                      COMMAND                  CREATED          STATUS          PORTS     NAMES
5b315d2e16a8   nginx:1.19.7-alpine        "/docker-entrypoint.…"   19 seconds ago   Up 19 seconds             nginx-lb
8207dff83965   osixia/keepalived:2.0.20   "/container/tool/run…"   23 seconds ago   Up 22 seconds             keepalived

# execute on k8s-master01: initial kubernetes cluster on first control-plane node
$ kubeadm init --config=kubeadm-config.yaml --upload-certs

# after executing the command, the output is as follows:
# mark down the following content for the master node and worker node to join the cluster
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

# execute on all master nodes: set KUBECONFIG environment variables for kubectl
$ cat <<EOF >> ~/.bashrc
export KUBECONFIG=/etc/kubernetes/admin.conf
EOF
$ source ~/.bashrc

# waiting all pods as Running status except coredns pods
# if the network component is not installed, coredns will be in the ContainerCreating state
$ kubectl get pods -A
NAMESPACE     NAME                                   READY   STATUS              RESTARTS   AGE
kube-system   coredns-54d67798b7-b4g55               0/1     ContainerCreating   0          93s
kube-system   coredns-54d67798b7-sflfm               0/1     ContainerCreating   0          93s
kube-system   etcd-k8s-master01                      1/1     Running             0          89s
kube-system   kube-apiserver-k8s-master01            1/1     Running             0          89s
kube-system   kube-controller-manager-k8s-master01   1/1     Running             0          89s
kube-system   kube-proxy-n8g5l                       1/1     Running             0          93s
kube-system   kube-scheduler-k8s-master01            1/1     Running             0          89s

# execute on k8s-master01: install calico network component
$ kubectl apply -f calico-v3.17.2/tigera-operator.yaml
$ sleep 1
$ kubectl apply -f calico-v3.17.2/custom-resources.yaml

# after calico network component installed, all pods should be Running state
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

### bootstrap high-availiability kubernetes cluster

```bash
# execute on k8s-master02 and k8s-master03 one by one: join master nodes to kubernetes cluster control-plane
# join one by one until all pods in Running state
$ kubeadm join xxxx --token xxxx \
  --discovery-token-ca-cert-hash xxxx \
  --control-plane --certificate-key xxxx

# waiting for all pods status to be Running
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

# waiting for all nodes status to be Ready
$ kubectl get nodes
NAME           STATUS   ROLES                  AGE     VERSION
k8s-master01   Ready    control-plane,master   6m56s   v1.20.2
k8s-master02   Ready    control-plane,master   3m59s   v1.20.2
k8s-master03   Ready    control-plane,master   90s     v1.20.2

# execute on all master nodes: kubectl autocompletion settings
$ kubectl get pods
$ yum install -y bash-completion && mkdir -p ~/.kube/
$ kubectl completion bash > ~/.kube/completion.bash.inc
$ printf "
# Kubectl shell completion
source '$HOME/.kube/completion.bash.inc'
" >> $HOME/.bash_profile
$ source $HOME/.bash_profile

# execute on all master nodes: please exit shell to make it works
$ exit

# execute on k8s-master01: enable pods schedule on master nodes
$ kubectl taint nodes --all node-role.kubernetes.io/master-

# execute on all master nodes: use kubelet to automatically create keepalived and nginx-lb pods
$ mv /etc/kubernetes/keepalived/ /etc/kubernetes/manifests/
$ mv /etc/kubernetes/manifests/keepalived/keepalived.yaml /etc/kubernetes/manifests/
$ mv /etc/kubernetes/nginx-lb/ /etc/kubernetes/manifests/
$ mv /etc/kubernetes/manifests/nginx-lb/nginx-lb.yaml /etc/kubernetes/manifests/

# verify all files in /etc/kubernetes/manifests/ directory
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
# Very important, please be sure to wait for the pods of nginx-lb-k8s-masterX and keepalived-k8s-masterX to be in the Running state
#######################
$ kubectl get pods -n kube-system
NAME                                   READY   STATUS    RESTARTS   AGE
keepalived-k8s-master01                1/1     Running   0          13s
keepalived-k8s-master02                1/1     Running   0          11s
keepalived-k8s-master03                1/1     Running   0          8s
nginx-lb-k8s-master01                  1/1     Running   0          13s
nginx-lb-k8s-master02                  1/1     Running   0          11s
nginx-lb-k8s-master03                  1/1     Running   0          8s

# execute on all master nodes: check that the keepalived and nginx-lb pods of the master node have been automatically created, and then perform the following operations
$ systemctl stop kubelet
$ docker rm -f keepalived nginx-lb
$ systemctl restart kubelet

# wait and check the status of pods. Pods of keepalived and nginx-lb are added
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

# verify nginx-lb and keepalived works
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

# execute on all master nodes: edit /etc/kubernetes/admin.conf
$ sed -i 's/:16443/:6443/g' /etc/kubernetes/admin.conf

# execute on all worker nodes: join worker nodes to kubernetes cluster
$ kubeadm join xxxx --token xxxx \
    --discovery-token-ca-cert-hash xxxx
```

### install metrics-server component

```bash
# install metrics-server components
$ cd kubeadm-ha
$ kubectl apply -f addons/metrics-server.yaml

# after waiting for a minute or so, check the performance indicators of the pods
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

### install kubernetes-dashboard component

```bash
# install kubernetes-dashboard component
$ cd kubeadm-ha
$ cd addons

# create kubernetes-dashboard certificates
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/CN=dashboard"
$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout dashboard.key -out dashboard.csr -subj "/CN=dashboard"

# Pay attention to setting the ip address and hostname of vip
$ export VIPADDR=172.20.10.10
$ export VIPHOST=k8s-vip
$ echo "subjectAltName = DNS: dashboard, DNS: ${VIPHOST}, IP: ${VIPADDR}" > extfile.cnf
$ openssl x509 -req -days 3650 -in dashboard.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out dashboard.crt

# create kubernetes-dashboard certificates secret
$ kubectl create namespace kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
$ kubectl create secret generic kubernetes-dashboard-certs --from-file=dashboard.key --from-file=dashboard.crt -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -

# install kubernetes-dashboard
$ kubectl apply -f kubernetes-dashboard.yaml

# verify kubernetes-dashboard status
$ kubectl -n kubernetes-dashboard get pods,services
NAME                                             READY   STATUS    RESTARTS   AGE
pod/dashboard-metrics-scraper-79c5968bdc-xxf45   1/1     Running   0          22s
pod/kubernetes-dashboard-7cb9fd9999-lqgw9        1/1     Running   0          22s

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
service/dashboard-metrics-scraper   ClusterIP   10.109.137.59    <none>        8000/TCP        22s
service/kubernetes-dashboard        NodePort    10.108.252.248   <none>        443:30000/TCP   23s

# get the admin-user serviceaccount token, which is used to log in to kubernetes-dashboard
$ kubectl -n kube-system get secrets $(kubectl -n kube-system get serviceaccounts admin-user -o=jsonpath='{.secrets[0].name}') -o=jsonpath='{.data.token}' | base64 -d
```

- use token to log in to kubernetes-dashboard

kubernetes-dashboard URL: https://k8s-vip:30000

- open the browser and log in to kubernetes-dashboard with token

![](images/kubernetes-dashboard-login.png)

- open the browser to view kubernetes-dashboard

![](images/kubernetes-dashboard-pods.png)

### check kubernetes cluster status

```bash
# verify all pods state
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

# verify all nodes state
$ kubectl get nodes -o wide
NAME           STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION               CONTAINER-RUNTIME
k8s-master01   Ready    control-plane,master   23m   v1.20.2   172.20.10.4   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
k8s-master02   Ready    control-plane,master   20m   v1.20.2   172.20.10.5   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
k8s-master03   Ready    control-plane,master   18m   v1.20.2   172.20.10.6   <none>        CentOS Linux 7 (Core)   5.11.0-1.el7.elrepo.x86_64   docker://20.10.3
```
