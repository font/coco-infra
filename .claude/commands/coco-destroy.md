Destroy the ARO cluster and clean up all Azure resource groups.

Steps:
1. Confirm with the user before proceeding (this is destructive and irreversible).
2. Delete the ARO cluster:
   ```
   az aro delete --resource-group ifont-coco-rg --name coco-kserve --yes
   ```
   Run this in the background as it takes ~15-20 minutes.
3. Once cluster deletion completes, delete the resource group:
   ```
   az group delete --name ifont-coco-rg --yes --no-wait
   ```
4. Check for and delete the auto-created networkwatcherRG if it exists:
   ```
   az group delete --name networkwatcherRG --yes --no-wait
   ```
5. Verify all resource groups are cleaned up:
   ```
   az group list -o table
   ```
   Confirm no resource groups remain (or only unrelated ones).
