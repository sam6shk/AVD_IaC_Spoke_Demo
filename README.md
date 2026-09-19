# Azure Virtual Desktop (AVD) 2nd Spoke Landing Zone

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?style=flat&logo=terraform)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-AVD%20Landing%20Zone-0089D6?style=flat&logo=microsoftazure)](https://azure.microsoft.com/)
[![FSLogix](https://img.shields.io/badge/FSLogix-Profile%20Containers-0078D4)](https://learn.microsoft.com/en-us/fslogix/)
[![App Attach](https://img.shields.io/badge/MSIX-App%20Attach-00A4EF)](https://learn.microsoft.com/en-us/azure/virtual-desktop/app-attach-overview)

Production-ready Terraform implementation for deploying an **Azure Virtual Desktop (AVD) 2nd Spoke Landing Zone** integrated into an existing Enterprise Hub-and-Spoke topology.

This architecture includes **FSLogix Profile Containers**, **MSIX App Attach** for application delivery, and an **Azure Compute Gallery (Shared Image Gallery)** for simplified image updates.

---

## 🏛️ High-Level Architecture (HLD)

```mermaid
graph TD
    subgraph Existing_Hub ["Existing Hub Landing Zone VNet"]
        HubVNet["Hub Virtual Network"]
        Firewall["Azure Firewall / NVA (0.0.0.0/0)"]
    end

    subgraph AVD_Spoke ["AVD 2nd Spoke VNet (10.2.0.0/16)"]
        SpokeVNet["AVD Spoke VNet"]
        
        subgraph Subnet_Hosts ["Session Host Subnet (snet-avd-session-hosts)"]
            SH01["AVD Session Host 01"]
            SH02["AVD Session Host 02"]
            NSG_UDR["NSG + UDR Route Table"]
        end

        subgraph Subnet_PE ["Private Endpoint Subnet (snet-avd-private-endpoints)"]
            PE_FSLogix["FSLogix Private Endpoint"]
            PE_AppAttach["App Attach Private Endpoint"]
        end

        subgraph Image_System ["Image Lifecycle Management"]
            ACG["Azure Compute Gallery (SIG)"]
            ImgDef["Win11 23H2 Multi-Session Image Def"]
        end
    end

    subgraph Storage_Layer ["Azure Storage Services"]
        ST_FSLogix["Azure Files (Premium FileStorage)<br/>Share: profiles"]
        ST_AppAttach["Azure Files (StorageV2)<br/>Share: appattach-packages"]
    end

    subgraph AVD_Control ["AVD Control Plane"]
        Workspace["AVD Workspace"]
        HostPool["AVD Host Pool (Pooled / BreadthFirst)"]
        DAG["Desktop Application Group"]
    end

    SpokeVNet <-->|"VNet Peering"| HubVNet
    SH01 -->|"0.0.0.0/0 UDR"| Firewall
    SH01 -->|"SMB Profiles"| PE_FSLogix --> ST_FSLogix
    SH01 -->|"MSIX App Attach Mount"| PE_AppAttach --> ST_AppAttach
    ImgDef -.->|"Provisioning Reference"| SH01
    HostPool --> SH01
    HostPool --> SH02
    DAG --> HostPool
    Workspace --> DAG
```

---

## ✨ Key Architectural Features

### 1. Hub-and-Spoke Network Integration
- **Isolated AVD Spoke VNet**: `10.2.0.0/16` with dedicated subnets for Session Hosts (`10.2.1.0/24`) and Storage Private Endpoints (`10.2.2.0/24`).
- **Bi-directional VNet Peering**: Directly peers with the existing Hub VNet (`remote_virtual_network_id`).
- **Centralized Security Routing**: User Defined Route (UDR) forces all outbound `0.0.0.0/0` traffic through the Hub Azure Firewall / NVA.

### 2. Simplified Host Pool Image Update System (Azure Compute Gallery)
- Centralized image management using **Azure Compute Gallery (Shared Image Gallery)**.
- **Zero-Downtime Image Rollout Procedure**:
  1. Build a new image version in the Azure Compute Gallery (`win11-23h2-avd-golden-image`).
  2. Set `use_custom_gallery_image = true` and update `custom_image_version_id` in `terraform.tfvars`.
  3. Enable Drain Mode on existing hosts, deploy new hosts from the new image version, and gracefully decommission old hosts.

### 3. Profile Management with FSLogix
- **High-Performance Storage**: Premium FileStorage Account with File Share (`profiles`) accessed securely over **Private Endpoint** (`privatelink.file.core.windows.net`).
- **Automated Host Configuration**: Session Hosts automatically provisioned with FSLogix registry keys via Custom Script Extension (`Enabled=1`, `VHDLocations`, `FlipFlopProfileDirectoryName=1`).

### 4. Dynamic Application Delivery with MSIX App Attach
- Dedicated File Share (`appattach-packages`) backed by Private Endpoint for storing application `.vhdx` / `.cim` containers.
- Decouples applications from the core OS image, accelerating patch management and reducing image maintenance overhead.

---

## 📂 Repository Structure

```text
AVD-LandingZone/
├── providers.tf            # Provider configuration (azurerm, azuread, random)
├── variables.tf            # Input variable declarations & defaults
├── terraform.tfvars.example# Sample deployment configuration template
├── network.tf              # Spoke VNet, Subnets, UDR, NSG & Hub VNet Peering
├── compute_gallery.tf      # Azure Compute Gallery & Image Definition
├── storage_fslogix.tf      # FSLogix Storage Account, Share, PE & Private DNS
├── storage_appattach.tf    # App Attach Storage Account, Share & PE
├── avd_core.tf             # Workspace, Host Pool, App Group & Reg Token
├── avd_session_hosts.tf    # VMs, Entra ID Join, AVD DSC Agent & FSLogix script
├── outputs.tf              # Deployment output IDs, UNC paths, and IP addresses
└── README.md               # Architecture documentation & execution guide
```

---

## 📋 Prerequisites

Before deploying this solution, ensure you have:

1. **Terraform CLI**: `>= 1.5.0` installed.
2. **Azure CLI**: `az login` executed with an active Azure subscription context.
3. **Azure RBAC Permissions**: `Contributor` and `User Access Administrator` on the target subscription/resource groups.
4. **Existing Hub Landing Zone Details**:
   - Hub Virtual Network Name & Resource Group
   - Hub Virtual Network Resource ID
   - Hub NVA / Firewall Private IP (for default routing)

---

## 🚀 Deployment Guide

### Step 1: Clone Repository & Create Configuration File
```bash
git clone <repository-url>
cd AVD-LandingZone
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Edit `terraform.tfvars`
Update `terraform.tfvars` with your target environment parameters:

```hcl
location                = "eastus2"
prefix                  = "avd-spk"
environment             = "prod"

# Reference to your existing Hub VNet
hub_vnet_name           = "vnet-hub-prod-eastus2"
hub_vnet_id             = "/subscriptions/<SUB_ID>/resourceGroups/rg-hub-network-prod/providers/Microsoft.Network/virtualNetworks/vnet-hub-prod-eastus2"
hub_resource_group_name = "rg-hub-network-prod"
hub_nva_firewall_ip     = "10.1.0.4"

# AVD Spoke Subnets
spoke_vnet_address_space         = ["10.2.0.0/16"]
session_hosts_subnet_prefix      = ["10.2.1.0/24"]
private_endpoints_subnet_prefix = ["10.2.2.0/24"]

# Host Pool & Session Hosts
session_host_count    = 2
vm_size               = "Standard_D4ds_v5"
local_admin_username  = "avdadmin"
local_admin_password  = "YourSecurePassword123!"
```

### Step 3: Initialize & Validate Terraform
```bash
terraform init
terraform validate
```

### Step 4: Preview Infrastructure Plan
```bash
terraform plan -out=tfplan
```

### Step 5: Deploy Infrastructure
```bash
terraform apply tfplan
```

---

## 🔄 Post-Deployment Operations

### Updating Host Pool Image via Azure Compute Gallery

To rollout a new golden image version:
1. Publish the new version to the Azure Compute Gallery (`win11-23h2-avd-golden-image`).
2. Update `terraform.tfvars`:
   ```hcl
   use_custom_gallery_image = true
   custom_image_version_id  = "/subscriptions/<SUB_ID>/resourceGroups/rg-avd-spk-prod-eastus2/providers/Microsoft.Compute/galleries/sigavdspkprod/images/win11-23h2-avd-golden-image/versions/1.0.1"
   ```
3. Run `terraform apply`.

### Configuring MSIX App Attach Packages
1. Upload `.vhdx` / `.cim` application packages to the UNC Share:
   `\\<stappattach_name>.file.core.windows.net\appattach-packages`
2. Register the MSIX Package in Azure Portal under **Azure Virtual Desktop -> App Attach packages**.
3. Assign the package to the Application Group (`vdag-desktop-avd-spk-prod`).

---

## 🛡️ Security & Compliance

- **No Public Endpoints**: Storage Accounts enforce `public_network_access_enabled = false` and rely strictly on Private Endpoints.
- **Traffic Inspection**: Forced tunneling (`0.0.0.0/0`) sends all egress traffic to the Hub NVA/Firewall.
- **Identity & Access**: Session hosts support Entra ID Join (`AADLoginForWindows`) and Entra ID Kerberos SMB authentication for FSLogix file shares.

---

## 📄 License
Internal Infrastructure as Code Template - Designed for Enterprise Landing Zone Integration.
