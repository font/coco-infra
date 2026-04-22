#!/bin/bash
set -e

# Install the OpenShift Sandboxed Containers operator.
# Works for both ARO and bare metal.
#
# Environment variables:
#   OSC_CSV       - starting CSV (default: sandboxed-containers-operator.v1.12.0)
#   OSC_APPROVAL  - install plan approval: Automatic or Manual (default: Automatic)

source "$(dirname "$0")/../common/helpers.sh"

OSC_CSV=${OSC_CSV:-"sandboxed-containers-operator.v1.12.0"}
OSC_APPROVAL=${OSC_APPROVAL:-"Automatic"}

echo "=== Installing OSC operator ==="
echo "  CSV: $OSC_CSV"
echo "  Approval: $OSC_APPROVAL"

oc apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-sandboxed-containers-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: sandboxed-containers-operator-group
  namespace: openshift-sandboxed-containers-operator
spec:
  targetNamespaces:
    - openshift-sandboxed-containers-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: sandboxed-containers-operator
  namespace: openshift-sandboxed-containers-operator
spec:
  channel: stable
  installPlanApproval: ${OSC_APPROVAL}
  name: sandboxed-containers-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: ${OSC_CSV}
EOF

if [ "$OSC_APPROVAL" == "Manual" ]; then
  echo "  Approving OSC install plan..."
  for i in $(seq 1 30); do
    PLAN=$(oc get installplan -n openshift-sandboxed-containers-operator -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null)
    if [ -n "$PLAN" ]; then
      echo "$PLAN" | xargs -r oc patch installplan -n openshift-sandboxed-containers-operator --type merge -p '{"spec":{"approved":true}}'
      break
    fi
    echo "  Waiting for install plan... ($i/30)"
    sleep 10
  done
fi

echo "  Waiting for OSC operator..."
wait_for_deployment controller-manager openshift-sandboxed-containers-operator || exit 1

echo ""
echo "=== OSC operator installed ==="
