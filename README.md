> 本仓库现下为学习内容为主，多数会以shell脚本形式展示。因为一直使用Apple家的产品，所以也会兼顾提供一下Apple部分软件上的使用心得、教程类的文章。

## Learning Road

学习部分的内容会整合从2017年开始工作后，所经历过的一些项目的经验整合，以期间在学习上的相关内容分享。

**项目学习历程**

初始阶段，首先接触到了集群及各种devops工具，git、禅道、数据库、maven、docker等。根据整体使用情况，一步一步展示所有应用的使用方式。

### Middleware/Harbor

harbor作为docker容器的一种存储工具，充分做到了分组、管理、权限的合集。在一众新版本中，也支持了Helm chart管理。为了适应简单的使用，当然其部署方式也相对简单，基本实现了一键部署。但同时在不同场景中，也需要不同的配置。这里展示在内网环境下部署。

官网部署参考链接：https://goharbor.io/docs/2.0.0/install-config/

简易安装整理：[harobr install](/Harbor/install.md)

### Middleware/MySql

mysql服务的部署以最主流的版本5.7.*为依据，从三个层面介绍其单机部署方式。

- [RPM部署](/Mysql/RPM部署.md)

- [编译包部署](/Mysql/编译包部署.md)

- [源码编译部署](/Mysql/源码编译部署.md)

三种部署方式中，建议采用rpm部署或编译包部署。

### Middleware/MongoDB

mongodb是一种非关系型数据库，为满足实际生产模式中的使用，最好选择部署副本集模式。以下提供helm部署和二进制部署两种模式。

[helm部署](MongoDB/helm部署.md)

[二进制部署](MongoDB/二进制部署.md)

### Basic/Kubernetes

在实际使用或部署k8s的过程中，总会遇到很多场景上的差异。在实际项目应用和开发过程中，可以主要考虑两种方式的k8s部署方法：

- ansible引用kubeadm一键部署集群[Thanks To TimeBye](https://github.com/TimeBye/kubeadm-ha.git)
- kubeadm分步部署集群[Thanks To cookeem](https://github.com/cookeem/kubeadm-ha.git)

将Apple产品使用上的相关内容集中展示（虽然也有很多人都做过了）

### App/QuantumultX

准备做一些破解规则

### App/Surge