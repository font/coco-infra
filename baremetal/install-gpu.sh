#!/bin/bash
set -e

# Install the NVIDIA GPU Operator and create ClusterPolicy for
# confidential containers with GPU passthrough.

source "$(dirname "$0")/../common/helpers.sh"

echo "=== Installing NVIDIA GPU Operator ==="

oc apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
    - nvidia-gpu-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: v24.9
  installPlanApproval: Automatic
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF

echo "  Waiting for GPU operator..."
wait_for_deployment gpu-operator nvidia-gpu-operator || exit 1

echo ""
echo "=== Labeling nodes for GPU ==="

for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do
  oc label node "$node" nvidia.com/gpu.present=true --overwrite
  echo "  Labeled $node"
done

echo ""
echo "=== Creating ClusterPolicy ==="

oc apply -f - <<'EOF'
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  ccManager:
    defaultMode: "on"
    enabled: true
  cdi:
    default: false
    enabled: true
    nriPluginEnabled: false
  daemonsets:
    rollingUpdate:
      maxUnavailable: '1'
    updateStrategy: RollingUpdate
  dcgm:
    enabled: false
  dcgmExporter:
    config:
      name: ''
    enabled: false
    serviceMonitor:
      enabled: true
  devicePlugin:
    config:
      default: ''
      name: ''
    enabled: false
    mps:
      root: /run/nvidia/mps
  driver:
    certConfig:
      name: ''
    enabled: false
    kernelModuleConfig:
      name: ''
    kernelModuleType: auto
    licensingConfig:
      configMapName: ''
      nlsEnabled: true
    repoConfig:
      configMapName: ''
    upgradePolicy:
      autoUpgrade: true
      drain:
        deleteEmptyDir: false
        enable: false
        force: false
        timeoutSeconds: 300
      maxParallelUpgrades: 1
      maxUnavailable: 25%
      podDeletion:
        deleteEmptyDir: false
        force: false
        timeoutSeconds: 300
      waitForCompletion:
        timeoutSeconds: 0
    useNvidiaDriverCRD: false
    useOpenKernelModules: false
    virtualTopology:
      config: ''
  gdrcopy:
    enabled: false
  gds:
    enabled: false
  gfd:
    enabled: true
  kataManager:
    enabled: false
  mig:
    strategy: single
  migManager:
    enabled: false
  nodeStatusExporter:
    enabled: true
  operator:
    defaultRuntime: crio
    initContainer: {}
    runtimeClass: nvidia
    use_ocp_driver_toolkit: true
  sandboxDevicePlugin:
    enabled: true
    env:
      - name: P_GPU_ALIAS
        value: pgpu
      - name: NVSWITCH_ALIAS
        value: nvswitch
  sandboxWorkloads:
    defaultWorkload: vm-passthrough
    enabled: true
    mode: kata
  toolkit:
    enabled: false
    installDir: /usr/local/nvidia
  validator:
    plugin:
      env:
        - name: WITH_WORKLOAD
          value: 'false'
  vfioManager:
    enabled: true
    env:
      - name: BIND_NVSWITCHES
        value: 'true'
  vgpuDeviceManager:
    enabled: false
  vgpuManager:
    enabled: false
EOF

echo "  Waiting for GPU operator pods..."
sleep 30
for i in $(seq 1 30); do
  RUNNING=$(oc get pods -n nvidia-gpu-operator --no-headers 2>/dev/null | grep -c Running)
  if [ "$RUNNING" -ge 3 ] 2>/dev/null; then
    echo "  GPU operator pods running ($RUNNING pods)"
    break
  fi
  echo "  Waiting for GPU pods ($RUNNING running, $i/30)..."
  sleep 20
done

echo ""
echo "=== NVIDIA GPU Operator installed ==="
