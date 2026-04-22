#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
SKIP_MACHINECONFIG=${SKIP_MACHINECONFIG:-"false"}
SKIP_GPU=${SKIP_GPU:-"false"}
TEE_TYPE=${TEE_TYPE:-"tdx"}

echo "################################################"
echo "CoCo on Bare Metal - Full Setup"
echo "  TEE type:           $TEE_TYPE"
echo "  Skip MachineConfig: $SKIP_MACHINECONFIG"
echo "  Skip GPU:           $SKIP_GPU"
echo "################################################"

# Verify we're logged in
if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to OpenShift. Log in with oc login first." >&2
  exit 1
fi

TOTAL_STEPS=7
if [[ "$SKIP_GPU" == "true" ]]; then
  TOTAL_STEPS=$((TOTAL_STEPS - 1))
fi

STEP=0

# Step 1: MachineConfig for TDX + IOMMU
STEP=$((STEP + 1))
if [[ "$SKIP_MACHINECONFIG" == "true" ]]; then
  echo "Skipping MachineConfig (SKIP_MACHINECONFIG=true)"
else
  echo ""
  echo "=== Step ${STEP}/${TOTAL_STEPS}: Applying MachineConfig (TDX + IOMMU) ==="
  TEE_TYPE="$TEE_TYPE" bash "$SCRIPT_DIR/configure-machineconfig.sh"
fi

# Step 2: Install NFD (required before OSC for TEE detection)
STEP=$((STEP + 1))
echo ""
echo "=== Step ${STEP}/${TOTAL_STEPS}: Installing NFD ==="
bash "$SCRIPT_DIR/install-nfd.sh"

# Step 3: Install Trustee + cert-manager
STEP=$((STEP + 1))
echo ""
echo "=== Step ${STEP}/${TOTAL_STEPS}: Installing Trustee + cert-manager ==="
bash "$SCRIPT_DIR/../common/install-trustee.sh"

# Step 4: Configure Trustee
STEP=$((STEP + 1))
echo ""
echo "=== Step ${STEP}/${TOTAL_STEPS}: Configuring Trustee ==="
TRUSTEE_DIR="$SCRIPT_DIR/trustee" bash "$SCRIPT_DIR/../common/configure-trustee.sh"

# Step 5: Install OSC
STEP=$((STEP + 1))
echo ""
echo "=== Step ${STEP}/${TOTAL_STEPS}: Installing OSC ==="
bash "$SCRIPT_DIR/../common/install-osc.sh"

# Step 6: Configure OSC for bare metal confidential containers
STEP=$((STEP + 1))
echo ""
echo "=== Step ${STEP}/${TOTAL_STEPS}: Configuring OSC ==="
bash "$SCRIPT_DIR/configure-osc.sh"

# Step 7: Install GPU Operator (optional)
if [[ "$SKIP_GPU" != "true" ]]; then
  STEP=$((STEP + 1))
  echo ""
  echo "=== Step ${STEP}/${TOTAL_STEPS}: Installing GPU Operator ==="
  bash "$SCRIPT_DIR/install-gpu.sh"
fi

echo ""
echo "################################################"
echo "CoCo bare metal setup complete!"
echo "You can now deploy workloads with:"
echo "  runtimeClassName: kata-cc"
echo "################################################"
