#!/bin/bash
set -e

# Apply MachineConfig for Intel TDX and IOMMU kernel args.
# On SNO this triggers sequential reboots (one per MachineConfig change).

source "$(dirname "$0")/../common/helpers.sh"

TEE_TYPE=${TEE_TYPE:-"tdx"}

echo "=== Applying MachineConfig for TEE and IOMMU ==="

# Determine MachineConfig role label (master for SNO, kata-oc for multi-node)
NODE_COUNT=$(oc get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -eq 1 ]; then
  MC_ROLE="master"
  echo "  SNO detected, using role: master"
else
  MC_ROLE="worker"
  echo "  Multi-node detected, using role: worker"
fi

# Check if TDX MachineConfig already exists
if oc get machineconfig 99-enable-intel-tdx &>/dev/null; then
  echo "  TDX MachineConfig already exists, skipping"
else
  if [ "$TEE_TYPE" == "tdx" ]; then
    echo "  Applying Intel TDX MachineConfig..."
    oc apply -f - <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: ${MC_ROLE}
  name: 99-enable-intel-tdx
spec:
  kernelArguments:
    - kvm_intel.tdx=1
    - nohibernate
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/modules-load.d/vsock.conf
          mode: 0644
          contents:
            source: data:text/plain;charset=utf-8;base64,dnNvY2sK
EOF
  fi
fi

# Check if IOMMU MachineConfig already exists
if oc get machineconfig 100-iommu-kernel-args &>/dev/null; then
  echo "  IOMMU MachineConfig already exists, skipping"
else
  echo "  Applying IOMMU MachineConfig..."
  oc apply -f - <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: ${MC_ROLE}
  name: 100-iommu-kernel-args
spec:
  config:
    ignition:
      version: 3.2.0
  kernelArguments:
    - intel_iommu=on
EOF
fi

echo ""
echo "  Waiting for MachineConfig rollout (node will reboot)..."
wait_for_mcp "$MC_ROLE" || exit 1
wait_for_node_ready || exit 1

echo ""
echo "=== MachineConfig applied successfully ==="
