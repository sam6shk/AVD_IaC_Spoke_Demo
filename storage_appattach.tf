# App Attach Application Delivery Storage Account & Private Endpoint

# 1. Storage Account for MSIX App Attach Packages (.vhdx / .cim files)
resource "azurerm_storage_account" "appattach_sa" {
  name                     = "stappattach${var.prefix}${random_string.sa_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg_avd.name
  location                 = azurerm_resource_group.rg_avd.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "ZRS"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  azure_files_authentication {
    directory_type = "AADKERB"
  }

  tags = azurerm_resource_group.rg_avd.tags
}

# 2. File Share for Storing App Attach Packages
resource "azurerm_storage_share" "appattach_share" {
  name                 = "appattach-packages"
  storage_account_name = azurerm_storage_account.appattach_sa.name
  quota                = var.appattach_share_quota_gb
  enabled_protocol     = "SMB"
}

# 3. Private Endpoint for App Attach Storage
resource "azurerm_private_endpoint" "appattach_pe" {
  name                = "pe-${azurerm_storage_account.appattach_sa.name}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  subnet_id           = azurerm_subnet.private_endpoints_subnet.id

  private_service_connection {
    name                           = "psc-appattach-file"
    private_connection_resource_id = azurerm_storage_account.appattach_sa.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "pdzgroup-appattach"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_file.id]
  }

  tags = azurerm_resource_group.rg_avd.tags
}
