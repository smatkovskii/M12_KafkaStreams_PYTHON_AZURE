#!/bin/bash
trap 'echo interrupted; exit' INT
set -e


echo "Building Docker image for Kafka Streams app..."
registryName=$(terraform -chdir=terraform output -raw acr_name)
registryUrl=$(terraform -chdir=terraform output -raw acr_url)
export KSTREAM_APP_IMAGE=$registryUrl/hotel-stays-processor:1.0.0
docker build -t $KSTREAM_APP_IMAGE -f src/Dockerfile .

echo "Pushing Docker image '$KSTREAM_APP_IMAGE' to the remote registry..."
az acr login -n $registryName
docker push $KSTREAM_APP_IMAGE

echo "Deploying..."

export KUBECONFIG=kubeconfig

envsubst '$KSTREAM_APP_IMAGE' < kstream-app.yaml | kubectl apply -f -

echo "Deployment initiated."
