# Description: 此脚本用于将k8s集群内的Prometheus rules导出到本地rules目录中
# 使用方式：
# 首先将所有规则导出: kubectl get configmap -n cattle-monitoring-system prometheus-rancher-monitoring-prometheus-rulefiles-0 -o yaml > configmap.yaml
# 然后执行此脚本: python3 configmap_export.py

import yaml
import os

# 读取 ConfigMap 文件
configmap_file = 'configmap.yaml'

# 确保 ConfigMap 文件存在
if not os.path.exists(configmap_file):
    print(f"文件 {configmap_file} 不存在！")
    exit(1)

# 读取 YAML 配置文件
with open(configmap_file, 'r') as file:
    configmap = yaml.safe_load(file)

# 提取 ConfigMap 中的 data 部分
data = configmap.get('data', {})

# 导出每个 key 到独立的文件
os.mkdir("../rules")
for key, value in data.items():
    names = key.split("-")
    name = f"../rules/{'-'.join(names[3:-5])}.yaml"
    with open(name, 'w') as output_file:
        output_file.write(value)

    print(f"已将 {name} 的内容导出到文件 {name}")