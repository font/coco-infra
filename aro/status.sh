#!/bin/bash

echo "################################################"
echo "CoCo on ARO - Status"
echo "################################################"

RESOURCE_GROUP=${RESOURCE_GROUP:-"${USER}-coco-rg"}
CLUSTER_NAME=${CLUSTER_NAME:-"${USER}-coco"}

# Check Azure cluster
echo ""
echo "=== ARO Cluster ==="
PROVISIONING_STATE=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query provisioningState -o tsv 2>/dev/null)
if [[ -z "$PROVISIONING_STATE" ]]; then
  echo "Cluster not found in resource group $RESOURCE_GROUP"
  exit 1
fi
API_URL=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query apiserverProfile.url -o tsv 2>/dev/null)
CONSOLE_URL=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query consoleProfile.url -o tsv 2>/dev/null)
VERSION=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query clusterProfile.version -o tsv 2>/dev/null)
echo "  State:   $PROVISIONING_STATE"
echo "  Version: $VERSION"
echo "  API:     $API_URL"
echo "  Console: $CONSOLE_URL"

# Check OpenShift login
echo ""
echo "=== OpenShift Login ==="
if ! oc whoami &>/dev/null; then
  echo "  Not logged in"
  exit 0
fi
echo "  User: $(oc whoami)"

# Nodes
echo ""
echo "=== Nodes ==="
oc get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion

# Trustee
echo ""
echo "=== Trustee ==="
TRUSTEE_READY=$(oc get deployment trustee-deployment -n trustee-operator-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$TRUSTEE_READY" ]]; then
  echo "  Trustee: $TRUSTEE_READY replica(s) ready"
else
  echo "  Trustee: not installed"
fi

CERTMGR_READY=$(oc get deployment cert-manager-operator-controller-manager -n cert-manager-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$CERTMGR_READY" ]]; then
  echo "  cert-manager: $CERTMGR_READY replica(s) ready"
else
  echo "  cert-manager: not installed"
fi

# OSC
echo ""
echo "=== OSC ==="
OSC_READY=$(oc get deployment controller-manager -n openshift-sandboxed-containers-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$OSC_READY" ]]; then
  echo "  OSC operator: $OSC_READY replica(s) ready"
else
  echo "  OSC operator: not installed"
fi

# Runtime classes
echo ""
echo "=== Runtime Classes ==="
for rc in kata kata-remote; do
  if oc get runtimeclass "$rc" &>/dev/null; then
    echo "  $rc: available"
  else
    echo "  $rc: not found"
  fi
done

# KServe
echo ""
echo "=== KServe ==="
KSERVE_READY=$(oc get deployment kserve-controller-manager -n kserve --no-headers 2>/dev/null)
if [[ -n "$KSERVE_READY" ]]; then
  echo "  $KSERVE_READY"
else
  echo "  not installed"
fi

echo ""
echo "################################################"
