#!/bin/bash
# Description: This script is use for export all grafana dashboards

HOST="http://K8S-NODE-IP:31337"
TOKEN="glsa_oYUxKXlB6Qu9PMw9ZOLFt7K7YOeCyFjD_3d12e6ff"

dir_name="k8s-default-dashboards"
rm -rf $dir_name && mkdir -p $dir_name

if ! command -v jq > /dev/null; then
	apt install jq
fi

for uid in $(curl -sSL -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/search/" | jq -r .[].uid); do
    url=$(curl -sSL -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/dashboards/uid/${uid}"  | jq -r .meta.url)
    filename=$(echo "${url}"|sed 's/.*\///')
    curl -sSL -k -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/dashboards/uid/${uid}"  | jq -r .dashboard > ${dir_name}/"${filename}".json
done
