# Project Context

## What This Is
Automation scripts for provisioning Confidential Containers (CoCo) infrastructure. Currently supports ARO (Azure Red Hat OpenShift), with potential for other platforms in the future.

## Goal
Automate end-to-end CoCo setup: cluster creation, Trustee (attestation), and OSC (OpenShift Sandboxed Containers) with peer pods. Used for testing custom KServe builds with CoCo.

## Azure Lessons Learned
- The subscription has a cleanup policy (`dpp-toolkit` service principal) that deletes resource groups after ~12 hours. Request preservation before creating clusters.
- ARO-managed resource groups (`aro-*`) may be protected by Azure from deletion, but use `--cluster-resource-group` to give them a predictable name and request preservation anyway.
- Must deploy to `eastus2` for H100 peer pods (`Standard_NCC40ads_H100_v5`).
- `Standard_D8as_v5` and `Standard_D8ds_v5` can hit ZonalAllocationFailed in `eastus2` (transient). `Standard_D8s_v5` works.
- Must register `Microsoft.RedHatOpenShift` provider before first ARO create.

## Installation Order (Critical)
1. Create ARO cluster (`create-aro.sh`)
2. Install Trustee + cert-manager (`install-trustee.sh`)
3. Configure Trustee (`configure-trustee.sh` with `TRUSTEE_ENV=gen`)
4. Install OSC (`install-osc.sh`)
5. Configure OSC (`configure-osc.sh` with `INITDATA_PATH=./trustee/initdata.toml OSC_ENV=aro`)

## Claude Code Skills
- `/coco-create` — Create ARO cluster with full CoCo setup
- `/coco-destroy` — Tear down cluster and clean up all resource groups
- `/coco-status` — Check cluster and CoCo component status

## Commit Style
- Lowercase, no period, imperative mood (e.g., "add status script for cluster and CoCo components")
