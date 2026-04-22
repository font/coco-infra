#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Configuration
RESOURCE_GROUP=${RESOURCE_GROUP:-"${USER}-coco-rg"}
CLUSTER_NAME=${CLUSTER_NAME:-"${USER}-coco"}
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
TRUSTEE_CSV=trustee-operator.v1.0.0 TRUSTEE_APPROVAL=Manual bash "$SCRIPT_DIR/../common/install-trustee.sh"

# Step 3: Configure Trustee
echo ""
echo "=== Step 3/5: Configuring Trustee ==="
TRUSTEE_ENV=gen TRUSTEE_DIR="$SCRIPT_DIR/trustee" bash "$SCRIPT_DIR/../common/configure-trustee.sh"

# Step 4: Install OSC
echo ""
echo "=== Step 4/5: Installing OSC ==="
OSC_CSV=sandboxed-containers-operator.v1.11.1 OSC_APPROVAL=Manual bash "$SCRIPT_DIR/../common/install-osc.sh"

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
