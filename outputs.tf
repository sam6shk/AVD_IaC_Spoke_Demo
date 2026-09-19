output "spoke_resource_group_name" {
  description = "Resource group name for AVD Spoke deployment."
  value       = azurerm_resource_group.rg_avd.name
}

output "spoke_vnet_id" {
  description = "Resource ID of the AVD Spoke Virtual Network."
  value       = azurerm_virtual_network.spoke_vnet.id
}

output "spoke_vnet_name" {
  description = "Name of the AVD Spoke Virtual Network."
  value       = azurerm_virtual_network.spoke_vnet.name
}

output "avd_workspace_id" {
  description = "Resource ID of the AVD Workspace."
  value       = azurerm_virtual_desktop_workspace.avd_workspace.id
}

output "avd_host_pool_name" {
  description = "Name of the created AVD Host Pool."
  value       = azurerm_virtual_desktop_host_pool.avd_host_pool.name
}

output "fslogix_storage_account_name" {
  description = "Name of the Storage Account used for FSLogix Profiles."
  value       = azurerm_storage_account.fslogix_sa.name
}

output "fslogix_share_unc_path" {
  description = "UNC Path to FSLogix Profiles File Share."
  value       = "\\\\${azurerm_storage_account.fslogix_sa.name}.file.core.windows.net\\profiles"
}

output "appattach_storage_account_name" {
  description = "Name of the Storage Account used for App Attach packages."
  value       = azurerm_storage_account.appattach_sa.name
}

output "appattach_share_unc_path" {
  description = "UNC Path to MSIX App Attach Package File Share."
  value       = "\\\\${azurerm_storage_account.appattach_sa.name}.file.core.windows.net\\appattach-packages"
}

output "azure_compute_gallery_id" {
  description = "Resource ID of the Azure Compute Gallery for image lifecycle management."
  value       = azurerm_shared_image_gallery.avd_gallery.id
}

output "session_host_private_ips" {
  description = "Private IP addresses of deployed session host VMs."
  value       = azurerm_network_interface.sh_nic[*].private_ip_address
}
