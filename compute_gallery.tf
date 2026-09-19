# Simplified Host Pool Image Update System - Azure Compute Gallery (Shared Image Gallery)

# 1. Azure Compute Gallery
resource "azurerm_shared_image_gallery" "avd_gallery" {
  name                = replace("sig${var.prefix}${var.environment}", "-", "")
  resource_group_name = azurerm_resource_group.rg_avd.name
  location            = azurerm_resource_group.rg_avd.location
  description         = "Central Azure Compute Gallery for AVD Golden Image versioning and automated Host Pool updates."

  tags = azurerm_resource_group.rg_avd.tags
}

# 2. Image Definition for Windows 11 Multi-Session Enterprise
resource "azurerm_shared_image" "win11_multisession" {
  name                = "win11-23h2-avd-golden-image"
  gallery_name        = azurerm_shared_image_gallery.avd_gallery.name
  resource_group_name = azurerm_resource_group.rg_avd.name
  location            = azurerm_resource_group.rg_avd.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "win11-23h2-avd-m365"
  }

  tags = azurerm_resource_group.rg_avd.tags
}
