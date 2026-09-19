# FSLogix Profile Management Storage Account & Private Endpoint

resource "random_string" "sa_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Premium File Storage Account for FSLogix Profiles
resource "azurerm_storage_account" "fslogix_sa" {
  name                     = "stfslogix${var.prefix}${random_string.sa_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg_avd.name
  location                 = azurerm_resource_group.rg_avd.location
  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = "ZRS"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  azure_files_authentication {
    directory_type = "AADKERB" # Entra ID Kerberos for Azure Files SMB Access
  }

  tags = azurerm_resource_group.rg_avd.tags
}

# 2. File Share for FSLogix Profile Containers
resource "azurerm_storage_share" "fslogix_profiles_share" {
  name                 = "profiles"
  storage_account_name = azurerm_storage_account.fslogix_sa.name
  quota                = var.fslogix_share_quota_gb
  enabled_protocol     = "SMB"
}

# 3. Private DNS Zone for Azure Files Private Endpoint
resource "azurerm_private_dns_zone" "dns_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_avd.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_file_spoke_link" {
  name                  = "link-file-spoke-vnet"
  resource_group_name   = azurerm_resource_group.rg_avd.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_file.name
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
}

# 4. Private Endpoint for FSLogix Storage
resource "azurerm_private_endpoint" "fslogix_pe" {
  name                = "pe-${azurerm_storage_account.fslogix_sa.name}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  subnet_id           = azurerm_subnet.private_endpoints_subnet.id

  private_service_connection {
    name                           = "psc-fslogix-file"
    private_connection_resource_id = azurerm_storage_account.fslogix_sa.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "pdzgroup-fslogix"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_file.id]
  }

  tags = azurerm_resource_group.rg_avd.tags
}
