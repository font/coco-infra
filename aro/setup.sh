#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
RESOURCE_GROUP=${RESOURCE_GROUP:-"coco-rg"}
CLUSTER_NAME=${CLUSTER_NAME:-"coco-kserve"}
SKIP_CLUSTER=${SKIP_CLUSTER:-"false"}

echo "################################################"
echo "CoCo on ARO - Full Setup"
echo "  Resource group: $RESOURCE_GROUP"
echo "  Cluster name:   $CLUSTER_NAME"
echo "  Skip cluster:   $SKIP_CLUSTER"
echo "################################################"

# Step 1: Create ARO cluster (or skip if already exists)
if [[ "$SKIP_CLUSTER" == "true" ]]; then
  echo "Skipping cluster creation (SKIP_CLUSTER=true)"
else
  echo ""
  echo "=== Step 1/5: Creating ARO cluster ==="
  RESOURCE_GROUP="$RESOURCE_GROUP" CLUSTER_NAME="$CLUSTER_NAME" bash "$SCRIPT_DIR/create-aro.sh"
fi

# Verify we're logged in
if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to OpenShift. Log in first or set SKIP_CLUSTER=false." >&2
  exit 1
fi

# Step 2: Install Trustee + cert-manager
echo ""
echo "=== Step 2/5: Installing Trustee + cert-manager ==="
bash "$SCRIPT_DIR/install-trustee.sh"

# Step 3: Configure Trustee
echo ""
echo "=== Step 3/5: Configuring Trustee ==="
TRUSTEE_ENV=gen bash "$SCRIPT_DIR/configure-trustee.sh"

# Step 4: Install OSC
echo ""
echo "=== Step 4/5: Installing OSC ==="
bash "$SCRIPT_DIR/install-osc.sh"

# Step 5: Configure OSC
echo ""
echo "=== Step 5/5: Configuring OSC ==="
INITDATA_PATH="$SCRIPT_DIR/trustee/initdata.toml" OSC_ENV=aro bash "$SCRIPT_DIR/configure-osc.sh"

echo ""
echo "################################################"
echo "CoCo setup complete!"
echo "You can now deploy workloads with:"
echo "  runtimeClassName: kata-remote"
echo "################################################"
