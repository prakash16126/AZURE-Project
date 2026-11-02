# AKS and GitOps Project Guide

This guide documents the Terraform infrastructure under `infra/terraform/` and the application, Argo CD, and monitoring manifests in this repository.

> **Learning/demo setup, not production-ready as currently configured.** The current Terraform default exposes the Kubernetes API publicly to all IPs, local admin credentials are enabled, and the node pool is small. Review the security and sizing sections before deploying workloads.

## What this project provisions

Terraform under `infra/terraform/` creates:

- An Azure resource group (`prakash-aks-rg` by default).
- A virtual network and AKS subnet.
- A Log Analytics workspace.
- An AKS cluster with a system node pool and system-assigned identity.

AKS also creates a managed node resource group containing supporting resources such as the VM scale set and load balancer. Enabling Container Insights can create an Azure Monitor solution associated with the workspace.

The repository root contains sample backend Kubernetes manifests, an Argo CD `Application`, a `ServiceMonitor`, a default-deny network policy, and a production checklist. These are **not** provisioned by Terraform.

## Prerequisites

Use PowerShell on Windows and install:

- Azure CLI
- Terraform
- `kubectl` (the Azure CLI can install it)
- Helm
- Git

Authenticate and select the intended subscription:

```powershell
az login
az account set --subscription "<subscription-id>"
az account show --query "{subscription:id,name:name}" -o table
```

The account needs permission to create resource groups, networks, workspaces, and AKS clusters, and to register Azure resource providers. Register required providers once per subscription; wait for each to report `Registered`:

```powershell
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement
az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv
```

If Azure CLI reports it cannot resolve `management.azure.com`, fix local DNS/VPN/proxy connectivity before retrying. Do not assume a registration request succeeded unless `az provider show` confirms it.

## Configure Terraform safely

1. Generate or choose an SSH key pair. AKS needs the **public** key data; keep the private key private:

   ```powershell
   ssh-keygen -t rsa -b 4096 -f "$HOME\.ssh\aks-terraform"
   ssh-keygen -lf "$HOME\.ssh\aks-terraform.pub"
   ```

2. Change to the Terraform root and create a local `terraform.tfvars` file. `.tfvars` files are ignored by this project's `.gitignore`; do not commit secrets or key material.

   ```powershell
   Set-Location .\infra\terraform
   ```

   ```hcl
   resource_group_name = "prakash-aks-rg"
   location            = "eastus"
   node_count          = 2
   node_vm_size        = "Standard_F2als_v7"
   ssh_public_key_path = "~/.ssh/aks-terraform.pub"

   # Prefer restricting access to your actual public egress IP.
   # Replace the example with your public IP in CIDR form, e.g. "203.0.113.10/32".
   api_server_access = {
     mode                 = "public_restricted"
     authorized_ip_ranges = ["<your-public-ip>/32"]
   }
   ```

   The current Terraform default for `api_server_access` is `public_open_demo`. Override it as above for a restricted public API, or configure a private cluster only when you have the required VNet/VPN connectivity. A private subnet address such as `10.240.0.0/24` is **not** your public client IP.

3. Check that the selected VM SKU is available in the chosen region and that subscription quota is sufficient. Run these checks from any directory. Quota and SKU availability vary by region and subscription:

   ```powershell
   az vm list-skus --location eastus --size Standard_F2als_v7 --all --output table
   az vm list-usage --location eastus --output table
   ```

   The current `Standard_F2als_v7` is a 2-vCPU, 4-GiB node. Two nodes provide limited capacity for AKS system services, Azure Monitor, Argo CD, Prometheus/Grafana, and an application. Probe failures across multiple services have already occurred in this setup. For a monitoring/GitOps learning cluster, consider at least two 4-vCPU, 16-GiB nodes if that SKU is available and quota/cost permit; verify the exact SKU and quota before changing Terraform. A larger pool costs more and may need quota approval.

