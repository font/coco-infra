---
description: Install and configure CoCo on an existing OpenShift cluster
user_invocable: true
---

Install and configure Confidential Containers (CoCo) on an already running OpenShift cluster. This assumes the cluster exists and the user is logged in via `oc`.

Steps:
1. Verify the user is logged in: `oc whoami && oc get nodes`
2. Confirm with the user:
   - Peer pod VM size (AZURE_INSTANCE_SIZE): default Standard_DC4as_v5, use Standard_NCC40ads_H100_v5 for GPU
3. Run setup with SKIP_CLUSTER=true:
   ```
   RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve SKIP_CLUSTER=true bash aro/setup.sh
   ```
   Run this in the background — it takes ~30 minutes (mostly waiting for kata MCP rollout).

4. After completion, run the status script to verify everything is healthy:
   ```
   RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve bash aro/status.sh
   ```
