output "aks_cluster_id" {
  description = "AKS cluster resource id"
  value       = module.aks.aks_cluster_id
}

output "kube_admin_config_raw" {
  description = "Raw kubeadmin config (sensitive)"
  value       = module.aks.kube_admin_config_raw
  sensitive   = true
}

output "vnet_id" {
  description = "VNet id created by the network module"
  value       = module.network.vnet_id
}

