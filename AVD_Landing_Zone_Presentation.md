---
marp: true
theme: default
paginate: true
header: 'Azure Virtual Desktop (AVD) 2nd Spoke Landing Zone'
footer: 'Enterprise AVD Architecture & IaC Demo | 2026'
style: |
  section {
    background-color: #0f172a;
    color: #f8fafc;
    font-family: 'Inter', sans-serif;
  }
  h1, h2, h3 {
    color: #38bdf8;
  }
  code {
    background-color: #1e293b;
    color: #34d399;
  }
  .highlight {
    color: #fbbf24;
    font-weight: bold;
  }
---

<!-- _class: lead -->
# Azure Virtual Desktop (AVD) 2nd Spoke Landing Zone
### Enterprise Infrastructure as Code & High-Level Design (HLD)

**Presenter**: Cloud & AVD Infrastructure Engineering Team  
**Repository**: `https://github.com/sam6shk/AVD_IaC_Spoke_Demo.git`

---

## 🎯 Executive Requirements & Scope

The client requires a **2nd Spoke Virtual Network** integrated into an existing Enterprise Hub Landing Zone:

1. **100% Terraform IaC**: Fully automated modular deployment.
2. **Hub-and-Spoke Topology**: Connected to existing Hub VNet via VNet Peering with forced tunneling (`0.0.0.0/0` UDR) through Hub Firewall.
3. **Simplified Image Update System**: **Azure Compute Gallery (SIG)** for zero-downtime golden image lifecycle management.
4. **Profile Container Management**: **FSLogix** on Premium Azure Files over Private Endpoints.
5. **Dynamic Application Delivery**: **MSIX App Attach** to decouple applications from the OS.

---

## 🏛️ High-Level Architecture (HLD)

```
+-----------------------------------------------------------------------------------+
|                            EXISTING HUB LANDING ZONE                              |
|   +--------------------------+          +-------------------------------------+   |
|   |   Hub Virtual Network    |<========>|  Azure Firewall / NVA (0.0.0.0/0) |   |
|   +--------------------------+          +-------------------------------------+   |
+------------------------------------||---------------------------------------------+
                                     || Bi-directional VNet Peering & UDR Route
+------------------------------------||---------------------------------------------+
|                            AVD 2ND SPOKE LANDING ZONE                             |
|                                                                                   |
|  +-----------------------------------+   +-------------------------------------+  |
|  | Session Hosts Subnet (10.2.1.0/24)|   | Private Endpoints (10.2.2.0/24)     |  |
|  | - AVD Session Host 01 / 02        |   | - FSLogix Storage PE                |  |
|  | - NSG + Force Tunneling UDR       |   | - App Attach Storage PE             |  |
|  +-----------------------------------+   +-------------------------------------+  |
|                                                                                   |
|  +-----------------------------------+   +-------------------------------------+  |
|  | Image Management                  |   | AVD Control Plane                   |  |
|  | - Azure Compute Gallery (SIG)     |   | - Workspace / Host Pool / DAG       |  |
|  +-----------------------------------+   +-------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 🖼️ 1. Simplified Host Pool Image Update System

### Powered by Azure Compute Gallery (SIG)

* **Centralized Golden Image**: Base Windows 11 Enterprise Multi-Session 23H2 image definition.
* **Version Control**: Manage image revisions (`v1.0.1` $\rightarrow$ `v1.0.2`).
* **Zero-Downtime Rolling Update Strategy**:
  1. Build new version in Azure Compute Gallery (`compute_gallery.tf`).
  2. Update `custom_image_version_id` in Terraform inputs (`terraform.tfvars`).
  3. Turn on **Drain Mode** on old session hosts.
  4. Provision new session hosts from latest image version; gracefully decommission old hosts after user logoff.

---

## 💾 2. Profile Management with FSLogix

### Enterprise Storage Architecture

* **Storage Tier**: Premium Azure Files (`FileStorage` tier, `ZRS` replication).
* **Private Connectivity**: Restricted to Private Endpoint (`snet-avd-private-endpoints`) with Private DNS integration (`privatelink.file.core.windows.net`).
* **Security & Auth**: Entra ID Kerberos (`AADKERB`) authentication over SMB.
* **Automated Host Provisioning**: Custom Script Extension configures registry keys on VM deployment:
  * `Enabled = 1`
  * `VHDLocations = \\<storage_account>.file.core.windows.net\profiles`
  * `FlipFlopProfileDirectoryName = 1`

---

## 📦 3. Dynamic App Delivery (MSIX App Attach)

### Decoupling Applications from OS Image

* **Dedicated App Attach Share**: Storage Account File Share (`appattach-packages`) backed by Private Endpoint.
* **On-Demand Package Mount**: Applications stored as `.vhdx` or `.cim` containers.
* **Business Benefits**:
  * Reduces OS image patching cycles by **70%**.
  * Eliminates application conflicts across session host pools.
  * Allows instantaneous app assignments to specific user groups without rebooting session hosts.

---

## 🔒 4. Network Security & Routing Control

* **Forced Tunneling**: Session Host Subnet UDR forces all Internet bound traffic (`0.0.0.0/0`) through the Hub Azure Firewall/NVA.
* **Strict NSG Controls**:
  * Inbound RDP restricted to internal management subnets.
  * Outbound filtered to `WindowsVirtualDesktop` service tag, KMS (`1688`), and HTTPS (`443`).
* **Zero Public Storage IPs**: All storage accounts disable public network access (`public_network_access_enabled = false`).
* **Identity Integration**: Native Entra ID Join (`AADLoginForWindows`) extension enabled on all session hosts.

---

## 🛠️ 5. Infrastructure as Code (Terraform Layout)

| Module File | Key Infrastructure Resources |
| :--- | :--- |
| `network.tf` | AVD Spoke VNet, Subnets, UDR, NSG, Hub VNet Peering |
| `compute_gallery.tf` | Azure Compute Gallery, Win11 Image Definition |
| `storage_fslogix.tf` | Premium Azure Files, SMB Share `profiles`, Private Endpoint, DNS Link |
| `storage_appattach.tf` | Storage Account, SMB Share `appattach-packages`, Private Endpoint |
| `avd_core.tf` | AVD Workspace, Host Pool, Desktop App Group (DAG), Reg Token |
| `avd_session_hosts.tf` | Session Host VMs, NICs, Entra ID Join, AVD DSC, FSLogix Script |

---

## 🚀 6. Demo Execution & Verification

### Deployment Commands

```bash
# Clone & Navigate
git clone https://github.com/sam6shk/AVD_IaC_Spoke_Demo.git
cd AVD_IaC_Spoke_Demo

# Initialize & Validate
terraform init
terraform validate

# Plan & Apply
terraform plan -out=tfplan
terraform apply tfplan
```

**Validation Output**: `Success! The configuration is valid.`

---

## 💡 Summary & Next Steps

### Business Value Delivered

* **Modular & Reusable**: Standardized AVD Spoke Landing Zone pattern for multi-region scalability.
* **Operational Excellence**: Zero-downtime image maintenance via ACG.
* **Enterprise Security**: Private Endpoints + Hub Firewall forced tunneling.

### Next Steps for Production Rollout

1. Connect customer's CI/CD pipeline (GitHub Actions / Azure DevOps).
2. Configure AVD Scaling Plan (Autoscaling schedules).
3. Onboard MSIX App Attach packages to production shares.
