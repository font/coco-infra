#!/bin/bash
set -e

# Recalculate PCR8 from the current INITDATA in peer-pods-cm and update
# the Trustee reference values. Run this after any change to INITDATA
# (e.g., region change, cert rotation).

echo "=== Calculating PCR8 from current INITDATA ==="

INITDATA_RAW=$(oc get configmap peer-pods-cm \
  -n openshift-sandboxed-containers-operator \
  -o jsonpath='{.data.INITDATA}' | base64 -d | gunzip)

initial_pcr=0000000000000000000000000000000000000000000000000000000000000000
hash=$(echo -n "$INITDATA_RAW" | sha256sum | cut -d' ' -f1)
PCR8_HASH=$(echo -n "$initial_pcr$hash" | xxd -r -p | sha256sum | cut -d' ' -f1)

echo "  New PCR8: $PCR8_HASH"

echo ""
echo "=== Updating reference values ==="

CURRENT_JSON=$(oc get configmap trusteeconfig-rvps-reference-values \
  -n trustee-operator-system \
  -o jsonpath='{.data.reference-values\.json}')

OLD_PCR8=$(echo "$CURRENT_JSON" | jq -r '.[] | select(.name == "snp_pcr08") | .value[0]')
echo "  Old PCR8: $OLD_PCR8"

if [[ "$OLD_PCR8" == "$PCR8_HASH" ]]; then
  echo "  PCR8 is already up to date, nothing to do."
  exit 0
fi

UPDATED_JSON=$(echo "$CURRENT_JSON" | jq --arg new "$PCR8_HASH" \
  '[ .[] | if (.name == "snp_pcr08" or .name == "tdx_pcr08") then .value = [$new] else . end ]')

oc patch configmap trusteeconfig-rvps-reference-values \
  -n trustee-operator-system \
  --type merge \
  -p "{\"data\":{\"reference-values.json\":$(echo "$UPDATED_JSON" | jq -Rs .)}}"

echo ""
echo "=== Restarting Trustee ==="
oc rollout restart deployment/trustee-deployment -n trustee-operator-system
oc rollout status deployment/trustee-deployment -n trustee-operator-system --timeout=120s

echo ""
echo "=== Done ==="
echo "  PCR8 updated: $OLD_PCR8 -> $PCR8_HASH"
echo "  Trustee restarted. New peer pod VMs will pass attestation."
