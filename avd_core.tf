# AVD Core Control Plane: Workspace, Host Pool, Application Group & Registration Token

# 1. AVD Workspace
resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "ws-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  friendly_name       = "AVD Enterprise Spoke Workspace (${var.environment})"
  description         = "Central AVD Workspace for 2nd Spoke Landing Zone"

  tags = azurerm_resource_group.rg_avd.tags
}

# 2. AVD Host Pool
resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                     = "vdpool-${var.prefix}-${var.environment}"
  location                 = azurerm_resource_group.rg_avd.location
  resource_group_name      = azurerm_resource_group.rg_avd.name
  friendly_name            = "AVD Spoke Host Pool (${var.environment})"
  validate_environment     = false
  custom_rdp_properties    = "audiocodesc:i:0;videocodec:i:1;use multimon:i:1;screencaptureprotection:i:1;redirectclipboard:i:1;redirectprinters:i:0;"
  type                     = var.host_pool_type
  load_balancer_type       = var.load_balancer_type
  maximum_sessions_allowed = var.max_sessions_per_host

  scheduled_agent_updates {
    enabled = true
    schedule {
      day_of_week = "Sunday"
      hour_of_day = 2
    }
  }

  tags = azurerm_resource_group.rg_avd.tags
}

# 3. Host Pool Registration Token (Valid for 24 hours for automated VM joining)
resource "azurerm_virtual_desktop_host_pool_registration_info" "registration_token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "24h")
}

# 4. Desktop Application Group (DAG)
resource "azurerm_virtual_desktop_application_group" "avd_dag" {
  name                = "vdag-desktop-${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  friendly_name       = "Full Desktop Application Group"

  tags = azurerm_resource_group.rg_avd.tags
}

# 5. Associate Application Group with AVD Workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "dag_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_dag.id
}
