data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  name                    = var.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = var.dns_prefix
  tags                    = var.tags
  private_cluster_enabled = var.api_server_access.mode == "private"

  dynamic "api_server_access_profile" {
    for_each = var.api_server_access.mode == "public_restricted" ? [var.api_server_access.authorized_ip_ranges] : []
    content {
      authorized_ip_ranges = api_server_access_profile.value
    }
  }

  default_node_pool {
    name            = var.node_pool_name
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    vnet_subnet_id  = var.aks_subnet_id
    os_disk_size_gb = var.os_disk_size_gb
    max_pods        = var.max_pods
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = var.network_plugin
    network_policy = var.network_policy
    dns_service_ip = var.dns_service_ip
    service_cidr   = var.service_cidr
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = []
  }

  linux_profile {
    admin_username = var.linux_admin_username
    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  node_provisioning_profile {
    mode = "Manual"
  }
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "kube_admin_config_raw" {
  value     = azurerm_kubernetes_cluster.this.kube_admin_config_raw
  sensitive = true
}
