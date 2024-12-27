#!/bin/bash
# Description: This script is use for export all grafana dashboards

HOST="http://172.31.103.245:31899"
KEY="eyJrIjoialVQeGlrelNnRGlyeXJZT280TkN5b2NOUGV6UkVEVVciLCJuIjoiYWRtaW4iLCJpZCI6MX0="

dir_name="dashboards"
rm -rf $dir_name && mkdir -p $dir_name

for uid in $(curl -sSL -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/search/" | jq -r .[].uid); do
    url=$(curl -sSL -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/uid/${uid}"  | jq -r .meta.url)
    filename=$(echo "${url}"|sed 's/.*\///')
    curl -sSL -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/uid/${uid}"  | jq -r .dashboard > ${dir_name}/"${filename}".json
done
