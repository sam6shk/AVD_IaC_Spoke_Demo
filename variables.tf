# Environment & Region Variables
variable "location" {
  type        = string
  description = "Azure region where the AVD Spoke resources will be deployed."
  default     = "eastus2"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources created in this AVD Spoke deployment."
  default     = "avd-spk"
}

variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., dev, prod, staging)."
  default     = "prod"
}

# Hub-and-Spoke Integration Variables
variable "hub_vnet_name" {
  type        = string
  description = "Name of the existing Hub Virtual Network."
}

variable "hub_vnet_id" {
  type        = string
  description = "Resource ID of the existing Hub Virtual Network for VNet peering."
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource Group name where the existing Hub VNet resides."
}

variable "hub_nva_firewall_ip" {
  type        = string
  description = "Private IP address of the Hub Azure Firewall or NVA for routing 0.0.0.0/0 traffic."
  default     = "10.1.0.4"
}

# AVD Spoke Network Variables
variable "spoke_vnet_address_space" {
  type        = list(string)
  description = "Address CIDR block for the new AVD Spoke VNet."
  default     = ["10.2.0.0/16"]
}

variable "session_hosts_subnet_prefix" {
  type        = list(string)
  description = "Subnet CIDR for AVD Session Hosts."
  default     = ["10.2.1.0/24"]
}

variable "private_endpoints_subnet_prefix" {
  type        = list(string)
  description = "Subnet CIDR for Storage Private Endpoints (FSLogix & App Attach)."
  default     = ["10.2.2.0/24"]
}

# AVD Host Pool & Workspaces
variable "host_pool_type" {
  type        = string
  description = "Host pool load balancing strategy type (Pooled or Personal)."
  default     = "Pooled"
}

variable "load_balancer_type" {
  type        = string
  description = "Load balancing algorithm for Pooled host pool (BreadthFirst or DepthFirst)."
  default     = "BreadthFirst"
}

variable "max_sessions_per_host" {
  type        = number
  description = "Maximum user sessions per host."
  default     = 10
}

# Session Host Virtual Machine Sizing & Auth
variable "session_host_count" {
  type        = number
  description = "Number of AVD Session Host VMs to deploy."
  default     = 2
}

variable "vm_size" {
  type        = string
  description = "Azure VM Size for session hosts (e.g., Standard_D4ds_v5)."
  default     = "Standard_D4ds_v5"
}

variable "local_admin_username" {
  type        = string
  description = "Local administrator username for session host VMs."
  default     = "avdadmin"
}

variable "local_admin_password" {
  type        = string
  description = "Local administrator password for session host VMs."
  sensitive   = true
}

# Image Management / Azure Compute Gallery (SIG)
variable "use_custom_gallery_image" {
  type        = bool
  description = "Set to true to use a custom image version from Azure Compute Gallery; false for Marketplace image."
  default     = false
}

variable "custom_image_version_id" {
  type        = string
  description = "Resource ID of the custom image version from Azure Compute Gallery (if use_custom_gallery_image is true)."
  default     = ""
}

# FSLogix & App Attach Storage
variable "fslogix_share_quota_gb" {
  type        = number
  description = "Quota in GB for FSLogix Profiles File Share."
  default     = 100
}

variable "appattach_share_quota_gb" {
  type        = number
  description = "Quota in GB for App Attach MSIX packages File Share."
  default     = 200
}
