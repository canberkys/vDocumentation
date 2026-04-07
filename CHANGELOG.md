# Changelog

All notable changes to this project will be documented in this file.

## [3.0.1] - 2026-04-08

### Added
- vSAN ESA (Express Storage Architecture) detection in `Get-vSANInfo`
  - Detects ESA vs OSA storage architecture automatically
  - New output columns: `Storage Architecture`, `Compression Only (ESA)`
  - ESA clusters report correctly without disk groups
- vSphere Lifecycle Manager (vLCM) support in `Get-ESXPatching`
  - New `-LifecycleManager` switch for image-based compliance reporting
  - Reports: Management Mode, Desired Base Image, Vendor/Firmware/Driver Add-Ons, Compliance Status
  - Existing VUM baseline mode unchanged (default behavior)

---

## [3.0.0] - 2026-04-08

### About This Fork

This is a maintained fork of the original [vDocumentation](https://github.com/arielsanchezmora/vDocumentation) project created by **Ariel Sanchez** (@arielsanchezmor) and **Edgar Sanchez** (@edmsanchez13). The original project was last updated in October 2019 (v2.4.7). This fork modernizes the module for current VMware environments while preserving full attribution to the original authors.

### Added
- PowerShell 7+ and PowerCLI 13.x support
- `CompatiblePSEditions = @('Core')` in module manifest
- Cross-platform compatibility (Windows, macOS, Linux) via `Join-Path`
- `Get-ESXDPUInventory` - New function for DPU/SmartNIC documentation (vSphere 8)
- vSAN ESA (Express Storage Architecture) detection in `Get-vSANInfo`
- vSphere Lifecycle Manager (vLCM) support in `Get-ESXPatching`
- Private helper functions to reduce code duplication:
  - `Test-VIServerConnection` - Centralized vCenter connection validation
  - `Get-VMHostList` - Unified host gathering from VMhost/Cluster/DataCenter parameters
  - `Resolve-OutputFilePath` - Cross-platform output path resolution
  - `Export-CollectionData` - Unified CSV/Excel/PassThru export logic
  - `Test-HostConnectionState` - Host connection state validation
  - `Write-VerboseModuleInfo` - Module version verbose logging
- Pester 5 unit and integration tests
- GitHub Actions CI/CD pipeline (lint, test, publish)
- PSScriptAnalyzer integration
- `.gitignore` for PowerShell projects

### Fixed
- vSAN cluster type detection logic inversion (`Get-vSANInfo`)
- Cross-platform path separator (hardcoded `\` replaced with `Join-Path`)
- Variable typo in `Get-ESXNetworking` (`$ThirdPartyVirtualSwitchesCollectionn`)
- HBA firmware version detection in `Get-ESXStorage`
- Consistent Excel export settings (`-AutoSize`, `-FreezeTopRow`, `-NoNumberConversion`)

### Changed
- Minimum PowerShell version: 3.0 -> 7.0
- Minimum PowerCLI version: 6.3 -> 13.0
- Module loader uses `Join-Path` for cross-platform paths
- Refactored ~600 lines of duplicated code into 6 shared helper functions
- Updated module tags for vSphere 8 discoverability

### Removed
- Windows PowerShell 5.1 support (use v2.4.7 for legacy environments)

---

## Previous Releases (Original Project)

For releases v1.0 through v2.4.7, see the [original project changelog](https://github.com/arielsanchezmora/vDocumentation/blob/master/README.md).
