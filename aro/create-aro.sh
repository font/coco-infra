#!/bin/bash
set -e

# Configuration
RESOURCE_GROUP=${RESOURCE_GROUP:-"coco-rg"}
CLUSTER_NAME=${CLUSTER_NAME:-"coco-kserve"}
CLUSTER_RESOURCE_GROUP=${CLUSTER_RESOURCE_GROUP:-"${RESOURCE_GROUP}-managed"}
LOCATION=${LOCATION:-"eastus2"}
VNET_NAME=${VNET_NAME:-"${CLUSTER_NAME}-vnet"}
WORKER_VM_SIZE=${WORKER_VM_SIZE:-"Standard_D8s_v5"}
WORKER_COUNT=${WORKER_COUNT:-3}
ARO_VERSION=${ARO_VERSION:-"4.19.20"}
SP_CREDENTIALS=${SP_CREDENTIALS:-"$HOME/.azure/osServicePrincipal.json"}
PULL_SECRET=${PULL_SECRET:-"$HOME/pull-secret.json"}

# Validate prerequisites
if [[ ! -f "$SP_CREDENTIALS" ]]; then
  echo "ERROR: Service principal credentials not found: $SP_CREDENTIALS" >&2
  exit 1
fi

if [[ ! -f "$PULL_SECRET" ]]; then
  echo "ERROR: Pull secret not found: $PULL_SECRET" >&2
  exit 1
fi

SP_CLIENT_ID=$(python3 -c "import json; d=json.load(open('$SP_CREDENTIALS')); print(d['clientId'])")
SP_CLIENT_SECRET=$(python3 -c "import json; d=json.load(open('$SP_CREDENTIALS')); print(d['clientSecret'])")

echo "################################################"
echo "Creating ARO cluster"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Cluster name:   $CLUSTER_NAME"
echo "  Location:       $LOCATION"
echo "  Version:        $ARO_VERSION"
echo "  Worker VM size: $WORKER_VM_SIZE"
echo "  Worker count:   $WORKER_COUNT"
echo "  Managed RG:     $CLUSTER_RESOURCE_GROUP"
echo "################################################"

# Register provider if needed
REG_STATE=$(az provider show -n Microsoft.RedHatOpenShift --query registrationState -o tsv 2>/dev/null)
if [[ "$REG_STATE" != "Registered" ]]; then
  echo "Registering Microsoft.RedHatOpenShift provider..."
  az provider register -n Microsoft.RedHatOpenShift --wait
fi

# Create resource group
echo "Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

# Create VNet
echo "Creating VNet and subnets..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefixes 10.0.0.0/22 \
  -o none

az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name master-subnet \
  --address-prefixes 10.0.0.0/23 \
  -o none

az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name worker-subnet \
  --address-prefixes 10.0.2.0/23 \
  -o none

# Create ARO cluster
echo "Creating ARO cluster (this takes ~35 minutes)..."
az aro create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --vnet "$VNET_NAME" \
  --master-subnet master-subnet \
  --worker-subnet worker-subnet \
  --version "$ARO_VERSION" \
  --worker-vm-size "$WORKER_VM_SIZE" \
  --worker-count "$WORKER_COUNT" \
  --cluster-resource-group "$CLUSTER_RESOURCE_GROUP" \
  --client-id "$SP_CLIENT_ID" \
  --client-secret "$SP_CLIENT_SECRET" \
  --pull-secret @"$PULL_SECRET" \
  -o json

# Log in to the cluster
echo "Logging in to cluster..."
API_URL=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query apiserverProfile.url -o tsv)
KUBEADMIN_PW=$(az aro list-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query kubeadminPassword -o tsv)
oc login "$API_URL" -u kubeadmin -p "$KUBEADMIN_PW" --insecure-skip-tls-verify

CONSOLE_URL=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query consoleProfile.url -o tsv)

echo ""
echo "################################################"
echo "ARO cluster created successfully!"
echo "  API:     $API_URL"
echo "  Console: $CONSOLE_URL"
echo "################################################"
