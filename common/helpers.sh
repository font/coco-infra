#!/bin/bash
# Shared helper functions for CoCo setup scripts.
# Source this file: source "$(dirname "$0")/../common/helpers.sh"

function wait_for_deployment() {
  local deployment=$1
  local namespace=$2
  local timeout=${3:-300}
  local interval=25
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    local ready=$(oc get deployment -n "$namespace" "$deployment" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [ "$ready" -ge 1 ] 2>/dev/null; then
      echo "  Deployment $deployment is ready"
      return 0
    fi
    echo "  Waiting for $deployment ($elapsed/${timeout}s)..."
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  echo "ERROR: $deployment not ready after ${timeout}s"
  return 1
}

function wait_for_mcp() {
  local mcp=$1
  local timeout=${2:-1800}
  local interval=30
  local elapsed=0
  echo "  Waiting for MCP $mcp to finish updating..."
  while [ $elapsed -lt $timeout ]; do
    local updated=$(oc get mcp "$mcp" -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}' 2>/dev/null)
    local updating=$(oc get mcp "$mcp" -o jsonpath='{.status.conditions[?(@.type=="Updating")].status}' 2>/dev/null)
    local degraded=$(oc get mcp "$mcp" -o jsonpath='{.status.conditions[?(@.type=="Degraded")].status}' 2>/dev/null)
    if [ "$updated" == "True" ] && [ "$updating" == "False" ] && [ "$degraded" == "False" ]; then
      echo "  MCP $mcp is ready"
      return 0
    fi
    echo "  MCP $mcp: updated=$updated updating=$updating degraded=$degraded ($elapsed/${timeout}s)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  echo "ERROR: MCP $mcp not ready after ${timeout}s"
  return 1
}

function wait_for_runtimeclass() {
  local runtimeclass=$1
  local timeout=${2:-900}
  local interval=30
  local elapsed=0

  while [ $elapsed -lt $timeout ]; do
    local name=$(oc get runtimeclass "$runtimeclass" -o jsonpath='{.metadata.name}' 2>/dev/null)
    if [ "$name" == "$runtimeclass" ]; then
      echo "  RuntimeClass $runtimeclass is ready"
      return 0
    fi
    echo "  Waiting for RuntimeClass $runtimeclass ($elapsed/${timeout}s)..."
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  echo "ERROR: RuntimeClass $runtimeclass not ready after ${timeout}s"
  return 1
}

function wait_for_node_ready() {
  local timeout=${1:-1800}
  echo "  Waiting for node(s) to become Ready..."
  for i in $(seq 1 $((timeout / 15))); do
    if oc wait node --all --for=condition=Ready --timeout=15s 2>/dev/null; then
      echo "  Node(s) Ready"
      return 0
    fi
  done
  echo "ERROR: Node(s) not Ready after ${timeout}s"
  return 1
}
