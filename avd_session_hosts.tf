# Session Host Network Interfaces & Virtual Machines

resource "azurerm_network_interface" "sh_nic" {
  count               = var.session_host_count
  name                = "nic-${var.prefix}-sh-${count.index + 1}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.session_hosts_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = azurerm_resource_group.rg_avd.tags
}

# AVD Session Host Virtual Machines
resource "azurerm_windows_virtual_machine" "session_host" {
  count               = var.session_host_count
  name                = "vm${var.prefix}sh${count.index + 1}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  size                = var.vm_size
  admin_username      = var.local_admin_username
  admin_password      = var.local_admin_password
  network_interface_ids = [
    azurerm_network_interface.sh_nic[count.index].id
  ]

  os_disk {
    name                 = "osdisk-${var.prefix}-sh-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Simplified Host Pool Image Update: Reference Azure Compute Gallery Custom Image OR Marketplace
  dynamic "source_image_reference" {
    for_each = var.use_custom_gallery_image ? [] : [1]
    content {
      publisher = "MicrosoftWindowsDesktop"
      offer     = "office-365"
      sku       = "win11-23h2-avd-m365"
      version   = "latest"
    }
  }

  source_image_id = var.use_custom_gallery_image ? var.custom_image_version_id : null

  identity {
    type = "SystemAssigned"
  }

  tags = azurerm_resource_group.rg_avd.tags
}

# Extension 1: Entra ID Join Extension for Session Hosts
resource "azurerm_virtual_machine_extension" "entra_id_join" {
  count                      = var.session_host_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Extension 2: AVD Agent & Host Pool Registration Extension
resource "azurerm_virtual_machine_extension" "avd_ds_agent" {
  count                      = var.session_host_count
  name                       = "RegisterAVDAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.471.zip",
        "configurationFunction": "Configuration.ps1\\AddSessionHost",
        "properties": {
            "hostPoolName": "${azurerm_virtual_desktop_host_pool.avd_host_pool.name}",
            "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.registration_token.token}"
        }
    }
SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.entra_id_join
  ]
}

# Extension 3: FSLogix Automated Registry Configuration via Custom Script
resource "azurerm_virtual_machine_extension" "fslogix_config" {
  count                      = var.session_host_count
  name                       = "ConfigureFSLogixProfiles"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"New-Item -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Force | Out-Null; New-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'Enabled' -Value 1 -PropertyType DWORD -Force; New-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'VHDLocations' -Value '\\\\${azurerm_storage_account.fslogix_sa.name}.file.core.windows.net\\profiles' -PropertyType MultiString -Force; New-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'FlipFlopProfileDirectoryName' -Value 1 -PropertyType DWORD -Force; New-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name 'SizeInMB' -Value 30000 -PropertyType DWORD -Force;\""
    }
SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.avd_ds_agent
  ]
}
