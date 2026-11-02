terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "network" {
  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  vnet_name           = var.vnet_name
  address_space       = var.address_space
  aks_subnet_name     = var.aks_subnet_name
  aks_subnet_prefix   = var.aks_subnet_prefix
  tags                = var.tags
}

module "log_analytics" {
  source              = "./modules/log_analytics"
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_in_days
  tags                = var.tags
}

module "aks" {
  source                     = "./modules/aks"
  name                       = var.cluster_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  dns_prefix                 = var.dns_prefix
  node_pool_name             = var.node_pool_name
  node_count                 = var.node_count
  node_vm_size               = var.node_vm_size
  aks_subnet_id              = module.network.aks_subnet_id
  os_disk_size_gb            = var.os_disk_size_gb
  max_pods                   = var.max_pods
  network_plugin             = var.network_plugin
  network_policy             = var.network_policy
  dns_service_ip             = var.dns_service_ip
  service_cidr               = var.service_cidr
  log_analytics_workspace_id = module.log_analytics.workspace_id
  linux_admin_username       = var.linux_admin_username
  ssh_public_key             = trimspace(file(pathexpand(var.ssh_public_key_path)))
  tags                       = var.tags
  api_server_access          = var.api_server_access
}
