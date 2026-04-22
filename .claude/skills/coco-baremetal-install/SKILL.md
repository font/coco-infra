---
description: Install and configure CoCo on an existing bare metal OpenShift cluster
user_invocable: true
---

Install and configure Confidential Containers (CoCo) on an existing bare metal OpenShift cluster. This assumes OCP 4.20+ is already installed (SNO or multi-node) and the user is logged in via `oc`.

Steps:
1. Verify the user is logged in: `oc whoami && oc get nodes`
2. Confirm with the user:
   - TEE type (TEE_TYPE): default `tdx` (Intel TDX)
   - Skip MachineConfig (SKIP_MACHINECONFIG): if kernel args are already applied
   - Skip GPU setup (SKIP_GPU): if no GPU passthrough needed
3. Run setup:
   ```
   bash baremetal/setup.sh
   ```
   Run this in the background — it takes 30-60 minutes (MachineConfig triggers node reboots on SNO).

   For GPU-enabled TDX setup with MachineConfig already applied:
   ```
   SKIP_MACHINECONFIG=true bash baremetal/setup.sh
   ```

   For non-GPU setup:
   ```
   SKIP_GPU=true bash baremetal/setup.sh
   ```

4. After completion, verify:
   ```
   oc get runtimeclass kata-cc
   oc get pods -n openshift-sandboxed-containers-operator
   oc get pods -n trustee-operator-system
   ```

Key differences from ARO:
- Uses `kata-cc` runtime class (not `kata-remote`)
- KataConfig has `enablePeerPods: false`
- MachineConfig applies kernel args for TDX and IOMMU
- Includes NFD and NVIDIA GPU Operator for GPU passthrough
