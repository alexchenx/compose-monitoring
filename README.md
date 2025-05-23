## 简介
本compose用于独立部署Prometheus, Alertmanager, Grafana等监控组件，可同时监控Rancher集群资源以及其他集群外资源。
 - 对于Rancher集群采用 remote_write 远程写的方案将数据推送到本机
 - 对于集群外资源和传统监控采集方案一致，直接将被监控资源 target 添加到prometheus.yml文件中

说明：当前Rancher monitoring版本为 105.1.4+up61.3.2-rancher.5，为避免Grafana图表兼容性问题，Grafana所使用的版本和monitoring 105.1.4+up61.3.2-rancher.5中的版本保持一致

分组告警的几种方案：
1. 使用monitoring中的Routes and Receivers，该方案不能分组，弃用；
2. 使用monitoring中的AlertmanagerConfigs，该方案分组告警可以工作，但只限于集群内资源，集群外资源无法识别，弃用；
3. 独立部署外部Prometheus，集群外资源独立采集，集群外Prometheus采用remote_read远程读取集群内数据，分组告警可正常工作，但会出现有时无法采集到数据情况，有一些兼容性问题，弃用；
4. 独立部署外部Prometheus，集群外资源独立采集，外部Prometheus通过联邦模式抓取集群内Prometheus的所有job，存在抓取的集群内job数据都放到了一个job中，部分图表指标有使用固定的job名称导致出现问题
5. 本方案，独立部署外部Prometheus，集群外资源独立采集，集群内资源采用remote_write远程写的方式将数据推送到外部Prometheus，外部拥有所有数据，分组告警可正常工作。

## 部署步骤
### 将k8s内部Prometheus暴露
执行 k8s/k8s-service-nodeport-prometheus.yaml 创建nodeport，监听端口为 30909，目的是为了外部独立主机可监控k8s集群内部Prometheus.

### 创建所需目录并授权
```bash
rm -rf /data/monitoring/{prometheus-data,grafana-data}
mkdir -p /data/monitoring/{prometheus-data,grafana-data}
chmod 777 /data/monitoring/{prometheus-data,grafana-data}
```

### 编辑 prometheus.yml 
修改 prometheus.yml 文件中的 PROMETHEUS-HOST-IP 以及 K8S-NODE-IP 为对应的IP.

### 启动服务
```bash
docker-compose up -d prometheus alertmanager grafana tg_bot dingtalk_bot blackbox_exporter
```
启动后检查服务是否正常。

### K8S指定远程写的地址
找到 additionalRemoteWrite 部分,添加 url 指定远程Prometheus的地址，并且设置远程写的时候删除prometheus和prometheus_replica这两个标签，不然会导致图表出错。
```yaml
    additionalRemoteWrite:
      - url: http://192.168.200.139:9090/api/v1/write
        writeRelabelConfigs:
        - action: labeldrop
          regex: prometheus|prometheus_replica
```
找到 grafana.ini 部分，在 security 下 添加 angular_support_enabled: true ，原因是Grafana11已经弃用Angular，但是Rancher monitoring的图表依然依赖Angular，通过此配置重新启用，如果不需要访问集群内部的Grafana也可以不用配置此项。
```yaml
    security:
      allow_embedding: true
      angular_support_enabled: true  # 添加此记录
```

### 添加数据源
进入Grafana后台添加2个Prometheus数据源，一个首字母大写Prometheus，一个首字符小写prometheus，因为导出的dashboard有几个读的是小写的prometheus数据源，为了不修改原始dashboard，直接添加2个数据源即可。

### 导入k8s默认dashboards
进入Grafana后台获取token: Administration->Users and access->Service accounts->Add service account

执行 k8s/grafana_dashboards_import.sh 脚本。

### 导入 Grafana dashboard，常用的如下
- 16098: Node Exporter Dashboard
- 17320: Mysqld Exporter Dashboard
- 763/17507: Redis Dashboard
- rocketmq_exporter.json (https://github.com/apache/rocketmq-exporter)
- 9965: Blackbox Exporter Dashboard
- 9734: Doris Overview
- 13105: K8S Dashboard
- 2279: NATS Server Dashboard
- 21473: Etcd Cluster Overview



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


