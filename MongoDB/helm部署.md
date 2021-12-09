## MongoDB副本集

为了解决外网冲突问题，可以分成两部分的部署模式。以下方式部署的结果没有访问密码

1、启动，但没有外网访问模式

```yaml
helm install mongodb \\
--set architecture=replicaset \\
--set global.storageClass=nfs-provisioner \\
--set global.namespaceOverride=storage \\
--set auth.enabled=false \\
--set replicaSetName=demo \\
--set fullnameOverride=mongodb \\
bitnami/mongodb
```

2、更新，增加外网访问模式。由于某些原因不能一步到位，所以采用更新的操作实现

```yaml
helm upgrade --install mongodb \\
--set architecture=replicaset \\
--set global.storageClass=nfs-provisioner \\
--set global.namespaceOverride=storage \\
--set auth.enabled=false \\
--set replicaSetName=demo \\
--set fullnameOverride=mongodb \\
--set replicaCount=2 \\
--set externalAccess.enabled=true \\
--set externalAccess.service.type=NodePort \\
--set externalAccess.service.nodePorts[0]='30090' \\
--set externalAccess.service.nodePorts[1]='30091' \\
bitnami/mongodb
```

3、设置访问密码和数据。需以command形式登录到mongodb中

```yaml
# 切换到hops_cmdb数据库
use hops_cmdb
# 创建hops_cmdb数据库读写角色
db.createUser({user: "hops", pwd: "hops", roles: [{ role: "readWrite", db:"hops_cmdb" }]})
```