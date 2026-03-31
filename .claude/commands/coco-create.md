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
- Region: eastus2

The cluster creation takes ~40 minutes. Run the setup in the background and notify when complete.

After completion, run the status script to verify everything is healthy:
```
RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve bash aro/status.sh
```