4. From `infra/terraform`, validate and review the plan before creating anything:

   ```powershell
   terraform init
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

   Confirm region, resource group, VM size, node count, SSH key path, API access, and all create/update/destroy actions. Do not approve a plan that unexpectedly replaces or destroys resources.

5. Apply only after reviewing the plan:

   ```powershell
   terraform apply
   ```

   Review Terraform's plan again and type `yes` to approve. Avoid `-auto-approve` while learning or when a plan contains destructive changes.

Keep `terraform.tfstate`, state backups, kubeconfig files, and private SSH keys out of Git. The provider lock file `infra/terraform/.terraform.lock.hcl` should be committed so collaborators use the selected provider version consistently.

## Connect to AKS

Install `kubectl` if needed and fetch credentials:

```powershell
az aks install-cli
az aks get-credentials --resource-group prakash-aks-rg --name aks-cluster --admin --overwrite-existing
kubectl config current-context
kubectl get nodes
```

This cluster currently has no Entra admin group configured and local admin credentials are enabled, so the example uses `--admin`. These credentials are highly privileged; protect `%USERPROFILE%\.kube\config`. For a shared or production cluster, configure Entra group/Azure RBAC access and disable local accounts as appropriate instead of distributing admin kubeconfigs.

Check stability before installing more workloads:

```powershell
kubectl get nodes
kubectl top nodes
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp | Select-Object -Last 30
```

If several unrelated pods fail probes, or a node reports container-runtime, DNS, memory, or disk problems, resolve node health/capacity first.

## Install Helm on Windows

Install Helm on your workstation; Helm is a client that talks to AKS through kubeconfig, not software installed on AKS nodes:

```powershell
winget install Helm.Helm
```

Open a **new PowerShell window** after installation so the updated `PATH` is loaded:

```powershell
helm version
kubectl get nodes
```

## Install Argo CD

```powershell
helm repo add argo-cd https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd
helm upgrade --install argocd argo-cd/argo-cd --namespace argocd
kubectl get pods,services -n argocd
kubectl wait --for=condition=Available deployments --all -n argocd --timeout=10m
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=10m
```

The namespace may already exist; that `AlreadyExists` message is harmless. Wait for pods to become ready before using Argo CD.

For local UI access, avoid exposing the Argo CD service publicly:

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Keep the command running and browse to `https://localhost:8080`. Retrieve the initial admin password from the `argocd-initial-admin-secret` Secret locally; never paste it into chat or commit it. Change the initial password after the first login.

## Deploy the sample app with GitOps

The Argo CD application manifest is `self-healing-gitops-project/argocd/application.yaml`. It currently points at:

```text
https://github.com/prakash16126/self-healing-app.git
```

Before creating the Argo CD Application:

1. Push the intended manifests to a Git repository Argo CD can access.
2. Verify `repoURL`, `targetRevision`, and `path` in `argocd/application.yaml` match this repository. The configured path is `apps/backend`.
3. **Configure secrets before deploying the backend.** The non-deployable example is in `docs/backend-secret-template.yaml`; it is outside Argo CD's sync path. Do not commit real credentials. Use an approved secret manager (for example Azure Key Vault with an External Secrets integration) or another secure delivery method; the production checklist currently marks External Secrets as incomplete.
4. Review the app's public `LoadBalancer` Service (`service.yaml`) for exposure and Azure cost. Prefer private ingress or a controlled ingress with TLS/access restrictions where appropriate.
5. The `network/networkpolicy.yaml` is outside the Argo CD app path and applies default-deny ingress **and egress** in `production`. Do not apply it until needed allow rules (including DNS and app dependencies) are defined and tested.

Then create the Application:

```powershell
kubectl apply -f .\argocd\application.yaml
kubectl get applications -n argocd
kubectl get pods,services -n production
```

The manifest enables automated sync, pruning, and self-healing. Git becomes the source of truth: manual changes to managed objects can be reverted by Argo CD, and objects removed from Git may be pruned.

