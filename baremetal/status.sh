#!/bin/bash

echo "################################################"
echo "CoCo on Bare Metal - Status"
echo "################################################"

# Check OpenShift login
echo ""
echo "=== OpenShift Login ==="
if ! oc whoami &>/dev/null; then
  echo "  Not logged in"
  exit 0
fi
echo "  User: $(oc whoami)"

# Node
echo ""
echo "=== Node ==="
oc get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage

# Host / TEE
echo ""
echo "=== Host / TEE ==="
HOST=$(oc get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
if ssh -q -o ConnectTimeout=3 core@"$HOST" true 2>/dev/null; then
  BIOS_VERSION=$(ssh -q core@"$HOST" "sudo dmidecode -s bios-version" 2>/dev/null)
  BIOS_DATE=$(ssh -q core@"$HOST" "sudo dmidecode -s bios-release-date" 2>/dev/null)
  CPU_VENDOR=$(ssh -q core@"$HOST" "grep -m1 vendor_id /proc/cpuinfo" 2>/dev/null | awk '{print $3}')
  echo "  BIOS: ${BIOS_VERSION:-unknown} (${BIOS_DATE:-unknown})"
  echo "  CPU: ${CPU_VENDOR:-unknown}"

  if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    TDX_MODULE=$(ssh -q core@"$HOST" "dmesg | grep 'TDX module'" 2>/dev/null | sed 's/.*TDX module //')
    TDX_INIT=$(ssh -q core@"$HOST" "dmesg | grep -c 'tdx: module initialized'" 2>/dev/null)
    if [[ -z "$TDX_MODULE" ]]; then
      echo "  TDX module: NOT FOUND [WARNING]"
    else
      TDX_VER=$(echo "$TDX_MODULE" | awk -F'[, ]' '{print $1}')
      TDX_MIN="1.5.16"
      if [[ "$(printf '%s\n' "$TDX_MIN" "$TDX_VER" | sort -V | head -1)" != "$TDX_MIN" ]]; then
        echo "  TDX module: $TDX_MODULE [WARNING: below minimum $TDX_MIN]"
      elif [[ "$TDX_INIT" -eq 0 ]]; then
        echo "  TDX module: $TDX_MODULE [WARNING: not initialized]"
      else
        echo "  TDX module: $TDX_MODULE"
      fi
    fi
  elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    SEV_INFO=$(ssh -q core@"$HOST" "dmesg | grep -i 'SEV-SNP'" 2>/dev/null | head -1)
    SEV_DEV=$(ssh -q core@"$HOST" "ls /dev/sev 2>/dev/null && echo found" 2>/dev/null)
    if [[ -n "$SEV_INFO" ]]; then
      echo "  SEV-SNP: ${SEV_INFO##*] }"
    elif [[ -n "$SEV_DEV" ]]; then
      echo "  SEV: /dev/sev present"
    else
      echo "  SEV-SNP: NOT FOUND [WARNING]"
    fi
  else
    echo "  TEE: unknown CPU vendor"
  fi
else
  echo "  SSH to $HOST not available"
fi

# Extended resources
echo ""
echo "=== Extended Resources ==="
NODE=$(oc get nodes -o jsonpath='{.items[0].metadata.name}')
oc get node "$NODE" -o json | jq -r '.status.capacity | to_entries[] | select(.key | test("tdx|sgx|nvidia|gpu")) | "  \(.key): \(.value)"'

# Runtime classes
echo ""
echo "=== Runtime Classes ==="
for rc in kata kata-cc kata-cc-nvidia-gpu kata-nvidia-gpu; do
  if oc get runtimeclass "$rc" &>/dev/null; then
    HANDLER=$(oc get runtimeclass "$rc" -o jsonpath='{.handler}')
    echo "  $rc (handler: $HANDLER): available"
  fi
done

# OSC
echo ""
echo "=== OSC Operator ==="
OSC_CSV=$(oc get csv -n openshift-sandboxed-containers-operator --no-headers 2>/dev/null | awk '/sandboxed/ {print $6}')
OSC_READY=$(oc get deployment controller-manager -n openshift-sandboxed-containers-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$OSC_READY" ]]; then
  echo "  Version: ${OSC_CSV:-unknown}"
  echo "  Controller: $OSC_READY replica(s) ready"
  oc get pods -n openshift-sandboxed-containers-operator --no-headers 2>/dev/null | awk '{printf "  %-50s %s\n", $1, $3}'
else
  echo "  Not installed"
fi

# KataConfig
echo ""
echo "=== KataConfig ==="
KATA_STATUS=$(oc get kataconfig example-kataconfig -o jsonpath='{.status.conditions[?(@.type=="InProgress")].status}' 2>/dev/null)
if [[ -n "$KATA_STATUS" ]]; then
  echo "  InProgress: $KATA_STATUS"
  INSTALLED=$(oc get kataconfig example-kataconfig -o jsonpath='{.status.kataNodes.installed}' 2>/dev/null)
  echo "  Installed nodes: ${INSTALLED:-none}"
else
  echo "  Not found"
fi

# Feature gates
echo ""
echo "=== Feature Gates ==="
CONFIDENTIAL=$(oc get configmap osc-feature-gates -n openshift-sandboxed-containers-operator -o jsonpath='{.data.confidential}' 2>/dev/null)
DEPLOY_MODE=$(oc get configmap osc-feature-gates -n openshift-sandboxed-containers-operator -o jsonpath='{.data.deploymentMode}' 2>/dev/null)
echo "  confidential: ${CONFIDENTIAL:-not set}"
echo "  deploymentMode: ${DEPLOY_MODE:-not set}"

# NFD
echo ""
echo "=== NFD ==="
NFD_READY=$(oc get deployment nfd-controller-manager -n openshift-nfd -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
NFD_WORKERS=$(oc get pods -n openshift-nfd -l app=nfd-worker --no-headers 2>/dev/null | grep -c Running)
if [[ -n "$NFD_READY" ]]; then
  echo "  Controller: $NFD_READY replica(s) ready"
  echo "  Workers: $NFD_WORKERS running"
else
  echo "  Not installed"
fi

# NodeFeatureRules
echo ""
echo "=== NodeFeatureRules ==="
oc get nodefeaturerule -A --no-headers 2>/dev/null | awk '{printf "  %-40s %s\n", $2, $1}'
if [[ $(oc get nodefeaturerule -A --no-headers 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "  None found"
fi

# Intel Device Plugins
echo ""
echo "=== Intel Device Plugins ==="
INTEL_READY=$(oc get deployment intel-deviceplugins-controller-manager -n intel-device-plugins-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$INTEL_READY" ]]; then
  echo "  Controller: $INTEL_READY replica(s) ready"
  oc get pods -n intel-device-plugins-operator --no-headers 2>/dev/null | awk '{printf "  %-55s %s\n", $1, $3}'
else
  echo "  Not installed"
fi

# SGX device plugin
SGX_READY=$(oc get sgxdeviceplugin -A --no-headers 2>/dev/null)
if [[ -n "$SGX_READY" ]]; then
  echo "  SGX plugin:"
  echo "$SGX_READY" | awk '{printf "    %-40s desired=%s ready=%s\n", $1, $2, $3}'
fi

# Intel DCAP
echo ""
echo "=== Intel DCAP ==="
PCCS_READY=$(oc get deployment pccs -n intel-dcap -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
QGS_READY=$(oc get daemonset tdx-qgs -n intel-dcap -o jsonpath='{.status.numberReady}' 2>/dev/null)
if [[ -n "$PCCS_READY" || -n "$QGS_READY" ]]; then
  echo "  PCCS: ${PCCS_READY:-0} replica(s) ready"
  echo "  QGS: ${QGS_READY:-0} pod(s) ready"
  oc get pods -n intel-dcap --no-headers 2>/dev/null | awk '{printf "  %-40s %s\n", $1, $3}'
else
  echo "  Not installed"
fi

# NVIDIA GPU Operator
echo ""
echo "=== NVIDIA GPU Operator ==="
GPU_READY=$(oc get deployment gpu-operator -n nvidia-gpu-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$GPU_READY" ]]; then
  echo "  Operator: $GPU_READY replica(s) ready"
  oc get pods -n nvidia-gpu-operator --no-headers 2>/dev/null | awk '{printf "  %-55s %s\n", $1, $3}'
else
  echo "  Not installed"
fi

# Trustee
echo ""
echo "=== Trustee ==="
TRUSTEE_READY=$(oc get deployment trustee-deployment -n trustee-operator-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ -n "$TRUSTEE_READY" ]]; then
  echo "  Trustee: $TRUSTEE_READY replica(s) ready"
  oc get pods -n trustee-operator-system --no-headers 2>/dev/null | awk '{printf "  %-55s %s\n", $1, $3}'
else
  echo "  Not installed"
fi

# MachineConfig
echo ""
echo "=== MachineConfig ==="
oc get machineconfig --no-headers 2>/dev/null | grep -E "kata|tdx|iommu|sandboxed" | awk '{printf "  %-55s %s\n", $1, $3}'
if [[ $(oc get machineconfig --no-headers 2>/dev/null | grep -cE "kata|tdx|iommu|sandboxed") -eq 0 ]]; then
  echo "  No CoCo-related MachineConfigs found"
fi

# MCP status
echo ""
echo "=== MCP Status ==="
oc get mcp --no-headers 2>/dev/null | awk '{printf "  %-15s updated=%s updating=%s degraded=%s\n", $1, $3, $4, $5}'

# Pending/failing pods
echo ""
echo "=== Problem Pods ==="
PROBLEMS=$(oc get pods -A --no-headers 2>/dev/null | grep -vE "Running|Completed|Succeeded" | grep -v "installer-")
if [[ -n "$PROBLEMS" ]]; then
  echo "$PROBLEMS" | awk '{printf "  %-50s %-20s %s\n", $2, $1, $4}'
else
  echo "  None"
fi

echo ""
echo "################################################"
