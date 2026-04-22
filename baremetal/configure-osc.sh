#!/bin/bash
set -e

# Configure OSC for bare metal confidential containers.
# Creates osc-feature-gates, KataConfig, and waits for kata-cc runtime class.
#
# Environment variables:
#   DEPLOYMENT_MODE  - MachineConfig, DaemonSet, or DaemonSetFallback (default: MachineConfig)

source "$(dirname "$0")/../common/helpers.sh"

DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-"MachineConfig"}

echo "=== Enabling confidential containers ==="

oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: osc-feature-gates
  namespace: openshift-sandboxed-containers-operator
data:
  confidential: "true"
  deploymentMode: "${DEPLOYMENT_MODE}"
EOF

echo ""
echo "=== Creating KataConfig ==="

oc apply -f - <<EOF
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: example-kataconfig
spec:
  enablePeerPods: false
  checkNodeEligibility: false
  logLevel: info
EOF

echo ""
echo "  KataConfig created. Waiting for kata-cc installation..."
echo "  (this triggers a node reboot and can take 10-60 minutes)"

sleep 30

# Wait for MCP if using MachineConfig deployment mode
if [ "$DEPLOYMENT_MODE" == "MachineConfig" ]; then
  # On SNO the MCP is 'master', on multi-node it creates 'kata-oc'
  NODE_COUNT=$(oc get nodes --no-headers | wc -l)
  if [ "$NODE_COUNT" -eq 1 ]; then
    wait_for_mcp master || exit 1
  else
    wait_for_mcp kata-oc || exit 1
  fi
fi

echo ""
echo "  Waiting for runtime classes..."
wait_for_runtimeclass kata-cc || exit 1

echo ""
echo "=== OSC configured for bare metal confidential containers ==="
echo "  Runtime class: kata-cc"
echo "  Use runtimeClassName: kata-cc in your pod specs"
