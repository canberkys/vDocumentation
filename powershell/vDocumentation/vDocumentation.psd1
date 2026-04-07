#
# Module manifest for module 'vDocumentation'
#
# Originally created by: Edgar Sanchez, @edmsanchez13, virtualcornerstone.com
# Maintained fork by: Canberk Kilicarslan, @canberkys
#
# Generated on: 8/8/2017
# Forked and modernized: 2026
#

@{

# Script module or binary module file associated with this manifest.
RootModule = '.\vDocumentation.psm1'

# Version number of this module.
ModuleVersion = '3.0.0'

# ID used to uniquely identify this module
GUID = 'e38fbdc9-ac76-4e62-bb18-ae9feb9c23dc'

# Author of this module
Author = 'Ariel Sanchez, @arielsanchezmor, arielsanchezmora.com',
         'Edgar Sanchez, @edmsanchez13, virtualcornerstone.com',
         'Canberk Kilicarslan, @canberkys (maintainer)'

# Company or vendor of this module
CompanyName = 'Community'

# Copyright statement for this module
Copyright = '(c) 2017-2026 Ariel Sanchez, Edgar Sanchez, and Contributors. MIT License.'

# Description of the functionality provided by this module
Description = 'PowerShell module that produces documentation of a vSphere environment. Supports vSphere 8, PowerShell 7+, and PowerCLI 13.x. Maintained fork of the original vDocumentation by Ariel and Edgar Sanchez.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '7.0'

# Supported PSEditions
CompatiblePSEditions = @('Core')

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
    @{ ModuleName = 'VMware.VimAutomation.Core'; ModuleVersion = '13.0.0' }
)

# Functions to export from this module
FunctionsToExport = @(
    'Get-ESXStorage',
    'Get-ESXNetworking',
    'Get-ESXIODevice',
    'Get-ESXInventory',
    'Get-ESXPatching',
    'Get-vSANInfo',
    'Get-ESXSpeculativeExecution',
    'Get-VMSpeculativeExecution',
    'Get-ESXDPUInventory'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Aliases to export from this module
AliasesToExport = @()

# List of all files packaged with this module
FileList = @(
    '.\vDocumentation.psd1',
    '.\vDocumentation.psm1',
    '.\Public\Get-ESXStorage.ps1',
    '.\Public\Get-ESXNetworking.ps1',
    '.\Public\Get-ESXIODevice.ps1',
    '.\Public\Get-ESXInventory.ps1',
    '.\Public\Get-ESXPatching.ps1',
    '.\Public\Get-vSANInfo.ps1',
    '.\Public\Get-ESXSpeculativeExecution.ps1',
    '.\Public\Get-VMSpeculativeExecution.ps1',
    '.\Public\Get-ESXDPUInventory.ps1',
    '.\Private\Test-VIServerConnection.ps1',
    '.\Private\Get-VMHostList.ps1',
    '.\Private\Resolve-OutputFilePath.ps1',
    '.\Private\Export-CollectionData.ps1',
    '.\Private\Test-HostConnectionState.ps1',
    '.\Private\Write-VerboseModuleInfo.ps1'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @(
            'PowerShell', 'VMware', 'PowerCLI', 'Inventory', 'vSphere', 'vSphere8',
            'ESXi', 'VUM', 'vLCM', 'Patch', 'vSAN', 'vSAN-ESA', 'DPU', 'SmartNIC',
            'PowerShell7', 'Documentation'
        )

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/canberkys/vDocumentation/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/canberkys/vDocumentation'

        # ReleaseNotes of this module
        ReleaseNotes = @'
v3.0.0 - Maintained fork modernization
- PowerShell 7+ and PowerCLI 13.x support
- vSphere 8 support (DPU/SmartNIC, vSAN ESA, Lifecycle Manager)
- Cross-platform compatibility (Windows, macOS, Linux)
- Code refactoring with shared helper functions
- Bug fixes for vSAN cluster type detection, HBA firmware, Excel export
- Pester tests and GitHub Actions CI/CD
- Original project: https://github.com/arielsanchezmora/vDocumentation
'@

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
