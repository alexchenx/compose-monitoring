FROM ubuntu:22.04
RUN sed -i 's|http://.*ubuntu.com|http://mirrors.aliyun.com|g' /etc/apt/sources.list
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN curl -sSL -k https://github.com/timonwong/prometheus-webhook-dingtalk/releases/download/v2.1.0/prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz | tar zx -C /usr/local/
WORKDIR /usr/local/prometheus-webhook-dingtalk-2.1.0.linux-amd64/