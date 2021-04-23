# ProfileScript
> 本仓库现下为学习内容为主，多数会以shell脚本形式展示。因为一直使用Apple家的产品，所以也会兼顾提供一下Apple部分软件上的使用心得、教程类的文章。

## Learning

学习部分的内容会整合从2017年开始工作后，所经历过的一些项目的经验整合，以期间在学习上的相关内容分享。

**项目学习历程**

初始阶段，首先接触到了集群及各种devops工具，git、禅道、数据库、maven、docker等。根据整体使用情况，一步一步展示所有应用的使用方式。

Docker

Harbor

Kubernetes

GitLab



### Harbor

harbor作为docker容器的一种存储工具，充分做到了分组、管理、权限的合集。在一众新版本中，也支持了Helm chart管理。为了适应简单的使用，当然其部署方式也相对简单，基本实现了一键部署。但同时在不同场景中，也需要不同的配置。这里展示在内网环境下部署。官网部署参考链接：https://goharbor.io/docs/2.0.0/install-config/

**环境和软件准备**

> 这里介绍离线部署harbor 1.9.4版本

**环境需求**

- 操作系统：Centos7+，Ubuntu16+，Debain9+
- Docker-Compose



**部署环境准备**

下载离线安装包

```
wget <https://github.com/goharbor/harbor/releases/download/v1.9.4/harbor-offline-installer-v1.9.4.tgz>
```

安装docker-compose

```
curl -L "<https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$>(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```



**安装harbor**

解压安装包

```
tar -zxvf harbor-offline-installer-v1.9.4.tgz
```

修改配置文件harbor.yml，如下内容

```
hostname: 10.0.16.72     # harbor访问域名或ip
http:
  port: 30000            # http端口
data_volume: /app/harbor # 数据存放目录
```

安装命令

```
# sudo ./install.sh
```



**Harbor配置**

Harbor的默认安装使用HTTP，需要将选项`--insecure-registry`到客户端的Docker守护程序，然后重新启动Docker服务。

docker配置文件(/etc/docker/daemon.json)，增加如下内容；值为数组，用`,`分隔

```
"insecure-registries": ["10.0.16.72:30000"]
```

使用docker login登录

```
docker login 10.0.16.72:30000
```





**FAQ**

Q: 内网环境下部署的服务通过ingress无法在外网环境使用docker login

A: 在harbor.yml文件中修改此配置，然后重新生成配置文件

```jsx
external_url: https://域名/
```

Q: 在外网环境下使用docker push 报错unknown blob

A: 在registry的配置文件（config.yml）增加配置

```jsx
http:
	relativeurls: true
```

参考链接：[https://github.com/docker/distribution/issues/970](https://github.com/docker/distribution/issues/970)

Q: 在内网环境下使用harbor

A: 在hosts文件中配置 服务器ip映射到域名

例：10.218.129.50 域名

这样，外网可以直接使用域名上传镜像，内网可以使用ip下载镜像





### Kubernetes

自从kuberntes升级到1.20之后，其运行方式发生了些变化，为了能够完善的处理多重方式的集群管理，整理完成两种版本的部署方式，且每种方式都提供两种场景。





**学习之路**



### Sharing

将Apple产品使用上的相关内容集中展示（虽然也有很多人都做过了）