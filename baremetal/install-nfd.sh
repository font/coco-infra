#!/bin/bash
set -e

# Install the Node Feature Discovery (NFD) operator and create
# NodeFeatureDiscovery + NodeFeatureRule CRs for TEE and GPU detection.

source "$(dirname "$0")/../common/helpers.sh"

echo "=== Installing NFD operator ==="

oc apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nfd
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nfd-operator-group
  namespace: openshift-nfd
spec:
  targetNamespaces:
    - openshift-nfd
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-nfd
spec:
  channel: stable
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "  Waiting for NFD operator..."
wait_for_deployment nfd-controller-manager openshift-nfd || exit 1

echo ""
echo "=== Creating NodeFeatureDiscovery CR ==="

OCP_VERSION=$(oc version -o json | jq -r '.openshiftVersion' | cut -d. -f1,2)

oc apply -f - <<EOF
apiVersion: nfd.openshift.io/v1
kind: NodeFeatureDiscovery
metadata:
  name: nfd-instance
  namespace: openshift-nfd
spec:
  operand:
    image: registry.redhat.io/openshift4/ose-node-feature-discovery-rhel9:v${OCP_VERSION}
    imagePullPolicy: Always
    servicePort: 12000
  workerConfig:
    configData: |
EOF

echo "  Waiting for NFD worker pods..."
for i in $(seq 1 30); do
  READY=$(oc get pods -n openshift-nfd -l app.kubernetes.io/component=worker --no-headers 2>/dev/null | grep -c Running)
  if [ "$READY" -ge 1 ] 2>/dev/null; then
    echo "  NFD worker pods running"
    break
  fi
  echo "  Waiting for NFD workers ($i/30)..."
  sleep 10
done

echo ""
echo "=== Creating NodeFeatureRule ==="

oc apply -f - <<EOF
apiVersion: nfd.openshift.io/v1alpha1
kind: NodeFeatureRule
metadata:
  name: consolidated-hardware-features
  namespace: openshift-nfd
spec:
  rules:
    - name: runtime.kata
      labels:
        feature.node.kubernetes.io/runtime.kata: "true"
      matchAny:
        - matchFeatures:
            - feature: cpu.cpuid
              matchExpressions:
                SSE42: { op: Exists }
                VMX: { op: Exists }
            - feature: kernel.loadedmodule
              matchExpressions:
                kvm: { op: Exists }
                kvm_intel: { op: Exists }
        - matchFeatures:
            - feature: cpu.cpuid
              matchExpressions:
                SSE42: { op: Exists }
                SVM: { op: Exists }
            - feature: kernel.loadedmodule
              matchExpressions:
                kvm: { op: Exists }
                kvm_amd: { op: Exists }
    - name: amd.sev-snp
      labels:
        amd.feature.node.kubernetes.io/snp: "true"
      extendedResources:
        sev-snp.amd.com/esids: "@cpu.security.sev.encrypted_state_ids"
      matchFeatures:
        - feature: cpu.cpuid
          matchExpressions:
            SVM: { op: Exists }
        - feature: cpu.security
          matchExpressions:
            sev.snp.enabled: { op: Exists }
    - name: intel.sgx
      labels:
        intel.feature.node.kubernetes.io/sgx: "true"
      extendedResources:
        sgx.intel.com/epc: "@cpu.security.sgx.epc"
      matchFeatures:
        - feature: cpu.cpuid
          matchExpressions:
            SGX: { op: Exists }
            SGXLC: { op: Exists }
        - feature: cpu.security
          matchExpressions:
            sgx.enabled: { op: IsTrue }
        - feature: kernel.config
          matchExpressions:
            X86_SGX: { op: Exists }
    - name: intel.tdx
      labels:
        intel.feature.node.kubernetes.io/tdx: "true"
      extendedResources:
        tdx.intel.com/keys: "@cpu.security.tdx.total_keys"
      matchFeatures:
        - feature: cpu.cpuid
          matchExpressions:
            VMX: { op: Exists }
        - feature: cpu.security
          matchExpressions:
            tdx.enabled: { op: Exists }
    - name: kernel-module-gdrdrv
      labels:
        nvidia.com/gdrcopy.capable: "true"
      matchFeatures:
        - feature: kernel.loadedmodule
          matchExpressions:
            gdrdrv:
              op: Exists
    - name: kernel-module-nvidia_fs
      labels:
        nvidia.com/gds.capable: "true"
      matchFeatures:
        - feature: kernel.loadedmodule
          matchExpressions:
            nvidia_fs:
              op: Exists
    - name: kernel-module-nvidia_peermem
      labels:
        nvidia.com/peermem.capable: "true"
      matchFeatures:
        - feature: kernel.loadedmodule
          matchExpressions:
            nvidia_peermem:
              op: Exists
EOF

echo ""
echo "=== NFD installed and configured ==="
