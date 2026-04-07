function Get-ESXStorage {
    <#
     .SYNOPSIS
       Get ESXi Storage Details
     .DESCRIPTION
       Will get iSCSI Software and Fibre Channel Adapter (HBA) details including Datastores
       All this can be gathered for a vSphere Cluster, Datacenter or individual ESXi host
     .NOTES
       File Name    : Get-ESXStorage.ps1
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
       Get-ESXStorage -VMhost devvm001.lab.local
     .PARAMETER Cluster
       The name(s) of the vSphere Cluster(s)
     .EXAMPLE
       Get-ESXStorage -Cluster production
     .PARAMETER Datacenter
       The name(s) of the vSphere Virtual DataCenter(s)
     .EXAMPLE
       Get-ESXStorage -Datacenter vDC001
     .PARAMETER ExportCSV
       Switch to export all data to CSV file. File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXStorage -Cluster production -ExportCSV
     .PARAMETER ExportExcel
       Switch to export all data to Excel file (No need to have Excel Installed). This relies on ImportExcel Module to be installed.
       ImportExcel Module can be installed directly from the PowerShell Gallery. See https://github.com/dfinke/ImportExcel for more information
       File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify an alternate location
     .EXAMPLE
       Get-ESXStorage -Cluster production -ExportExcel
     .PARAMETER StorageAdapters
       Default switch to get iSCSI Software and Fibre Channel Adapter (HBA) details
       This is default option that will get processed if no switch parameter is provided.
     .EXAMPLE
       Get-ESXStorage -Cluster production -StorageAdapters
     .PARAMETER Datastores
       Switch to get Datastores details
     .EXAMPLE
       Get-ESXStorage -Cluster production -Datastores
     .PARAMETER folderPath
       Specificies an alternate folder path of where the exported file should be saved.
     .EXAMPLE
       Get-ESXStorage -Cluster production -ExportExcel -folderPath C:\temp
     .PARAMETER PassThru
       Returns the object to the console
     .EXAMPLE
       Get-ESXStorage -VMhost devvm001.lab.local -PassThru
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
        [switch]$StorageAdapters,
        [switch]$Datastores,
        [switch]$PassThru,
        $folderPath
    )

    $FibreChannelCollection = [System.Collections.ArrayList]@()
    $iSCSICollection = [System.Collections.ArrayList]@()
    $DatastoresCollection = [System.Collections.ArrayList]@()
    $skipCollection = @()
    $returnCollection = @()

    <#
     ----------------------------------------------------------[Execution]----------------------------------------------------------
    #>

    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if ($PSBoundParameters.ContainsKey('Cluster') -or $PSBoundParameters.ContainsKey('DataCenter')) {
        [String[]]$VMhost = $null
    } #END if

    <#
      Query PowerCLI and vDocumentation versions if
      running Verbose
    #>
    Write-VerboseModuleInfo

    <#
      Check for an active connection to a VIServer
    #>
    Test-VIServerConnection

    <#
      Gather host list based on Parameter set used
    #>
    $vHostList = Get-VMHostList -VMhost $VMhost -Cluster $Cluster -DataCenter $DataCenter

    <#
      Validate export switches,
      folder path and dependencies
    #>
    $outputFile = Resolve-OutputFilePath -BaseName "Storage" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

    <#
      Validate that a Cmdlet switch was used. Options are
      -StorageAdapters, -Datastores. By default all are executed
      unless one is specified.
    #>
    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate Cmdlet switches")
    if ($StorageAdapters -or $Datastores) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was specified")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Cmdlet switch was not specified")
        Write-Verbose -Message ((Get-Date -Format G) + "`tWill execute all (-StorageAdapters -Datastores)")
        $StorageAdapters = $true
        $Datastores = $true
    } #END if/else

    <#
      Main code execution
    #>
    $vHostList = $vHostList | Sort-Object -Property Name
    foreach ($esxiHost in $vHostList) {

        <#
          Skip if ESXi host is not in a Connected
          or Maintenance ConnectionState
        #>
        if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) { continue }
        $esxcli1 = Get-EsxCli -VMHost $esxiHost -V2

        <#
          Get Storage adapters (HBA) details
        #>
        if ($StorageAdapters) {
            Write-Output "`tGathering storage adapter details from $esxiHost ..."

            <#
              Get iSCSI HBA Details
            #>
            Write-Verbose -Message ((Get-Date -Format G) + "`tGet iSCSI Software Adapter...")
            if ($hba = $esxiHost | Get-VMHostHba -Type iScsi | Where-Object {$_.Model -eq "iSCSI Software Adapter"}) {
                Write-Verbose -Message ((Get-Date -Format G) + "`tGet iSCSI HBA details for: " + $hba.Device)
                $hbaBinding = $esxcli1.iscsi.networkportal.list.Invoke(@{adapter = $hba.Device})
                $hbaTarget = Get-IScsiHbaTarget -IScsiHba $hba
                $sendList = $hbaTarget | Where-Object {$_.Type -eq "Send"} | Select-Object -ExpandProperty Address
                $staticList = $hbaTarget | Where-Object {$_.Type -eq "Static"} | Select-Object -ExpandProperty Address

                <#
                  Get active physical adapters
                  based on PortGroup.Test both
                  standard and distributed vSwitch
                #>
                foreach ($vmkNic in $hbaBinding) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tGet active physical adapter for: " + $vmkNic.PortGroup)
                    $vmNic = $esxiHost | Get-VMHostNetworkAdapter | Where-Object {$_.Mac -eq $vmkNic.MACAddress}
                    $nicList = $esxcli1.network.nic.list.Invoke() | Where-Object {$_.Name -eq $vmNic.Name}

                    <#
                      Use a custom object to store
                      collected data
                    #>
                    $output = [PSCustomObject]@{
                        'Hostname'                 = $esxiHost.Name
                        'Device'                   = $hba.Device
                        'iSCSI Name'               = $hba.IScsiName
                        'Model'                    = $hba.Model
                        'Send Targets'             = (@($sendList) -join ',')
                        'Static Tarets'            = (@($staticList) -join ',')
                        'Port Group'               = $vmkNic.PortGroup + " (" + $vmkNic.Vswitch + ")"
                        'VMkernel Adapter'         = $vmkNic.Vmknic
                        'Port Binding'             = $vmkNic.CompliantStatus
                        'Path Status'              = $vmkNic.PathStatus
                        'Physical Network Adapter' = $vmNic.Name + " (" + $vmnic.BitRatePerSec / 1000 + " Gbit/s, " + $nicList.Duplex + ")"
                    } #END [PSCustomObject]
                    [void]$iSCSICollection.Add($output)
                } #END foreach
            } #END if

            <#
              Get Fibre Channel HBA details
            #>
            Write-Verbose -Message ((Get-Date -Format G) + "`tGet Fibre Channel Adapter...")
            if ($hba = $esxiHost | Get-VMHostHba -Type FibreChannel) {
                foreach ($hbaDevice in $hba) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tGet Fibre Channel HBA details for: " + $hbaDevice.Device)
                    $nodeWWN = ([String]::Format("{0:X}", $HbaDevice.NodeWorldWideName) -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"
                    $portWWN = ([String]::Format("{0:X}", $HbaDevice.PortWorldWideName) -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"

                    <#
                      Use a custom object to store
                      collected data
                    #>
                    $output = [PSCustomObject]@{
                        'Hostname'   = $esxiHost.Name
                        'Device'     = $hbaDevice.Device
                        'Model'      = $hbaDevice.Model
                        'Node WWN'   = $nodeWWN
                        'Port WWN'   = $portWWN
                        'Driver'     = $hbaDevice.Driver
                        'Speed (Gb)' = $hbaDevice.Speed
                        'Status'     = $hbaDevice.Status
                    } #END [PSCustomObject]
                    [void]$FibreChannelCollection.Add($output)
                } # END foreach
            } #END if
        } #END if

        <#
          Get Datastores details
        #>
        if ($Datastores) {
            Write-Output "`tGathering Datastore details from $esxiHost ..."
            $hostDSList = $esxiHost | Get-Datastore | Sort-Object -Property Name
            foreach ($oneDS in $hostDSList) {
                Write-Verbose -Message ((Get-Date -Format G) + "`tGet Datastore details for: " + $oneDS.Name)
                $dsCName = $oneDS.ExtensionData.Info.Vmfs.Extent | Select-Object -First 1 -ExpandProperty DiskName
                if ($oneDS.Type -eq "vsan" -or $oneDS.Type -eq "NFS") {
                    Write-Verbose -Message ((Get-Date -Format G) + "`t" + $oneDS.Type + " type datastore found. Skipping storage multipathing policy validation")
                    $dsDisk = $null
                }
                else {
                    $dsDisk = $esxcli1.storage.nmp.device.list.Invoke(@{device = $dsCName})
                } #END if/else

                <#
                  Validate against exising collection
                  to speed up foreach
                #>
                $itemInCollection = $DatastoresCollection | Where-Object {$_.'Canonical Name' -like $dsCName} | Select-Object -First 1
                if ($itemInCollection) {
                    Write-Verbose -Message ((Get-Date -Format G) + "`t$dsCName already in collection; will reuse associated properties")
                    $dsName = $itemInCollection.'Datastore Name'
                    $dsDisplayName = $itemInCollection.'Device Name'
                    $LUN = $itemInCollection.LUN
                    $dsType = $itemInCollection.Type
                    $dsCluster = $itemInCollection.'Datastore Cluster'
                    $dsCapacityGB = $itemInCollection.'Capacity (GB)'
                    $ProvisionedGB = $itemInCollection.'Provisioned Space (GB)'
                    $dsFreeGB = $itemInCollection.'Free Space (GB)'
                    $dsTransportType = $itemInCollection.Transport
                    $dsMountPoint = $itemInCollection.'Mount Point'
                    $dsFileSystem = $itemInCollection.'File System Version'
                }
                else {
                    Write-Verbose -Message ((Get-Date -Format G) + "`t$dsCName not yet in collection; will query associated properties")
                    $dsView = $oneDS | Get-View
                    $dsSummary = $dsView | Select-Object -ExpandProperty Summary
                    $provisionedGB = [math]::round(($dsSummary.Capacity - $dsSummary.FreeSpace + $dsSummary.Uncommitted) / 1GB, 2)
                    if ($oneDS.Type -eq "vsan" -or $oneDS.Type -eq "NFS") {
                        Write-Verbose -Message ((Get-Date -Format G) + "`t" + $oneDS.Type + " type datastore found. Skipping storage path validation")
                        $dsDisplayName = $null
                        $LUN = $null
                        $dsTransport = $null
                    }
                    else {
                        $dspath = $esxcli1.storage.core.path.list.Invoke(@{device = $dsCName}) | Select-Object -First 1
                        $dsDisplayName = (($dspath.DeviceDisplayName -Split " [(]")[0])
                        $LUN = $dspath.LUN
                        $vmHBA = $dspath.Adapter
                        $dsTransport = $esxiHost | Get-VMHostHba | Select-Object Device, Type | Where-Object {$_.Device -eq $vmHBA}
                    } #END if/else
                    if ($null -eq $oneDS.ParentFolder -and $oneDS.ParentFolderId -match "StoragePod") {
                        $dsCluster = Get-DatastoreCluster -Id $oneDS.ParentFolderId | Select-Object -ExpandProperty Name
                        Write-Verbose -Message ((Get-Date -Format G) + "`tDatastore is part of Datastore Cluster: " + $dsCluster)
                    }
                    else {
                        $dsCluster = $null
                        Write-Verbose -Message ((Get-Date -Format G) + "`tDatastore not part of a Datastore Cluster")
                    } #END if/else
                    $dsName = $oneDS.Name
                    $dsType = $oneDS.Type
                    $dsCapacityGB = [math]::round($oneDS.CapacityGB, 2)
                    $dsFreeGB = [math]::round($oneDS.FreeSpaceGB, 2)
                    $dsTransportType = $dsTransport.Type
                    $dsMountPoint = (($dsSummary.Url -split "ds://")[1])
                    $dsFileSystem = $oneDS.FileSystemVersion
                } #END if/else

                <#
                  Use a custom object to store
                  collected data
                #>
                $output = [PSCustomObject]@{
                    'Hostname'               = $esxiHost.Name
                    'Datastore Name'         = $dsName
                    'Device Name'            = $dsDisplayName
                    'Canonical Name'         = $dsCName
                    'LUN'                    = $LUN
                    'Type'                   = $dsType
                    'Datastore Cluster'      = $dsCluster
                    'Capacity (GB)'          = $dsCapacityGB
                    'Provisioned Space (GB)' = $ProvisionedGB
                    'Free Space (GB)'        = $dsFreeGB
                    'Transport'              = $dsTransportType
                    'Mount Point'            = $dsMountPoint
                    'Multipath Policy'       = $dsDisk.PathSelectionPolicy
                    'File System Version'    = $dsFileSystem
                } #END [PSCustomObject]
                [void]$DatastoresCollection.Add($output)
            } #END foreach
        } #END if
    } #END foreach
    $stopWatch.Stop()
    Write-Verbose -Message ((Get-Date -Format G) + "`tMain code execution completed")
    Write-Verbose -Message  ((Get-Date -Format G) + "`tScript Duration: " + $stopWatch.Elapsed.Duration())

    <#
      Display skipped hosts and their connection status
    #>
    If ($skipCollection) {
        Write-Warning -Message "`tCheck Connection State or Host name "
        Write-Warning -Message "`tSkipped hosts: "
        $skipCollection | Format-Table -AutoSize
    } #END if

    <#
      Validate output arrays
    #>
    if ($iSCSICollection -or $FibreChannelCollection -or $DatastoresCollection) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInformation gathered")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
    } #END if/else

    <#
      Output to screen
      Export data to CSV, Excel
    #>
    if ($iSCSICollection) {
        $result = Export-CollectionData -Collection $iSCSICollection -OutputFile $outputFile -DisplayLabel "ESXi Storage iSCSI HBA" -WorksheetName "iSCSI_HBA" -CsvSuffix "iSCSI_HBA" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    } #END if
    if ($FibreChannelCollection) {
        $result = Export-CollectionData -Collection $FibreChannelCollection -OutputFile $outputFile -DisplayLabel "ESXi Fibre Channel HBA" -WorksheetName "FibreChannel_HBA" -CsvSuffix "FibreChannel" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    } #END if
    if ($DatastoresCollection) {
        $result = Export-CollectionData -Collection $DatastoresCollection -OutputFile $outputFile -DisplayLabel "ESXi Datastores" -WorksheetName "Datastores" -CsvSuffix "Datastores" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    } #END if
} #END function
