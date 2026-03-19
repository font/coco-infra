# coco-infra

Automation scripts for provisioning Confidential Containers (CoCo) infrastructure.

## ARO (Azure Red Hat OpenShift)

End-to-end setup for CoCo on ARO: creates the cluster, installs and configures Trustee (attestation) and OSC (OpenShift Sandboxed Containers) with peer pods.

### Prerequisites

- Azure CLI (`az`) logged in with a service principal that has Contributor + User Access Administrator roles
- Service principal credentials at `~/.azure/osServicePrincipal.json`
- OpenShift pull secret at `~/pull-secret.json`
- `oc`, `skopeo`, `jq`, `podman` installed

### Quick Start

```bash
# Full setup from scratch (~1.5 hours)
cd aro
bash setup.sh

# With custom parameters
RESOURCE_GROUP=my-rg CLUSTER_NAME=my-cluster bash aro/setup.sh

# Skip cluster creation (use existing ARO cluster)
SKIP_CLUSTER=true bash aro/setup.sh

# Teardown
bash aro/teardown.sh
```

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RESOURCE_GROUP` | `coco-rg` | Azure resource group |
| `CLUSTER_NAME` | `coco-kserve` | ARO cluster name |
| `CLUSTER_RESOURCE_GROUP` | `${RESOURCE_GROUP}-managed` | ARO-managed resource group |
| `LOCATION` | `eastus2` | Azure region |
| `WORKER_VM_SIZE` | `Standard_D8s_v5` | Worker node VM size |
| `WORKER_COUNT` | `3` | Number of worker nodes |
| `ARO_VERSION` | `4.19.20` | OpenShift version (must be >= 4.18.30) |
| `SKIP_CLUSTER` | `false` | Skip cluster creation |

### Scripts

| Script | Description |
|--------|-------------|
| `aro/setup.sh` | Full end-to-end setup |
| `aro/create-aro.sh` | Create ARO cluster only |
| `aro/teardown.sh` | Delete cluster and resource group |
| `aro/install-trustee.sh` | Install Trustee + cert-manager operators |
| `aro/configure-trustee.sh` | Configure Trustee with keys, policies, initdata |
| `aro/install-osc.sh` | Install OSC operator |
| `aro/configure-osc.sh` | Configure OSC with peer pods and KataConfig |
