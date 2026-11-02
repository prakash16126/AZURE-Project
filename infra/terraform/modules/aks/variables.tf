variable "name" {
  description = "AKS cluster name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name for AKS"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the default node pool"
  type        = string
  default     = "default"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_F4ams_v7"
}

variable "aks_subnet_id" {
  description = "Subnet id to attach AKS nodes to"
  type        = string
}

variable "os_disk_size_gb" {
  description = "OS disk size for nodes (GB)"
  type        = number
  default     = 30
}

variable "max_pods" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 110
}

variable "network_plugin" {
  description = "Network plugin for AKS"
  type        = string
  default     = "azure"
}

variable "network_policy" {
  description = "Network policy for AKS"
  type        = string
  default     = "azure"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP"
  type        = string
  default     = "10.0.0.10"
}

variable "service_cidr" {
  description = "Service CIDR for the cluster"
  type        = string
  default     = "10.0.0.0/16"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace id to connect OMS addon"
  type        = string
}

variable "linux_admin_username" {
  description = "Admin username for linux nodes"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for linux_profile"
  type        = string
}

variable "tags" {
  description = "Tags applied to the AKS cluster"
  type        = map(string)
}

variable "api_server_access" {
  description = "Kubernetes API endpoint access mode and optional allowed public IP ranges"
  type = object({
    mode                 = string
    authorized_ip_ranges = list(string)
  })
}
