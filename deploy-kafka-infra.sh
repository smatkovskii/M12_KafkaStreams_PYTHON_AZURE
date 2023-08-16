#!/bin/bash
trap 'echo interrupted; exit' INT
set -e


echo "Preparing to deploy resources to the cluster..."

kubeConfigFileName=kubeconfig
terraform -chdir=terraform output -raw kube_config > $kubeConfigFileName
export KUBECONFIG=$kubeConfigFileName

kubectl create namespace confluent || true
kubectl config set-context --current --namespace confluent

helm repo add confluentinc https://packages.confluent.io/helm
helm repo update

helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes

echo "Building Docker image for the source connector..."
registryName=$(terraform -chdir=terraform output -raw acr_name)
registryUrl=$(terraform -chdir=terraform output -raw acr_url)
export CONNECTOR_IMAGE=$registryUrl/azure-source-expedia-connector:1.0.0
docker build -t $CONNECTOR_IMAGE -f connectors/Dockerfile .

echo "Pushing Docker image '$CONNECTOR_IMAGE' to the remote registry..."
az acr login -n $registryName
docker push $CONNECTOR_IMAGE

echo "Deploying..."

envsubst < kafka-infrastructure.yaml | kubectl apply -f -

echo "Deployment initiated."
