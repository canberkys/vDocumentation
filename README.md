# vDocumentation v3.0

[![CI](https://github.com/canberkys/vDocumentation/actions/workflows/ci.yml/badge.svg)](https://github.com/canberkys/vDocumentation/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/vDocumentation)](https://www.powershellgallery.com/packages/vDocumentation)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

PowerShell module that produces infrastructure documentation of VMware vSphere environments in CSV or Excel format.

> **Maintained fork** of [arielsanchezmora/vDocumentation](https://github.com/arielsanchezmora/vDocumentation) by **Ariel Sanchez** and **Edgar Sanchez** (last updated Oct 2019, v2.4.7). This fork modernizes the module for **PowerShell 7+**, **PowerCLI 13.x**, and **vSphere 8**.

---

## Requirements

| Requirement | Version |
|---|---|
| PowerShell | 7.0+ |
| VMware PowerCLI | 13.0+ |
| ImportExcel *(optional)* | 3.0+ |
| vSphere / vCenter | 6.5+ (8.0+ for DPU features) |

## Installation

```powershell
# Install dependencies
Install-Module -Name VMware.PowerCLI -Scope CurrentUser
Install-Module -Name ImportExcel -Scope CurrentUser    # Optional, for Excel export

# Install vDocumentation
Install-Module -Name vDocumentation -Scope CurrentUser
```

To verify installation:

```powershell
Get-Module vDocumentation -ListAvailable | Format-List
```

## Quick Start

```powershell
# Connect to vCenter
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer vcenter.lab.local

# Document entire environment
Get-ESXInventory -ExportExcel

# Document specific cluster
Get-ESXNetworking -Cluster production -ExportExcel -folderPath /tmp/docs

# Document single host
Get-ESXStorage -VMhost esxi01.lab.local -ExportCSV
```

## Available Commands

| Command | Description |
|---|---|
| **Get-ESXInventory** | Host hardware inventory and configuration (BIOS, CPU, RAM, licensing, NTP, SSH) |
| **Get-ESXIODevice** | PCI/IO devices — HBAs, NICs, graphics — including VMware HCL compatibility |
| **Get-ESXNetworking** | Network config — physical adapters, VMkernel, vSwitches, CDP/LLDP |
| **Get-ESXStorage** | Storage config — iSCSI, Fibre Channel HBAs, datastores, multipathing |
| **Get-ESXPatching** | Patch compliance — VUM baselines, installed/missing patches, KB references |
| **Get-vSANInfo** | vSAN cluster — type (Flash/Hybrid), disk groups, capacity, dedup, policies |
| **Get-ESXSpeculativeExecution** | Spectre/Meltdown mitigation status — BIOS, MCU, host compliance |
| **Get-VMSpeculativeExecution** | VM-level Spectre mitigation — pipeline-enabled (`Get-VM \| Get-VMSpeculativeExecution`) |
| **Get-ESXDPUInventory** | **NEW** DPU/SmartNIC inventory — vendor, model, firmware, offload status (vSphere 8+) |

## Common Parameters

| Scope | Parameter | Description |
|---|---|---|
| Target | `-VMhost` | Specific ESXi host(s), comma-separated |
| Target | `-Cluster` | Specific cluster(s), comma-separated |
| Target | `-Datacenter` | Specific datacenter(s), comma-separated |
| Output | `-ExportCSV` | Export to CSV file |
| Output | `-ExportExcel` | Export to Excel file (requires ImportExcel module) |
| Output | `-PassThru` | Return objects to pipeline |
| Output | `-folderPath` | Custom output directory |

Each command also has specific switches for individual data tabs. Use `Get-Help <command> -Full` for details.

## What's New in v3.0

- **PowerShell 7+** and **PowerCLI 13.x** support
- **vSphere 8**: DPU/SmartNIC inventory, vSAN ESA detection, vSphere Lifecycle Manager
- **Cross-platform**: Windows, macOS, Linux
- **Bug fixes**: vSAN cluster type detection, HBA firmware, path separators, variable typos
- **Code quality**: 6 shared helper functions, ~1000 lines of duplicated code eliminated
- **CI/CD**: Pester tests, PSScriptAnalyzer, GitHub Actions

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Project Structure

```
powershell/vDocumentation/
  Public/          # 9 exported cmdlet functions
  Private/         # 6 shared helper functions
  vDocumentation.psd1   # Module manifest
  vDocumentation.psm1   # Module loader
tests/             # Pester 5 test suite
.github/workflows/ # CI/CD pipeline
```

## Contributing

Contributions are welcome. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Write Pester tests for new functionality
4. Ensure `Invoke-ScriptAnalyzer` passes
5. Submit a pull request

## Credits

**Original Authors:**
- Ariel Sanchez ([@arielsanchezmor](https://github.com/arielsanchezmora))
- Edgar Sanchez ([@edmsanchez13](https://github.com/edmsanchez13))

**Original Contributors:** Graham Barker (vSAN), Michael White, Justin Sider, @pdpelsem, and others.

**Maintained by:** Canberk Kilicarslan ([@canberkys](https://github.com/canberkys))

Originally presented at VMworld 2017 (session SER2077BU): [YouTube](https://www.youtube.com/watch?v=-KK0ih8tuTo)

## License

[MIT License](LICENSE) - (c) 2017-2026 Ariel Sanchez, Edgar Sanchez, and Contributors.
