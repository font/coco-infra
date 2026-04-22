#!/bin/bash
set -e

# Install Trustee operator and cert-manager.
# Works for both ARO and bare metal.
#
# Environment variables:
#   TRUSTEE_CSV      - starting CSV (default: trustee-operator.v1.1.0)
#   TRUSTEE_APPROVAL - install plan approval: Automatic or Manual (default: Automatic)

source "$(dirname "$0")/../common/helpers.sh"

TRUSTEE_CSV=${TRUSTEE_CSV:-"trustee-operator.v1.1.0"}
TRUSTEE_APPROVAL=${TRUSTEE_APPROVAL:-"Automatic"}

echo "=== Installing Trustee operator ==="
echo "  CSV: $TRUSTEE_CSV"
echo "  Approval: $TRUSTEE_APPROVAL"

oc apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: trustee-operator-system
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: trustee-operator-group
  namespace: trustee-operator-system
spec:
  targetNamespaces:
    - trustee-operator-system
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: trustee-operator
  namespace: trustee-operator-system
spec:
  channel: stable
  installPlanApproval: ${TRUSTEE_APPROVAL}
  name: trustee-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: ${TRUSTEE_CSV}
EOF

if [ "$TRUSTEE_APPROVAL" == "Manual" ]; then
  echo "  Approving Trustee install plan..."
  for i in $(seq 1 30); do
    PLAN=$(oc get installplan -n trustee-operator-system -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null)
    if [ -n "$PLAN" ]; then
      echo "$PLAN" | xargs -r oc patch installplan -n trustee-operator-system --type merge -p '{"spec":{"approved":true}}'
      break
    fi
    echo "  Waiting for install plan... ($i/30)"
    sleep 10
  done
fi

echo ""
echo "=== Installing cert-manager ==="

oc apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  targetNamespaces:
    - cert-manager-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: stable-v1
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

echo "  Waiting for Trustee operator..."
wait_for_deployment trustee-operator-controller-manager trustee-operator-system || exit 1
echo "  Waiting for cert-manager..."
wait_for_deployment cert-manager-operator-controller-manager cert-manager-operator || exit 1

sleep 10

echo ""
echo "=== Trustee and cert-manager installed ==="
