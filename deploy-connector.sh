#!/bin/bash
trap 'echo interrupted; exit' INT
set -e


echo "Submitting the connector's configuration..."

export AZURE_STORAGE_ACCOUNT=$(terraform -chdir=terraform output -raw storage_account_name)
export AZURE_STORAGE_ACCOUNT_KEY=$(terraform -chdir=terraform output -raw storage_account_access_key)
export AZURE_STORAGE_CONTAINER=$(terraform -chdir=terraform output -raw storage_account_container_name)

submitResponseFileName=$(mktemp)
submitCode=$(envsubst '$AZURE_STORAGE_ACCOUNT,$AZURE_STORAGE_ACCOUNT_KEY,$AZURE_STORAGE_CONTAINER' \
    < connectors/azure-source-cc-expedia.json \
    | curl http://localhost:8083/connectors -H "Content-Type: application/json" -d@- -o $submitResponseFileName -w "%{http_code}")

if [ "$submitCode" == 201 ]; then
    echo "Connector configuration submitted."
else
    echo "Connector submission failed"
    echo "Response code: $submitCode"
    echo "Response body:"
    cat $submitResponseFileName
fi
