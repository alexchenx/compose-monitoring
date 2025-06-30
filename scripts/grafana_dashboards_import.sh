#!/bin/bash
# Description: This script is use for import all grafana dashboards

HOST="http://127.0.0.1:3000"
TOKEN=""

dashboard_path="k8s-default-dashboards"
cd $dashboard_path || exit 1
sed -i '0,/"id": .*/{s/"id": .*/"id": null,/}' ./*.json
for file in *.json
do
    echo "Importing ${file} ..."
    if ! echo "{\"dashboard\": $(cat "${file}"), \"folderId\": 0, \"overwrite\": true}" | curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @- "${HOST}/api/dashboards/db"; then
        exit 1
    fi
    printf "\n\n"
done
