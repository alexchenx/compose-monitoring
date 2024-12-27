## 简介
本compose用于独立部署Prometheus, Alertmanager, Grafana等监控组件，可同时监控Rancher集群资源以及其他集群外资源。
 - 对于Rancher集群采用 remote_write 远程写的方案将数据推送到本机
 - 对于集群外资源和传统监控采集方案一致，直接将被监控资源 target 添加到prometheus.yml文件中

说明：当前Rancher monitoring版本为 102.0.5+up40.1.2，为避免Grafana图表兼容性问题，Grafana所使用的版本和monitoring 102.0.5+up40.1.2中的版本保持一致

分组告警的几种方案：
1. 使用monitoring中的Routes and Receivers，该方案不能分组，弃用；
2. 使用monitoring中的AlertmanagerConfigs，该方案分组告警可以工作，但只限于集群内资源，集群外资源无法识别，弃用；
3. 独立部署外部Prometheus，集群外资源独立采集，集群外Prometheus采用remote_read远程读取集群内数据，分组告警可正常工作，但会出现有时无法采集到数据情况，有一些兼容性问题，弃用；
4. 独立部署外部Prometheus，集群外资源独立采集，外部Prometheus通过联邦模式抓取集群内Prometheus的所有job，存在抓取的集群内job数据都放到了一个job中，部分图表指标有使用固定的job名称导致出现问题
5. 本方案，独立部署外部Prometheus，集群外资源独立采集，集群内资源采用remote_write远程写的方式将数据推送到外部Prometheus，外部拥有所有数据，分组告警可正常工作。

## 部署步骤
### 创建所需目录并授权
```bash
rm -rf /data/monitoring/{prometheus-data,grafana-data}

mkdir -p /data/monitoring/{prometheus-data,grafana-data}
chmod 777 /data/monitoring/{prometheus-data,grafana-data}
```

### 启动服务
```bash
docker-compose up -d prometheus alertmanager grafana tg_bot dingtalk_bot blackbox_exporter
```
启动后检查服务是否正常。

### K8S指定远程写的地址
找到 additionalRemoteWrite ,添加 url 指定远程Prometheus的地址
```yaml
    additionalRemoteWrite:
      - url: http://10.10.1.5:9090/api/v1/write
```

### 将k8s内部Prometheus暴露
执行 k8s/k8s-service-nodeport-prometheus.yaml 创建nodeport，监听端口为 30909

### 导入k8s默认dashboards
执行 k8s/grafana_dashboards_import.sh 脚本。

然后编辑此脚本将dashboard_path改为custom-dashboards，再次执行导入与该Grafana版本兼容的自定义图表。

### 导入 Grafana dashboard，常用的如下
- 16098: Node Exporter: 16098_rev2.json
- 17320: Mysqld Exporter
- 763/17507: Redis Exporter
- 9965: Blackbox Exporter
- 9734: Doris Overview
- 13105: k8s dashboard
- jvm: NG V1-1734074192714.json, 修改"uid": "prometheus"为"uid": "Prometheus"
- jvm: NG V2-1734074212622.json, 修改"uid": "prometheus"为"uid": "Prometheus"
- 2279: NATS Server Dashboard



## 其他Telegram相关
1. 获取会话ID:
    ```bash
    # curl https://api.telegram.org/bot5546157333:AAHz9TEbbkoTMSFJYjE_ndGuI6OED0CtAAA/getMe
    {"ok":true,"result":{"id":5546157333,"is_bot":true,"first_name":"monitor_robot","username":"monitor_bthy_bot","can_join_groups":true,"can_read_all_group_messages":false,"supports_inline_queries":false,"can_connect_to_business":false}}
    ```

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


