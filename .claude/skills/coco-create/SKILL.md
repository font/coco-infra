---
description: Create an ARO cluster with full CoCo (Confidential Containers) setup
user_invocable: true
---

Create an ARO cluster with full CoCo (Confidential Containers) setup.

Run the setup script with the standard environment variables:

```
RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve bash aro/setup.sh
```

This runs 5 steps in order:
1. Create ARO cluster (create-aro.sh)
2. Install Trustee + cert-manager (install-trustee.sh)
3. Configure Trustee (configure-trustee.sh with TRUSTEE_ENV=gen)
4. Install OSC (install-osc.sh)
5. Configure OSC (configure-osc.sh with INITDATA_PATH and OSC_ENV=aro)

Before running, confirm with the user:
- Resource group: ifont-coco-rg
- Cluster name: coco-kserve
- Region (LOCATION): default eastus2, can override (e.g., westus for cheaper SEV-SNP testing)
- Peer pod VM size (AZURE_INSTANCE_SIZE): default Standard_DC4as_v5, use Standard_NCC40ads_H100_v5 for GPU

The cluster creation takes ~40 minutes. Run the setup in the background and notify when complete.

After completion, run the status script to verify everything is healthy:
```
RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve bash aro/status.sh
```