## Install Prometheus and Grafana

Install the community `kube-prometheus-stack` only after the nodes are stable and have adequate resources. It deploys Prometheus, Grafana, Alertmanager, and exporters; this increases CPU, memory, storage, and cost.

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring --create-namespace
kubectl get pods -n monitoring -w
```

Use `Ctrl+C` to stop watching. Check readiness and resource use:

```powershell
kubectl get pods -n monitoring -o wide
kubectl top nodes
kubectl top pods -n monitoring --containers
kubectl get events -n monitoring --sort-by=.lastTimestamp | Select-Object -Last 30
```

For local Grafana access, port-forward instead of changing its Service to `LoadBalancer`:

```powershell
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Keep the process running and browse to `http://localhost:3000`. The initial username is usually `admin`; retrieve the password from the `monitoring-grafana` Secret without sharing it. A port-forward error such as `connection refused` with an empty Service endpoint means the Grafana pod is not Ready; inspect the pod's Grafana-container logs and events rather than exposing the Service.

This cluster has previously shown Grafana, Prometheus, Alertmanager, and other workloads failing probes together, plus one node briefly reporting container-runtime and DNS faults. Increasing node size/capacity may help resource contention, but it does not fix a runtime/network issue by itself. Check all nodes and system pods before trying monitoring again.

The sample `monitoring/servicemonitor.yaml` is not included in the Argo CD application's `apps/backend` path. Before applying it, ensure its Service selector matches labels on the backend Service and that its metadata labels/namespace are selected by the Prometheus release.

## Common failures and safe recovery

- **Missing subscription registration:** register the named Azure provider namespace with Azure CLI, then verify its state is `Registered`.
- **VM size/quota rejection:** compare node count × vCPUs per VM with regional quota, and verify SKU availability in the actual region. Old errors for `canadacentral` do not establish quota in `eastus`.
- **Invalid SSH key:** Terraform must read the contents of a valid OpenSSH `.pub` file. Never pass a filename or private key as `key_data`.
- **Azure resource exists but Terraform says create:** an apply may have succeeded in Azure but failed before writing state. Check Azure and `terraform state list`; import the exact existing resource only after verifying it is the intended resource. Review the plan before applying.
- **Subnet/provider inconsistent result:** verify whether Azure created the subnet. If it exists but is missing from state, import it, then plan. Do not repeatedly apply against an existing untracked resource.
- **AKS provisioning failed:** inspect `az aks show` and Azure Activity Log. Reconcile only when appropriate; do not blindly import or recreate a failed cluster.
- **Grafana port-forward disconnects:** confirm its pod is Ready and its Service has endpoints. A local forward cannot work while the container is restarting or not listening.

## Destroy the deployment

For a normal Terraform-managed teardown:

```powershell
# From the repository root:
Set-Location .\infra\terraform
terraform plan -destroy
terraform destroy
```

Review the full destroy plan and confirm interactively. Some Azure-created resources, such as a Container Insights solution, may not be represented as standalone Terraform resources and can block Terraform's resource-group deletion safeguard.

If the entire resource group is disposable and Terraform cannot delete it because of such leftovers, deleting the resource group directly is a broader, destructive alternative:

```powershell
az account show --query id -o tsv
az group delete --name prakash-aks-rg --yes --no-wait
az group exists --name prakash-aks-rg
```

Wait until `az group exists` returns `false`. AKS also creates a separate managed node resource group (for example, `MC_prakash-aks-rg_aks-cluster_eastus`). Check whether it remains after the main group deletion; delete it separately only if it is confirmed to be an orphan and contains nothing to retain.

After manual deletion, Terraform state is stale. Do not immediately apply. Inspect Azure and run `terraform plan`; if this workspace is intentionally being retired, archive/remove local state securely only after confirming the resources are gone and that no other deployment depends on it.
