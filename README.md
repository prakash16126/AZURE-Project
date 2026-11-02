# Azure AKS and Self-Healing GitOps

This repository contains Terraform for an Azure Kubernetes Service (AKS) cluster and a sample application configured for Argo CD GitOps.

> **Learning/demo project, not production-ready.** Review API exposure, local admin credentials, VM capacity, workload secrets, ingress/TLS, and policies before using it for anything important.

## Repository layout

- `infra/terraform/` — resource group, VNet/subnet, Log Analytics, and AKS.
- `apps/backend/` — sample Kubernetes application manifests.
- `argocd/` — Argo CD Application definition.
- `monitoring/` — Prometheus ServiceMonitor example.
- `network/` — default-deny network policy example (not included in the Argo CD app path).
- `docs/AKS_PROJECT_GUIDE.md` — setup, deployment, monitoring, troubleshooting, and teardown walkthrough.
- `docs/backend-secret-template.yaml` — non-deployable Secret template; provide real secrets through a secret manager.

Start with the [AKS project guide](docs/AKS_PROJECT_GUIDE.md). It documents prerequisites, Terraform provisioning, connecting with `kubectl`, installing Argo CD and Prometheus/Grafana, and cleanup.

Terraform state, `.tfvars`, key files, and generated provider data are intentionally excluded from Git. Keep the `.terraform.lock.hcl` file under version control.
