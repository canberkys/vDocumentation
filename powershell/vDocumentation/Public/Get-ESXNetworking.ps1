function Get-ESXNetworking {
    <#
     .SYNOPSIS
       Get ESXi Networking Details.
     .DESCRIPTION
       Will get Physical Adapters, Virtual Switches, and Port Groups
       All this can be gathered for a vSphere Cluster, Datacenter or individual ESXi host
     .NOTES
       File Name    : Get-ESXNetworking.ps1
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
       Get-ESXNetworking -VMhost devvm001.lab.local
     .PARAMETER Cluster
       The name(s) of the vSphere Cluster(s)
     .EXAMPLE
       Get-ESXNetworking -Cluster production
     .PARAMETER Datacenter
       The name(s) of the vSphere Virtual DataCenter(s)
     .EXAMPLE
       Get-ESXNetworking -Datacenter vDC001
     .PARAMETER ExportCSV
       Switch to export all data to CSV file. File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXNetworking -Cluster production -ExportCSV
     .PARAMETER ExportExcel
       Switch to export all data to Excel file (No need to have Excel Installed). This relies on ImportExcel Module to be installed.
       ImportExcel Module can be installed directly from the PowerShell Gallery. See https://github.com/dfinke/ImportExcel for more information
       File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXNetworking -Cluster production -ExportExcel
     .PARAMETER PhysicalAdapters
       Switch to get Physical Adapter details including uplinks to vswitch and CDP/LLDP Information
       This is default option that will get processed if no switch parameter is provided.
     .EXAMPLE
       Get-ESXNetworking -Cluster production -PhysicalAdapters
     .PARAMETER VMkernelAdapters
       Switch to get VMkernel Adapter details including Enabled services
     .EXAMPLE
       Get-ESXNetworking -Cluster production -VMkernelAdapters
     .PARAMETER VirtualSwitches
       Switch to get Virtual switches details including port groups.
     .EXAMPLE
       Get-ESXNetworking -Cluster production -VirtualSwitches
     .PARAMETER folderPath
       Specificies an alternate folder path of where the exported file should be saved.
     .EXAMPLE
       Get-ESXNetworking -Cluster production -ExportExcel -folderPath C:\temp
     .PARAMETER PassThru
       Returns the object to console
     .EXAMPLE
       Get-ESXNetworking -VMhost devvm001.lab.local -PassThru
    #>

    <#
     ----------------------------------------------------------[Declarations]----------------------------------------------------------
    #>
    [CmdletBinding(DefaultParameterSetName = 'VMhost')]
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
        [switch]$VirtualSwitches,
        [switch]$VMkernelAdapters,
        [switch]$PhysicalAdapters,
        [switch]$PassThru,
        $folderPath
    )

    $PhysicalAdapterCollection = [System.Collections.ArrayList]@()
    $VMkernelAdapterCollection = [System.Collections.ArrayList]@()
    $VirtualSwitchesCollection = [System.Collections.ArrayList]@()
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

    $outputFile = Resolve-OutputFilePath -BaseName "Networking" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

    <#
      Validate that a Cmdlet switch was used. Options are
      -PhysicalAdapters, -VMkernelAdapters, -VirtualSwitches.
      By default all are executed unless one is specified.
    #>
    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate Cmdlet switches")
    if ($PhysicalAdapters -or $VMkernelAdapters -or $VirtualSwitches) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was specified")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was not specified")
        Write-Verbose -Message ((Get-Date -Format G) + "`tWill execute all (-PhysicalAdapters, -VMkernelAdapters, -VirtualSwitches)")
        $PhysicalAdapters = $true
        $VMkernelAdapters = $true
        $VirtualSwitches = $true
    } #END if/else

    <#
      Main code execution
    #>
    foreach ($esxiHost in $vHostList) {

        if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) {
            continue
        }

        $vmhostView = $esxiHost | Get-View
        $esxcli = Get-EsxCli -VMHost $esxiHost -V2

        <#
          Get physical adapter details
        #>
        if ($PhysicalAdapters) {
            Write-Output "`tGathering physical adapter details from $esxiHost ..."
            $vmnics = $esxiHost | Get-VMHostNetworkAdapter -Physical | Select-Object -Property Name, Mac, Mtu
            foreach ($nic in $vmnics) {
                Write-Verbose -Message ((Get-Date -Format G) + "`tGet device details for: " + $nic.Name)
                $pciList = $esxcli.hardware.pci.list.Invoke() | Where-Object {$_.VMKernelName -eq $nic.Name}
                $nicList = $esxcli.network.nic.list.Invoke() | Where-Object {$_.Name -eq $nic.Name}

                <#
                  Get uplink vSwitch, check standard
                  vSwitch first then Distributed.
                #>
                if ($vSwitch = $esxcli.network.vswitch.standard.list.Invoke() | Where-Object {$_.uplinks -contains $nic.Name}) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tUplinks to vswitch: " + $vSwitch.Name)
                }
                else {
                    $vSwitch = $esxcli.network.vswitch.dvs.vmware.list.Invoke() | Where-Object {$_.uplinks -contains $nic.Name}
                    Write-Verbose -Message ((Get-Date -Format G) + "`tUplinks to vswitch: " + $vSwitch.Name)
                } #END if/else

                <#
                  Get Device Discovery Protocol CDP/LLDP
                #>
                Write-Verbose -Message ((Get-Date -Format G) + "`tGet Device Discovery Protocol for: " + $nic.Name)
                $networkSystem = $vmhostView.Configmanager.Networksystem
                $networkView = Get-View -Id $networkSystem
                $networkViewInfo = $networkView.QueryNetworkHint($nic.Name)
                if ($null -ne $networkViewInfo.connectedswitchport) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tDevice Discovery Protocol: CDP")
                    $ddp = "CDP"
                    $ddpExtended = $networkViewInfo.connectedswitchport
                    $ddpDevID = $ddpExtended.DevId
                    $ddpDevIP = $ddpExtended.Address
                    $ddpDevPortId = $ddpExtended.PortId
                }
                else {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tCDP not found")
                    if ($null -ne $networkViewInfo.lldpinfo) {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tDevice Discovery Protocol: LLDP")
                        $ddp = "LLDP"
                        $ddpDevID = $networkViewInfo.lldpinfo.Parameter | Where-Object {$_.Key -eq "System Name"} | Select-Object -ExpandProperty Value
                        $ddpDevIP = $networkViewInfo.lldpinfo.Parameter | Where-Object {$_.Key -eq "Management Address"} | Select-Object -ExpandProperty Value
                        $ddpDevPortId = $networkViewInfo.lldpinfo.Portid
                    }
                    else {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tLLDP not found")
                        $ddp = $null
                        $ddpDevID = $null
                        $ddpDevIP = $null
                        $ddpDevPortId = $null
                    } #END if/else
                } #END if/else

                <#
                  Use a custom object to store
                  collected data
                #>
                $output = [PSCustomObject]@{
                    'Hostname'           = $esxiHost.Name
                    'Name'               = $nic.Name
                    'Slot Description'   = $pciList.SlotDescription
                    'Device'             = $nicList.Description
                    'Duplex'             = $nicList.Duplex
                    'Link'               = $nicList.Link
                    'MAC'                = $nic.Mac
                    'MTU'                = $nicList.MTU
                    'Speed'              = $nicList.Speed
                    'vSwitch'            = $vSwitch.Name
                    'vSwitch MTU'        = $vSwitch.MTU
                    'Discovery Protocol' = $ddp
                    'Device ID'          = $ddpDevID
                    'Device IP'          = $ddpDevIP
                    'Port'               = $ddpDevPortId
                } #END [PSCustomObject]
                [void]$PhysicalAdapterCollection.Add($output)
            } #END foreach
        } #END if

        <#
          Get VMkernel adapter details
        #>
        if ($VMkernelAdapters) {
            Write-Output "`tGathering VMkernel adapter details from $esxiHost ..."
            $vmnics = $esxiHost | Get-VMHostNetworkAdapter -VMKernel
            foreach ($nic in $vmnics) {
                Write-Verbose -Message ((Get-Date -Format G) + "`tGathering details for: " + $nic.Name)

                <#
                  Get VMkernel adapter enabled services
                #>
                $enabledServices = @()
                if ($nic.VMotionEnabled) {
                    $enabledServices += "vMotion"
                } #END if
                if ($nic.FaultToleranceLoggingEnabled) {
                    $enabledServices += "Fault Tolerance logging"
                } #END if
                if ($nic.ManagementTrafficEnabled) {
                    $enabledServices += "Management"
                } #END if
                if ($nic.VsanTrafficEnabled) {
                    $enabledServices += "vSAN"
                } #END if

                <#
                  Get VMkernel adapter associated vSwitch, PortGroup Teaming Policy
                  and vSwitch MTU using Active adapter associated with the VMKernel Port.
                  Test against both Standard and Distributed Switch.
                #>
                $interfaceList = $esxcli.network.ip.interface.list.Invoke() | Where-Object {$_.Name -eq $nic.Name}
                if ($interfaceList.VDSName -eq "N/A") {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tStandard vSwitch: " + $interfaceList.Portset)
                    Write-Verbose -Message ((Get-Date -Format G) + "`tGet PortGroup details for: " + $nic.PortGroupName)
                    $portGroup = Get-VirtualPortGroup -VMhost $esxiHost -Name $nic.PortGroupName -Standard -ErrorAction SilentlyContinue
                    $portGroupTeam = $portGroup | Get-NicTeamingPolicy
                    $portVLanId = $portGroup | Select-Object -ExpandProperty VLanId
                    $vSwitch = $esxcli.network.vswitch.standard.list.Invoke(@{vswitchname = $interfaceList.Portset})
                    $vSwitchName = $interfaceList.Portset
                    $activeAdapters = (@($PortGroupTeam.ActiveNic) -join ',')
                    $standbyAdapters = (@($PortGroupTeam.StandbyNic) -join ',')
                    $unusedAdapters = (@($PortGroupTeam.UnusedNic) -join ',')
                }
                else {
                    if ($interfaceList.VDSUUID) {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tDistributed vSwitch: " + $interfaceList.VDSName)
                        Write-Verbose -Message ((Get-Date -Format G) + "`tGet PortGroup details for: " + $nic.PortGroupName)
                        $portGroup = Get-VDPortgroup -Name $nic.PortGroupName -VDSwitch $interfaceList.Portset -ErrorAction SilentlyContinue
                        $portGroupTeam = $portGroup | Get-VDUplinkTeamingPolicy
                        $portVLanId = $portGroup.VlanConfiguration.VlanId
                        $vSwitch = $esxcli.network.vswitch.dvs.vmware.list.Invoke(@{vdsname = $interfaceList.VDSName})
                        $vSwitchName = $interfaceList.VDSName
                        $activeAdapters = (@($PortGroupTeam.ActiveUplinkPort) -join ',')
                        $standbyAdapters = (@($PortGroupTeam.StandbyUplinkPort) -join ',')
                        $unusedAdapters = (@($PortGroupTeam.UnusedUplinkPort) -join ',')
                    }
                    else {
                        $vSwitch = $esxcli.network.vswitch.dvs.vmware.list.Invoke() | Where-Object {$_.VDSID -eq $interfaceList.VDSName}
                        Write-Verbose -Message ((Get-Date -Format G) + "`t3rd Party Distributed vSwitch: " + $vSwitch.Name)
                        $portVLanId = $null
                        $vSwitchName = $vSwitch.Name
                        $activeAdapters = $null
                        $standbyAdapters = $null
                        $unusedAdapters = $null
                    } #END if/else
                } #END if/else

                <#
                  Get TCP/IP Stack details
                #>
                Write-Verbose -Message ((Get-Date -Format G) + "`tGet VMkernel TCP/IP Stack details...")
                $netStackInstance = $vmhostView.Config.Network.NetStackInstance | Where-Object {$_.key -eq $interfaceList.NetstackInstance}
                $vmkGateway = $netStackInstance.IpRouteConfig.DefaultGateway
                $dnsAddress = $netStackInstance.DnsConfig.Address

                <#
                  Use a custom object to store
                  collected data
                #>
                $output = [PSCustomObject]@{
                    'Hostname'         = $esxiHost.Name
                    'Name'             = $nic.Name
                    'MAC'              = $nic.Mac
                    'MTU'              = $nic.MTU
                    'IP'               = $nic.IP
                    'Subnet Mask'      = $nic.SubnetMask
                    'TCP/IP Stack'     = $interfaceList.NetstackInstance
                    'Default Gateway'  = $vmkGateway
                    'DNS'              = (@($dnsAddress) -join ',')
                    'PortGroup Name'   = $nic.PortGroupName
                    'VLAN ID'          = $portVLanId
                    'Enabled Services' = (@($enabledServices) -join ',')
                    'vSwitch'          = $vSwitchName
                    'vSwitch MTU'      = $vSwitch.MTU
                    'Active adapters'  = $activeAdapters
                    'Standby adapters' = $standbyAdapters
                    'Unused adapters'  = $unusedAdapters
                } #END [PSCustomObject]
                [void]$VMkernelAdapterCollection.Add($output)
            } #END foreach
        } #END if

        <#
          Get virtual vSwitches details
        #>
        if ($VirtualSwitches) {
            Write-Output "`tGathering virtual vSwitches details from $esxiHost ..."

            <#
              Get standard switch details
            #>
            $StdvSwitch = Get-VirtualSwitch -VMHost $esxiHost -Standard
            foreach ($vSwitch in $StdvSwitch) {
                Write-Verbose -Message ((Get-Date -Format G) + "`tStandard vSwitch: " + $vSwitch.Name)

                <#
                  Get PortGroup details,
                  Security Policy, and Teaming Policy
                #>
                if ($portGroups = $vSwitch | Get-VirtualPortGroup) {
                    foreach ($port in $portGroups) {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tGet Port Group details for: " + $port.Name)
                        $portGroupTeam = $port | Get-NicTeamingPolicy
                        $portGroupSecurity = $port | Get-SecurityPolicy
                        $portGroupPolicy = @()
                        if ($portGroupSecurity.AllowPromiscuous) {
                            $portGroupPolicy += "Accept"
                        }
                        else {
                            $portGroupPolicy += "Reject"
                        } #END if/else
                        if ($portGroupSecurity.MacChanges) {
                            $portGroupPolicy += "Accept"
                        }
                        else {
                            $portGroupPolicy += "Reject"
                        } #END if/else
                        if ($portGroupSecurity.ForgedTransmits) {
                            $portGroupPolicy += "Accept"
                        }
                        else {
                            $portGroupPolicy += "Reject"
                        } #END if/else

                        <#
                          Use a custom object to store
                          collected data
                        #>
                        $output = [PSCustomObject]@{
                            'Hostname'                                        = $esxiHost.Name
                            'Type'                                            = "Standard"
                            'Version'                                         = $null
                            'Name'                                            = $vSwitch.Name
                            'Uplink/ConnectedAdapters'                        = (@($vSwitch.Nic) -join ',')
                            'PortGroup'                                       = $port.Name
                            'VLAN ID'                                         = $port.VLanId
                            'Active adapters'                                 = (@($PortGroupTeam.ActiveNic) -join ',')
                            'Standby adapters'                                = (@($PortGroupTeam.StandbyNic) -join ',')
                            'Unused adapters'                                 = (@($PortGroupTeam.UnusedNic) -join ',')
                            'Security Promiscuous/MacChanges/ForgedTransmits' = (@($portGroupPolicy) -join '/')
                        } #END [PSCustomObject]
                        [void]$VirtualSwitchesCollection.Add($output)
                    } #END foreach
                }
                else {
                    <#
                      Use a custom object to store
                      collected data
                    #>
                    $output = [PSCustomObject]@{
                        'Hostname'                                        = $esxiHost.Name
                        'Type'                                            = "Standard"
                        'Version'                                         = $null
                        'Name'                                            = $vSwitch.Name
                        'Uplink/ConnectedAdapters'                        = (@($vSwitch.Nic) -join ',')
                        'PortGroup'                                       = $null
                        'VLAN ID'                                         = $null
                        'Active adapters'                                 = $null
                        'Standby adapters'                                = $null
                        'Unused adapters'                                 = $null
                        'Security Promiscuous/MacChanges/ForgedTransmits' = $null
                    } #END [PSCustomObject]
                    [void]$VirtualSwitchesCollection.Add($output)
                } #END if/else
            } #END foreach

            <#
              Get distributed vSwitch details
            #>
            $dVSwitch = Get-VDSwitch -VMHost $esxiHost
            foreach ($vSwitch in $dVSwitch) {
                if ($vSwitch.Vendor -match "VMware") {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tDistributed vSwitch: " + $vSwitch.Name)

                    <#
                      Get PortGroup details,
                      Security Policy, and Teaming Policy
                    #>
                    $portGroups = $vSwitch | Get-VDPortgroup
                    $vSwitchUplink = @()
                    if ($portGroups) {
                        <#
                          Get distributed switch Uplinks
                        #>
                        $vSwitchUplink = $vSwitch | Get-VDPort -Uplink
                        $uplinkConnected = @()
                        foreach ($uplink in $vSwitchUplink) {
                            $uplinkConnected += $uplink.Name + "," + $uplink.ConnectedEntity
                        } #END foreach
                        foreach ($port in $portGroups | Where-Object {!$_.IsUplink}) {
                            Write-Verbose -Message ((Get-Date -Format G) + "`tGet Port Group details for: " + $port.Name)
                            $portGroupTeam = $port | Get-VDUplinkTeamingPolicy
                            $portGroupSecurity = $port | Get-VDSecurityPolicy
                            $portGroupPolicy = @()
                            if ($portGroupSecurity.AllowPromiscuous) {
                                $portGroupPolicy += "Accept"
                            }
                            else {
                                $portGroupPolicy += "Reject"
                            } #END if/else
                            if ($portGroupSecurity.MacChanges) {
                                $portGroupPolicy += "Accept"
                            }
                            else {
                                $portGroupPolicy += "Reject"
                            } #END if/else
                            if ($portGroupSecurity.ForgedTransmits) {
                                $portGroupPolicy += "Accept"
                            }
                            else {
                                $portGroupPolicy += "Reject"
                            } #END if/else

                            <#
                              Use a custom object to store
                              collected data
                            #>
                            $output = [PSCustomObject]@{
                                'Hostname'                                        = $esxiHost.Name
                                'Type'                                            = "Distributed"
                                'Version'                                         = $vSwitch.Version
                                'Name'                                            = $vSwitch.Name
                                'Uplink/ConnectedAdapters'                        = (@($uplinkConnected) -join '/')
                                'PortGroup'                                       = $port.Name
                                'VLAN ID'                                         = $port.VlanConfiguration.VlanId
                                'Active adapters'                                 = (@($PortGroupTeam.ActiveUplinkPort) -join ',')
                                'Standby adapters'                                = (@($PortGroupTeam.StandbyUplinkPort) -join ',')
                                'Unused adapters'                                 = (@($PortGroupTeam.UnusedUplinkPort) -join ',')
                                'Security Promiscuous/MacChanges/ForgedTransmits' = (@($portGroupPolicy) -join '/')
                            } #END [PSCustomObject]
                            [void]$VirtualSwitchesCollection.Add($output)
                        } #END foreach
                    }
                    else {
                        <#
                          Use a custom object to store
                          collected data
                        #>
                        $output = [PSCustomObject]@{
                            'Hostname'                                        = $esxiHost.Name
                            'Type'                                            = "Distributed"
                            'Version'                                         = $vSwitch.Version
                            'Name'                                            = $vSwitch.Name
                            'Uplink/ConnectedAdapters'                        = (@($uplinkConnected) -join '/')
                            'PortGroup'                                       = $port.Name
                            'VLAN ID'                                         = $port.VlanConfiguration.VlanId
                            'Active adapters'                                 = (@($PortGroupTeam.ActiveUplinkPort) -join ',')
                            'Standby adapters'                                = (@($PortGroupTeam.StandbyUplinkPort) -join ',')
                            'Unused adapters'                                 = (@($PortGroupTeam.UnusedUplinkPort) -join ',')
                            'Security Promiscuous/MacChanges/ForgedTransmits' = (@($portGroupPolicy) -join '/')
                        } #END [PSCustomObject]
                        [void]$VirtualSwitchesCollection.Add($output)
                    } #END if/else
                }
                else {
                    Write-Verbose -Message ((Get-Date -Format G) + "`t3rd Party distributed vSwitch: " + $vSwitch.Name)
                    $ThirdPartyVirtualSwitchesCollection = @()
                    $vSwitchView = $vSwitch | Get-View
                    $vSwitchUplink = $esxcli.network.vswitch.dvs.vmware.list.Invoke() | Where-Object {$_.Name -eq $vSwitch.Name}
                    $portGroups = $vSwitch | Get-VDPortgroup | Where-Object {$_.IsUplink -eq $false} | Select-Object -Property Name

                    <#
                      Use a custom object to store
                      collected data
                    #>
                    $ThirdPartyVirtualSwitchesCollection += [PSCustomObject]@{
                        'Hostname'   = $esxiHost.Name
                        'Type'       = "Distributed"
                        'Version'    = $vSwitch.Version
                        'Build'      = $vSwitchView.Summary.ProductInfo.Build
                        'Name'       = $vSwitch.Name
                        'Vendor'     = $vSwitchView.Summary.ProductInfo.Vendor
                        'Model'      = $vSwitchView.Summary.ProductInfo.Name
                        'Bundle ID'  = $vSwitchView.Summary.ProductInfo.BundleId
                        'Bundle URL' = $vSwitchView.Summary.ProductInfo.BundleUrl
                        'MTU'        = $vSwitchUplink.MTU
                        'Uplinks'    = (@($vSwitchUplink.uplinks) -join ',')
                        'PortGroups' = (@($portGroups.Name) -join ',')
                    } #END [PSCustomObject]
                } #END if/else
            } #END foreach
        } #END if
    } #END foreach
    $stopWatch.Stop()
    Write-Verbose -Message ((Get-Date -Format G) + "`tMain code execution completed")
    Write-Verbose -Message  ((Get-Date -Format G) + "`tScript Duration: " + $stopWatch.Elapsed.Duration())

    if ($skipCollection) {
        Write-Warning -Message "`tCheck Connection State or Host name"
        Write-Warning -Message "`tSkipped hosts:"
        $skipCollection | Format-Table -AutoSize
    }

    if ($PhysicalAdapterCollection -or $VMkernelAdapterCollection -or $VirtualSwitchesCollection -or $ThirdPartyVirtualSwitchesCollection) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInformation gathered")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
    } #END if/else

    if ($PhysicalAdapterCollection) {
        $result = Export-CollectionData -Collection $PhysicalAdapterCollection -OutputFile $outputFile -DisplayLabel "ESXi Physical Adapter" -WorksheetName "Physical_Adapters" -CsvSuffix "PhysicalAdapters" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($VMkernelAdapterCollection) {
        $result = Export-CollectionData -Collection $VMkernelAdapterCollection -OutputFile $outputFile -DisplayLabel "ESXi VMkernel Adapters" -WorksheetName "VMkernel_Adapters" -CsvSuffix "VMkernelAdapters" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($VirtualSwitchesCollection) {
        $result = Export-CollectionData -Collection $VirtualSwitchesCollection -OutputFile $outputFile -DisplayLabel "ESXi Virtual Switches" -WorksheetName "Virtual_Switches" -CsvSuffix "VirtualSwitches" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($ThirdPartyVirtualSwitchesCollection) {
        $result = Export-CollectionData -Collection $ThirdPartyVirtualSwitchesCollection -OutputFile $outputFile -DisplayLabel "ESXi 3rd party Virtual Switches" -WorksheetName "3rdParty_vSwitches" -CsvSuffix "3rdPartyvSwitches" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($returnCollection) { $returnCollection }
} #END function
