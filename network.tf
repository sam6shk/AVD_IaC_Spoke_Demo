# Resource Group for AVD Spoke Landing Zone
resource "azurerm_resource_group" "rg_avd" {
  name     = "rg-${var.prefix}-${var.environment}-${var.location}"
  location = var.location

  tags = {
    Environment = var.environment
    Workload    = "AVD-Spoke-LandingZone"
    ManagedBy   = "Terraform"
  }
}

# AVD Spoke Virtual Network
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-${var.prefix}-${var.environment}-${var.location}"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name
  address_space       = var.spoke_vnet_address_space

  tags = azurerm_resource_group.rg_avd.tags
}

# Subnet 1: AVD Session Hosts
resource "azurerm_subnet" "session_hosts_subnet" {
  name                 = "snet-avd-session-hosts"
  resource_group_name  = azurerm_resource_group.rg_avd.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = var.session_hosts_subnet_prefix
}

# Subnet 2: Private Endpoints (FSLogix & App Attach Storage)
resource "azurerm_subnet" "private_endpoints_subnet" {
  name                 = "snet-avd-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg_avd.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = var.private_endpoints_subnet_prefix
}

# Route Table (UDR) - Force all outbound 0.0.0.0/0 traffic through Hub NVA / Firewall
resource "azurerm_route_table" "spoke_udr" {
  name                          = "rt-${var.prefix}-${var.environment}"
  location                      = azurerm_resource_group.rg_avd.location
  resource_group_name           = azurerm_resource_group.rg_avd.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "route-to-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.hub_nva_firewall_ip
  }

  tags = azurerm_resource_group.rg_avd.tags
}

resource "azurerm_subnet_route_table_association" "session_hosts_udr_assoc" {
  subnet_id      = azurerm_subnet.session_hosts_subnet.id
  route_table_id = azurerm_route_table.spoke_udr.id
}

# Network Security Group (NSG) for Session Hosts Subnet
resource "azurerm_network_security_group" "session_hosts_nsg" {
  name                = "nsg-${var.prefix}-session-hosts"
  location            = azurerm_resource_group.rg_avd.location
  resource_group_name = azurerm_resource_group.rg_avd.name

  # Allow inbound RDP for management (restrict source IP in production)
  security_rule {
    name                       = "Allow-RDP-Management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow Outbound HTTPS to AVD Control Plane & Azure Services
  security_rule {
    name                       = "Allow-AVD-ControlPlane-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "WindowsVirtualDesktop"
  }

  security_rule {
    name                       = "Allow-AzureKMS-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1688"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = azurerm_resource_group.rg_avd.tags
}

resource "azurerm_subnet_network_security_group_association" "session_hosts_nsg_assoc" {
  subnet_id                 = azurerm_subnet.session_hosts_subnet.id
  network_security_group_id = azurerm_network_security_group.session_hosts_nsg.id
}

# Bi-directional VNet Peering: AVD Spoke VNet <--> Existing Hub VNet
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.prefix}-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.rg_avd.name
  virtual_network_name         = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.prefix}-spoke"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
