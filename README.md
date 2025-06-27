## 简介
本 compose 用于独立部署 Prometheus, Alertmanager, Grafana 等监控组件，可同时监控 Rancher 集群资源以及其他集群外资源。
 - 对于Rancher集群采用 remote_write 远程写的方案将数据推送到本机
 - 对于集群外资源和传统监控采集方案一致，直接将被监控资源 target 添加到prometheus.yml文件中

说明：当前 Rancher monitoring 版本为 106.1.1+up69.8.2-rancher.5，为避免 Grafana 图表兼容性问题，Grafana 所使用的版本和 monitoring 106.1.1+up69.8.2-rancher.5 中的版本保持一致

**为什么要独立部署 Prometheus？**

因为分组告警的需要，分组告警的几种方案：
1. 使用 monitoring 中的 Routes and Receivers，该方案不能分组，弃用；
2. 使用 monitoring 中的 AlertmanagerConfigs，该方案分组告警可以工作，但只限于集群内资源，集群外资源无法识别，弃用；
3. 独立部署外部 Prometheus，集群外资源独立采集，集群外 Prometheus 采用 remote_read 远程读取集群内数据，分组告警可正常工作，但会出现有时无法采集到数据情况，有一些兼容性问题，弃用；
4. 独立部署外部 Prometheus，集群外资源独立采集，外部 Prometheus 通过联邦模式抓取集群内 Prometheus 的所有 job，存在抓取的集群内job数据都放到了一个 job 中，部分图表指标有使用固定的job名称导致出现问题
5. 本方案，独立部署外部 Prometheus，集群外资源独立采集，集群内资源采用 remote_write 远程写的方式将数据推送到外部 Prometheus，外部拥有所有数据，分组告警可正常工作。

## 部署步骤
### 1、暴露k8s内部Prometheus
执行 k8s-service-nodeport-prometheus.yaml 创建nodeport，监听端口为 30909，目的是为了外部独立主机可监控k8s集群内部Prometheus.
```bash
kubectl apply -f k8s-service-nodeport-prometheus.yaml
```

### 2、导出k8s内部规则
```bash
# 将rules configmap导出到configmap.yaml
kubectl get configmap -n cattle-monitoring-system prometheus-rancher-monitoring-prometheus-rulefiles-0 -o yaml > configmap.yaml

# 读取configmap.yaml解析到rules目录
python3 export-k8s-rules.py
```

### 3、创建所需目录并授权
```bash
rm -rf /data/monitoring/{prometheus-data,grafana-data}
mkdir -p /data/monitoring/{prometheus-data,grafana-data}
chmod 777 /data/monitoring/{prometheus-data,grafana-data}
```

### 4、启动本地服务
修改 prometheus.yml 文件中的 PROMETHEUS-HOST-IP 以及 K8S-NODE-IP 为对应的IP.

启动服务：
```bash
docker-compose up -d prometheus alertmanager grafana blackbox_exporter prometheus_alert
```
tg_bot 和 dingtalk_bot 先不启动，后面按需启动。

### 5、删除k8s内部规则

删除k8s集群内部Prometheus规则，如果k8s集群里的Prometheus规则和集群外独立的Prometheus规则同时进行评估，由于规则里有record规则，两端同时评估会存在问题，会出现 out of order sample 问题。

### 6、K8S指定远程写的地址

找到 additionalRemoteWrite 部分，添加 url 指定远程Prometheus的地址，并且设置远程写的时候删除 prometheus 和 prometheus_replica 这两个标签，不然会导致图表出错。
```yaml
    additionalRemoteWrite:
      - url: http://PROMETHEUS-HOST-IP:9090/api/v1/write
        writeRelabelConfigs:
        - action: labeldrop
          regex: prometheus|prometheus_replica
```
### 6、本地Grafana操作
#### 1）添加数据源
进入本地 Grafana 后台添加2个 Prometheus 数据源，一个首字母大写 Prometheus，一个首字母小写 prometheus，因为导出的 dashboard 有几个读的是小写的 prometheus 数据源，为了不修改原始 dashboard，直接添加2个数据源即可。

Connections -> Data sources -> Add data source

#### 2）导出k8s默认图表
暴露k8s内部Grafana:

```bash
kubectl apply -f k8s-service-nodeport-grafana.yaml
```
获取 Token：进入Grafana后台->Administration->Users and access->Service accounts->Add service account

修改 grafana_dashboards_export.sh 中的 HOST 和 TOKEN，然后执行脚本导出：
```bash
bash grafana_dashboards_export.sh
```

#### 3) 导入图表到本地Grafana
获取Token：进入Grafana后台->Administration->Users and access->Service accounts->Add service account

修改 grafana_dashboards_import.sh 中的 HOST 和 TOKEN，然后执行脚本导入：
```bash
bash grafana_dashboards_import.sh
```

#### 4）导入其他图表
常用的如下：
- 16098: Node Exporter Dashboard
- 17320: Mysqld Exporter Dashboard
- 763/17507: Redis Dashboard
- 9965: Blackbox Exporter Dashboard
- 9734: Doris Overview
- 13105: K8S Dashboard
- 2279: NATS Server Dashboard
- 21473: Etcd Cluster Overview
- 19004: Spring Boot 3.x Statistics
- rocketmq_exporter.json (https://github.com/apache/rocketmq-exporter)

## 其他Telegram相关
1. 获取chat_id:

   在机器人所在的群里随意发送一段带斜杠的字符，如: /abc ，然后请求下面API获取：
   https://api.telegram.org/bot{YOUR_TOKEN}/getUpdates
    ```bash
   # curl https://api.telegram.org/bot7785791616:AAFEP2qdelv-NoWau4SAqjbWJRfthENV0ER/getUpdates
    ```
   结果中 result.message.chat.id 则为chat_id

2. 当日志中出现如下日志时:
    ```text
    component=telegram msg="failed to get chat list from store" err="Key not found in store"
    ```
    管理员可在群里敲 /status 查看状态情况，确认状态都ok然后敲 /start 启用。


## Prometheus 添加认证方法
官方文档: https://prometheus.io/docs/guides/basic-auth/

密码加密: https://bcrypt-generator.com/

如需给Prometheus添加认证可在promethues挂载web.yml文件 `./web.yml:/etc/prometheus/web.yml`，并在启动时添加 `--web.config.file=/etc/prometheus/web.yml`

web.yml文件内容如下:
admin/123456
```yaml
basic_auth_users:
  admin: $2a$12$CUHXssXKAH/m/ilSJc14sOfZY9adte46p2vbmjHdZ1yo19Of6wahO
```
密码为加密后的密码，加密密码可以通过 https://bcrypt-generator.com/ 生成：


## 动态加载
```bash
# Prometheus
curl -X POST 'http://127.0.0.1:9090/-/reload'

# Alertmanager
curl -X POST 'http://127.0.0.1:9093/-/reload'
```


