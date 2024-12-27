FROM ubuntu:22.04
RUN apt update && apt install -y wget && apt-get clean && \
    wget https://github.com/timonwong/prometheus-webhook-dingtalk/releases/download/v2.1.0/prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz && \
    tar -zxvf prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz -C /usr/local/ && \
    rm -rf prometheus-webhook-dingtalk-2.1.0.linux-amd64.tar.gz
WORKDIR /usr/local/prometheus-webhook-dingtalk-2.1.0.linux-amd64/