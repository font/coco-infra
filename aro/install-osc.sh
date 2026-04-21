#! /bin/bash
set -e

function wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=300
    local interval=25
    local elapsed=0
    local ready=0

    while [ $elapsed -lt $timeout ]; do
        ready=$(oc get deployment -n "$namespace" "$deployment" -o jsonpath='{.status.readyReplicas}')
        if [ "$ready" == "1" ]; then
            echo "Operator $deployment is ready"
            return 0
        fi
        echo "Operator $deployment is not yet ready, waiting another $interval seconds"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    echo "Operator $deployment is not ready after $timeout seconds"
    return 1
}

echo "################################################"
echo "Starting the script. Many of the following commands"
echo "will periodically check on OCP for operations to"
echo "complete, so it's normal to see errors."
echo "If this scripts completes successfully, you will"
echo "see a final message confirming installation went"
echo "well."
echo "################################################"

echo ""
echo "############################ Install OSC ########################"
oc apply -f-<<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-sandboxed-containers-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-sandboxed-containers-operator
  namespace: openshift-sandboxed-containers-operator
spec:
  targetNamespaces:
  - openshift-sandboxed-containers-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-sandboxed-containers-operator
  namespace: openshift-sandboxed-containers-operator
spec:
  channel: stable
  installPlanApproval: Manual
  name: sandboxed-containers-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: sandboxed-containers-operator.v1.11.1
EOF

echo "Approving OSC install plan..."
for i in $(seq 1 30); do
  PLAN=$(oc get installplan -n openshift-sandboxed-containers-operator -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null)
  if [ -n "$PLAN" ]; then
    echo "$PLAN" | xargs -r oc patch installplan -n openshift-sandboxed-containers-operator --type merge -p '{"spec":{"approved":true}}'
    break
  fi
  echo "Waiting for install plan... ($i/30)"
  sleep 10
done

echo "############################ Wait for OSC ########################"
wait_for_deployment controller-manager openshift-sandboxed-containers-operator || exit 1

echo ""
echo "################################################"
echo "OSC installed successfully!"
echo "################################################"