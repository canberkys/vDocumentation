function Get-ESXInventory {
    <#
     .SYNOPSIS
       Get basic ESXi host information
     .DESCRIPTION
       Will get inventory information for a vSphere Cluster, Datacenter or individual ESXi host
       The following is gathered:
       Hostname, Management IP, RAC IP, ESXi Version information, Hardware information
       and Host configuration
     .NOTES
       File Name    : Get-ESXInventory.ps1
       Author       : Edgar Sanchez - @edmsanchez13
       Contributor  : Ariel Sanchez - @arielsanchezmor
       Version      : 3.0.0
     .Link
       https://github.com/canberkys/vDocumentation
     .INPUTS
       No inputs required
     .OUTPUTS
       CSV file
       Excel file
     .PARAMETER VMhost
       The name(s) of the vSphere ESXi Host(s)
     .EXAMPLE
       Get-ESXInventory -VMhost devvm001.lab.local
     .PARAMETER Cluster
       The name(s) of the vSphere Cluster(s)
     .EXAMPLE
       Get-ESXInventory -Cluster production
     .PARAMETER Datacenter
       The name(s) of the vSphere Virtual Datacenter(s).
     .EXAMPLE
       Get-ESXInventory -Datacenter vDC001
     .PARAMETER ExportCSV
       Switch to export all data to CSV file. File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXInventory -Cluster production -ExportCSV
     .PARAMETER ExportExcel
       Switch to export all data to Excel file (No need to have Excel Installed). This relies on ImportExcel Module to be installed.
       ImportExcel Module can be installed directly from the PowerShell Gallery. See https://github.com/dfinke/ImportExcel for more information
       File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXInventory -Cluster production -ExportExcel
     .PARAMETER Hardware
       Switch to get Hardware inventory
     .EXAMPLE
       Get-ESXInventory -Cluster production -Hardware
     .PARAMETER Configuration
       Switch to get system configuration details
     .EXAMPLE
       Get-ESXInventory -Cluster production -Configuration
     .PARAMETER folderPath
       Specify an alternate folder path where the exported data should be saved.
     .EXAMPLE
       Get-ESXInventory -Cluster production -ExportExcel -folderPath C:\temp
     .PARAMETER PassThru
       Switch to return object to command line
     .EXAMPLE
       Get-ESXInventory -VMhost 192.168.1.100 -Hardware -PassThru
    #>

    [CmdletBinding(DefaultParameterSetName = 'VMhost')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("AvoidUsingConvertToSecureStringWithPlainText", "")]
    param (
        [Parameter(Mandatory = $false,
            ParameterSetName = "VMhost")]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String[]]$VMhost = "*",
        [Parameter(Mandatory = $false,
            ParameterSetName = "Cluster")]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String[]]$Cluster,
        [Parameter(Mandatory = $false,
            ParameterSetName = "DataCenter")]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String[]]$DataCenter,
        [switch]$ExportCSV,
        [switch]$ExportExcel,
        [switch]$Hardware,
        [switch]$Configuration,
        [switch]$PassThru,
        $folderPath
    )

    $hardwareCollection = [System.Collections.ArrayList]@()
    $configurationCollection = [System.Collections.ArrayList]@()
    $skipCollection = @()
    $returnCollection = @()

    <#
     ----------------------------------------------------------[Execution]----------------------------------------------------------
    #>

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($PSBoundParameters.ContainsKey('Cluster') -or $PSBoundParameters.ContainsKey('DataCenter')) {
        [String[]]$VMhost = $null
    }

    Write-VerboseModuleInfo
    Test-VIServerConnection
    $vHostList = Get-VMHostList -VMhost $VMhost -Cluster $Cluster -DataCenter $DataCenter

    $outputFile = Resolve-OutputFilePath -BaseName "Inventory" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

    <#
      Validate that a Cmdlet switch was used. Options are
      -Hardware, -Configuration. By default all are executed
      unless one is specified.
    #>
    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate Cmdlet switches")
    if ($Hardware -or $Configuration) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was specified")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was not specified")
        Write-Verbose -Message ((Get-Date -Format G) + "`tWill execute all (-Hardware -Configuration)")
        $Hardware = $true
        $Configuration = $true
    }

    <#
      Initialize variables used for -Configuration switch
    #>
    if ($Configuration) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInitializing -Configuration Cmdlet switch variables...")
        $serviceInstance = Get-View ServiceInstance
        $licenseManager = Get-View $ServiceInstance.Content.LicenseManager
        $licenseManagerAssign = Get-View $LicenseManager.LicenseAssignmentManager
    }

    <#
      Main code execution
    #>
    foreach ($esxiHost in $vHostList) {

        if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) {
            continue
        }

        $esxcli = Get-EsxCli -VMHost $esxiHost -V2
        $hostHardware = $esxiHost | Get-VMHostHardware -WaitForAllData -SkipAllSslCertificateChecks -ErrorAction SilentlyContinue
        $vmhostView = $esxiHost | Get-View
        $esxiUpdateLevel = (Get-AdvancedSetting -Name "Misc.HostAgentUpdateLevel" -Entity $esxiHost -ErrorAction SilentlyContinue -ErrorVariable err).Value
        if ($esxiUpdateLevel) {
            $esxiVersion = ($esxiHost.Version) + " U" + $esxiUpdateLevel
        }
        else {
            $esxiVersion = $esxiHost.Version
            Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get ESXi Update Level, Error : " + $err)
        }

        <#
          Get Hardware inventory details
        #>
        if ($Hardware) {
            Write-Output "`tGathering Hardware inventory from $esxiHost ..."
            $mgmtIP = Get-VMHostNetworkAdapter -VMHost $esxiHost -VMKernel | Where-Object {$_.ManagementTrafficEnabled -eq 'True'} | Select-Object -ExpandProperty IP
            $hardwarePlatfrom = $esxcli.hardware.platform.get.Invoke()

            <#
              Get RAC IP, and Firmware
            #>
            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering RAC IP...")
            $cimServicesTicket = $vmhostView.AcquireCimServicesTicket()
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cimServicesTicket.SessionId, (ConvertTo-SecureString $cimServicesTicket.SessionId -AsPlainText -Force)
            try {
                $racIP = $null
                $racMAC = $null
                $cimOpt = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
                $session = New-CimSession -Authentication Basic -Credential $credential -ComputerName $esxiHost -port 443 -SessionOption $cimOpt -ErrorAction SilentlyContinue -ErrorVariable err
                if ($err) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`t$err")
                }
                $rac = $session | Get-CimInstance CIM_IPProtocolEndpoint -ErrorAction SilentlyContinue -ErrorVariable err | Where-Object {$_.Name -match "Management Controller IP"}
                if ($rac.Name) {
                    $racIP = $rac.IPv4Address
                    $racMAC = $rac.MACAddress
                }
            }
            catch {
                Write-Verbose -Message ((Get-Date -Format G) + "`tCIM session failed, error:")
                Write-Verbose -Message ((Get-Date -Format G) + "`t$err")
            }
            if ($bmc = $esxiHost.ExtensionData.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo | Where-Object {$_.Name -match "BMC Firmware"}) {
                $bmcFirmware = (($bmc.Name -split "firmware")[1]) -split " " | Select-Object -Last 1
            }
            else {
                Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get BMC firmware via CIM, testing using WSMan ...")
                try {
                    $bmcFirmware = $null
                    $cimOpt = New-WSManSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -ErrorAction SilentlyContinue -ErrorVariable err
                    $uri = "https`://" + $esxiHost.Name + "/wsman"
                    $resourceURI = "http://schema.omc-project.org/wbem/wscim/1/cim-schema/2/OMC_MCFirmwareIdentity"
                    $rac = Get-WSManInstance -Authentication basic -ConnectionURI $uri -Credential $credential -Enumerate -Port 443 -UseSSL -SessionOption $cimOpt -ResourceURI $resourceURI -ErrorAction SilentlyContinue -ErrorVariable err
                    if ($rac.VersionString) {
                        $bmcFirmware = $rac.VersionString
                    }
                }
                catch {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tWSMan session failed, error:")
                    Write-Verbose -Message ((Get-Date -Format G) + "`t$err")
                }
            }

            $output = [PSCustomObject]@{
                'Hostname'           = $esxiHost.Name
                'Management IP'      = $mgmtIP
                'RAC IP'             = $racIP
                'RAC MAC'            = $racMAC
                'RAC Firmware'       = $bmcFirmware
                'Product'            = $vmhostView.Config.Product.Name
                'Version'            = $esxiVersion
                'Build'              = $esxiHost.Build
                'Make'               = $hostHardware.Manufacturer
                'Model'              = $hostHardware.Model
                'S/N'                = $hardwarePlatfrom.serialNumber
                'BIOS'               = $hostHardware.BiosVersion
                'BIOS Release Date'  = (($vmhostView.Hardware.BiosInfo.ReleaseDate -split " ")[0])
                'CPU Model'          = $hostHardware.CpuModel -replace '\s+', ' '
                'CPU Count'          = $hostHardware.CpuCount
                'CPU Core Total'     = $hostHardware.CpuCoreCountTotal
                'Speed (MHz)'        = $hostHardware.MhzPerCpu
                'Memory (GB)'        = $esxiHost.MemoryTotalGB -as [int]
                'Memory Slots Count' = $hostHardware.MemorySlotCount
                'Memory Slots Used'  = $hostHardware.MemoryModules.Count
                'Power Supplies'     = $hostHardware.PowerSupplies.Count
                'NIC Count'          = $hostHardware.NicCount
            }
            [void]$hardwareCollection.Add($output)
        }

        <#
          Get ESXi configuration details
        #>
        if ($Configuration) {
            Write-Output "`tGathering configuration details from $esxiHost ..."

            $vmhostID = $vmhostView.Config.Host.Value
            $vmhostLM = $licenseManagerAssign.QueryAssignedLicenses($vmhostID)
            $vmhostPatch = $esxcli.software.vib.list.Invoke() | Where-Object {$_.ID -match $esxiHost.Build} | Select-Object -First 1
            $vmhostvDC = $esxiHost | Get-Datacenter | Select-Object -ExpandProperty Name
            $vmhostCluster = $esxiHost | Get-Cluster | Select-Object -ExpandProperty Name
            $imageProfile = $esxcli.software.profile.get.Invoke()

            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering services configuration...")
            $vmServices = $esxiHost | Get-VMHostService
            $vmhostFireWall = $esxiHost | Get-VMHostFirewallException
            $ntpServerList = $esxiHost | Get-VMHostNtpServer
            $ntpService = $vmServices | Where-Object {$_.key -eq "ntpd"}
            $ntpFWException = $vmhostFireWall | Select-Object -Property Name, Enabled | Where-Object {$_.Name -eq "NTP Client"}
            $sshService = $vmServices | Where-Object {$_.key -eq "TSM-SSH"}
            $sshServerFWException = $vmhostFireWall | Select-Object -Property Name, Enabled | Where-Object {$_.Name -eq "SSH Server"}
            $esxiShellService = $vmServices | Where-Object {$_.key -eq "TSM"}
            $ShellTimeOut = (Get-AdvancedSetting -Entity $esxiHost -Name "UserVars.ESXiShellTimeOut" -ErrorAction SilentlyContinue).Value
            $interactiveShellTimeOut = (Get-AdvancedSetting -Entity $esxiHost -Name "UserVars.ESXiShellInteractiveTimeOut" -ErrorAction SilentlyContinue).Value

            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering Syslog Configuration...")
            $syslogList = @()
            $syslogFWException = $vmhostFireWall | Select-Object -Property Name, Enabled | Where-Object {$_.Name -eq "syslog"}
            foreach ($syslog in $esxiHost | Get-VMHostSysLogServer) {
                $syslogList += $syslog.Host + ":" + $syslog.Port
            }

            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering UpTime Configuration...")
            $bootTimeUTC = $vmhostView.Runtime.BootTime
            $BootTime = $bootTimeUTC.ToLocalTime()
            $upTime = New-TimeSpan -Seconds $vmhostView.Summary.QuickStats.Uptime
            $upTimeDays = $upTime.Days
            $upTimeHours = $upTime.Hours
            $upTimeMinutes = $upTime.Minutes
            $vmUUID = $esxcli.system.uuid.get.Invoke()
            $decimalDate = [Convert]::ToInt32($vmUUID.Split("-")[0], 16)
            $installDate = ([DateTime]'1/1/1970').AddSeconds($decimalDate).ToLocalTime()

            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering ESXi installation type...")
            $bootDevice = $esxcli.system.boot.device.get.Invoke()
            if ($bootDevice.BootFilesystemUUID) {
                if ($bootDevice.BootFilesystemUUID[6] -eq 'e') {
                    $installType = "Embedded"
                }
                else {
                    $installType = "Installable"
                    $bootSource = $esxcli.storage.filesystem.list.Invoke() | Where-Object {$_.UUID -eq $bootDevice.BootFilesystemUUID} | Select-Object -ExpandProperty MountPoint
                }
                $storageDevice = $esxcli.storage.core.device.list.Invoke() | Where-Object {$_.IsBootDevice -eq $true}
                $bootVendor = $storageDevice.Vendor + " " + $storageDevice.Model
                $bootDisplayName = $storageDevice.DisplayName
                $bootPath = $storageDevice.DevfsPath
                $storagePath = $esxcli.storage.core.path.list.Invoke() | Where-Object {$_.Device -eq $storageDevice.Device}
                $bootRuntime = $storagePath.RuntimeName
                if ($installType -eq "Embedded") {
                    $bootSource = $storageDevice.DisplayName.Split('(')[0]
                }
            }
            else {
                if ($bootDevice.StatelessBootNIC) {
                    $installType = "PXE Stateless"
                    $bootSource = $bootDevice.StatelessBootNIC
                }
                else {
                    $installType = "PXE"
                    $bootSource = $bootDevice.BootNIC
                }
                $bootVendor = $null
                $bootDisplayName = $null
                $bootPath = $null
                $bootRuntime = $null
            }

            $output = [PSCustomObject]@{
                'Hostname'                  = $esxiHost.Name
                'Make'                      = $hostHardware.Manufacturer
                'Model'                     = $hostHardware.Model
                'CPU Model'                 = $hostHardware.CpuModel -replace '\s+', ' '
                'Hyper-Threading'           = $esxiHost.HyperthreadingActive
                'Max EVC Mode'              = $esxiHost.MaxEVCMode
                'Product'                   = $vmhostView.Config.Product.Name
                'Version'                   = $esxiVersion
                'Build'                     = $esxiHost.Build
                'Install Type'              = $installType
                'Boot From'                 = $bootSource
                'Device Model'              = $bootVendor
                'Boot Device'               = $bootDisplayName
                'Runtime Name'              = $bootRuntime
                'Device Path'               = $bootPath
                'Image Profile'             = $imageProfile.Name
                'Acceptance Level'          = $imageProfile.AcceptanceLevel
                'Boot Time'                 = $BootTime
                'Uptime'                    = "$upTimeDays Day(s), $upTimeHours Hour(s), $upTimeMinutes Minute(s)"
                'Install Date'              = $installDate
                'Last Patched'              = $vmhostPatch.InstallDate
                'License Version'           = $vmhostLM.AssignedLicense.Name | Select-Object -Unique
                'License Key'               = $vmhostLM.AssignedLicense.LicenseKey | Select-Object -Unique
                'Connection State'          = $esxiHost.ConnectionState
                'Standalone'                = $esxiHost.IsStandalone
                'Cluster'                   = $vmhostCluster
                'Virtual Datacenter'        = $vmhostvDC
                'vCenter'                   = $vmhostView.Client.ServiceUrl.Split('/')[2]
                'NTP'                       = $ntpService.Label
                'NTP Running'               = $ntpService.Running
                'NTP Startup Policy'        = $ntpService.Policy
                'NTP Client Enabled'        = $ntpFWException.Enabled
                'NTP Server'                = (@($ntpServerList) -join ',')
                'SSH'                       = $sshService.Label
                'SSH Running'               = $sshService.Running
                'SSH Startup Policy'        = $sshService.Policy
                'SSH TimeOut'               = $ShellTimeOut
                'SSH Server Enabled'        = $sshServerFWException.Enabled
                'ESXi Shell'                = $esxiShellService.Label
                'ESXi Shell Running'        = $esxiShellService.Running
                'ESXi Shell Startup Policy' = $esxiShellService.Policy
                'ESXi Shell TimeOut'        = $interactiveShellTimeOut
                'Syslog Server'             = (@($syslogList) -join ',')
                'Syslog Client Enabled'     = $syslogFWException.Enabled
            }
            [void]$configurationCollection.Add($output)
        }
    }
    $stopWatch.Stop()
    Write-Verbose -Message ((Get-Date -Format G) + "`tMain code execution completed")
    Write-Verbose -Message ((Get-Date -Format G) + "`tScript Duration: " + $stopWatch.Elapsed.Duration())

    if ($skipCollection) {
        Write-Warning -Message "`tCheck Connection State or Host name"
        Write-Warning -Message "`tSkipped hosts:"
        $skipCollection | Format-Table -AutoSize
    }

    if ($hardwareCollection -or $configurationCollection) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInformation gathered")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
    }

    if ($hardwareCollection) {
        $result = Export-CollectionData -Collection $hardwareCollection -OutputFile $outputFile -DisplayLabel "ESXi Hardware Inventory" -WorksheetName "Hardware_Inventory" -CsvSuffix "Hardware" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($configurationCollection) {
        $result = Export-CollectionData -Collection $configurationCollection -OutputFile $outputFile -DisplayLabel "ESXi Host Configuration" -WorksheetName "Host_Configuration" -CsvSuffix "Configuration" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($returnCollection) { $returnCollection }
}
