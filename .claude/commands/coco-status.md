Check the status of the ARO cluster and CoCo components.

1. Log in to the cluster if not already logged in:
   ```
   RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve
   PASS=$(az aro list-credentials -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query kubeadminPassword -o tsv)
   API=$(az aro show -g "$RESOURCE_GROUP" -n "$CLUSTER_NAME" --query apiserverProfile.url -o tsv)
   oc login "$API" -u kubeadmin -p "$PASS" --insecure-skip-tls-verify=true
   ```
2. Run the status script:
   ```
   RESOURCE_GROUP=ifont-coco-rg CLUSTER_NAME=coco-kserve bash aro/status.sh
   ```
3. Summarize the results in a table showing component status.
