resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "workspace_primary_shared_key" {
  value     = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive = true
}
