#!/bin/bash
set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-"coco-rg"}
CLUSTER_NAME=${CLUSTER_NAME:-"coco-kserve"}

echo "################################################"
echo "Tearing down ARO cluster"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Cluster name:   $CLUSTER_NAME"
echo "################################################"

read -p "Are you sure you want to delete the cluster? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Deleting ARO cluster..."
az aro delete --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --yes

echo "Deleting resource group..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo ""
echo "################################################"
echo "Teardown initiated."
echo "Resource group deletion is running in the background."
echo "################################################"
