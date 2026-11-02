variable "resource_group_name" {
  description = "Resource group name to create/use for this deployment"
  type        = string
  default     = "prakash-aks-rg"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  type    = string
  default = "aks-vnet"
}

variable "address_space" {
  type    = list(string)
  default = ["10.240.0.0/16"]
}

variable "aks_subnet_name" {
  type    = string
  default = "aks-subnet"
}

variable "aks_subnet_prefix" {
  type    = string
  default = "10.240.0.0/20"
}

variable "log_analytics_name" {
  type    = string
  default = "la-aks-demo"
}

variable "log_analytics_sku" {
  type    = string
  default = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  type    = string
  default = "aks-cluster"
}

variable "dns_prefix" {
  type    = string
  default = "aksdemo"
}

variable "node_pool_name" {
  type    = string
  default = "agentpool"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_vm_size" {
  type    = string
  default = "Standard_F2ams_v7"
}

variable "os_disk_size_gb" {
  type    = number
  default = 30
}

variable "max_pods" {
  type    = number
  default = 110
}

variable "network_plugin" {
  type    = string
  default = "azure"
}

variable "network_policy" {
  type    = string
  default = "azure"
}

variable "dns_service_ip" {
  type    = string
  default = "10.0.0.10"
}

variable "service_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "linux_admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Local path to a valid OpenSSH public key file (.pub); never use the private key"
  type        = string
  default     = "~/.ssh/aks-terraform.pub"
}

variable "api_server_access" {
  description = "Kubernetes API endpoint access mode and optional allowed public IP ranges"
  type = object({
    mode                 = string
    authorized_ip_ranges = list(string)
  })
  default = {
    mode                 = "public_open_demo"
    authorized_ip_ranges = []
  }

  validation {
    condition = contains(
      ["public_restricted", "public_open_demo", "private"],
      var.api_server_access.mode
      ) && (
      var.api_server_access.mode == "public_restricted"
      ? length(var.api_server_access.authorized_ip_ranges) > 0
      : length(var.api_server_access.authorized_ip_ranges) == 0
    )
    error_message = "Use public_restricted with at least one public CIDR, or public_open_demo/private with no CIDRs."
  }
}
