function Get-ESXPatching {
    <#
     .SYNOPSIS
       Get ESXi patch compliance
     .DESCRIPTION
       Will get patch compliance for a vSphere Cluster, Datacenter or individual ESXi host
     .NOTES
       File Name    : Get-ESXPatching.ps1
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
       Get-ESXPatching -VMhost devvm001.lab.local
     .PARAMETER Cluster
       The name(s) of the vSphere Cluster(s)
     .EXAMPLE
       Get-ESXPatching -Cluster production
     .PARAMETER Datacenter
       The name(s) of the vSphere Virtual Datacenter(s).
     .EXAMPLE
       Get-ESXPatching -Datacenter vDC001
     .PARAMETER baseline
      The name(s) of VUM basline(s) to use. By Default 'Critical Host Patches*', 'Non-Critical Host Patches*' are used if this parameter is not specified.
     .EXAMPLE
      Get-ESXPatching -Cluster production -baseline 'Custom baseline Host Patches'
     .PARAMETER ExportCSV
       Switch to export all data to CSV file. File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXPatching -Cluster production -ExportCSV
     .PARAMETER ExportExcel
       Switch to export all data to Excel file (No need to have Excel Installed). This relies on ImportExcel Module to be installed.
       ImportExcel Module can be installed directly from the PowerShell Gallery. See https://github.com/dfinke/ImportExcel for more information
       File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXPatching -Cluster production -ExportExcel
     .PARAMETER folderPath
       Specify an alternate folder path where the exported data should be saved.
     .EXAMPLE
       Get-ESXPatching -Cluster production -ExportExcel -folderPath C:\temp
     .PARAMETER LifecycleManager
       Switch to use vSphere Lifecycle Manager (vLCM) image-based compliance instead of VUM baselines.
       Use this for clusters managed with vLCM desired state images (vSphere 7+/8+).
     .EXAMPLE
       Get-ESXPatching -Cluster production -LifecycleManager -ExportExcel
     .PARAMETER PassThru
       Switch to return object to command line
     .EXAMPLE
       Get-ESXPatching -VMhost 192.168.1.100 -PassThru
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
        $baseline,
        [switch]$LifecycleManager,
        [switch]$ExportCSV,
        [switch]$ExportExcel,
        [switch]$PassThru,
        $folderPath
    )

    $patchingCollection = [System.Collections.ArrayList]@()
    $lastPatchingCollection = [System.Collections.ArrayList]@()
    $notCompliantPatchCollection = [System.Collections.ArrayList]@()
    $vlcmCollection = [System.Collections.ArrayList]@()
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

    <#
      vSphere Lifecycle Manager (vLCM) mode
      Uses image-based compliance instead of VUM baselines
    #>
    if ($LifecycleManager) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tUsing vSphere Lifecycle Manager (vLCM) mode")

        $vHostList = Get-VMHostList -VMhost $VMhost -Cluster $Cluster -DataCenter $DataCenter
        $outputFile = Resolve-OutputFilePath -BaseName "ESXiLifecycleManager" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

        foreach ($esxiHost in $vHostList) {

            if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) {
                continue
            }

            Write-Output "`tGathering vLCM compliance from $esxiHost ..."
            $vmhostView = $esxiHost | Get-View
            $esxiUpdateLevel = (Get-AdvancedSetting -Name "Misc.HostAgentUpdateLevel" -Entity $esxiHost -ErrorAction SilentlyContinue -ErrorVariable err).Value
            if ($esxiUpdateLevel) {
                $esxiVersion = ($esxiHost.Version) + " U" + $esxiUpdateLevel
            }
            else {
                $esxiVersion = $esxiHost.Version
            }

            <#
              Determine if host's cluster uses vLCM image mode
            #>
            $hostCluster = $esxiHost | Get-Cluster -ErrorAction SilentlyContinue
            $clusterName = if ($hostCluster) { $hostCluster.Name } else { "N/A (Standalone)" }
            $managementMode = "Unknown"
            $imageProfile = "N/A"
            $complianceStatus = "N/A"
            $firmwareAddon = "N/A"
            $driverAddon = "N/A"
            $baseImage = "N/A"
            $vendorAddon = "N/A"

            if ($hostCluster) {
                try {
                    <#
                      Get cluster's desired software spec via vLCM API
                      LcmClusterDesiredSoftwareSpec is available in PowerCLI 13+
                    #>
                    $clusterView = $hostCluster | Get-View
                    $settingsManager = Get-View -Id "ClusterComputeResource-$($clusterView.MoRef.Value)"

                    # Check if cluster uses image-based management
                    $softwareSpec = $null
                    try {
                        $softwareSpec = $settingsManager.GetDesiredSoftwareSpec()
                    }
                    catch {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tGetDesiredSoftwareSpec not available, trying alternative method")
                    }

                    if ($softwareSpec) {
                        $managementMode = "vLCM Image"
                        if ($softwareSpec.BaseImage) {
                            $baseImage = "$($softwareSpec.BaseImage.Version)"
                        }
                        if ($softwareSpec.VendorAddOn) {
                            $vendorAddon = "$($softwareSpec.VendorAddOn.Name) $($softwareSpec.VendorAddOn.Version)"
                        }
                        if ($softwareSpec.Components) {
                            $firmwareAddon = ($softwareSpec.Components | Where-Object {$_.Key -match "firmware|fwaddon"} | Select-Object -First 1).Value
                            if (-not $firmwareAddon) { $firmwareAddon = "N/A" }
                            $driverAddon = ($softwareSpec.Components | Where-Object {$_.Key -match "driver"} | Select-Object -First 1).Value
                            if (-not $driverAddon) { $driverAddon = "N/A" }
                        }

                        # Get host compliance status
                        try {
                            $hostCompliance = Test-LcmClusterCompliance -Cluster $hostCluster -ErrorAction SilentlyContinue
                            if ($hostCompliance) {
                                $hostStatus = $hostCompliance | Where-Object {$_.Entity.Name -eq $esxiHost.Name}
                                if ($hostStatus) {
                                    $complianceStatus = $hostStatus.ComplianceStatus
                                }
                                else {
                                    $complianceStatus = $hostCompliance.ComplianceStatus | Select-Object -First 1
                                }
                            }
                        }
                        catch {
                            Write-Verbose -Message ((Get-Date -Format G) + "`tTest-LcmClusterCompliance not available: $_")
                            $complianceStatus = "Unable to determine"
                        }
                    }
                    else {
                        $managementMode = "VUM Baseline"
                        Write-Verbose -Message ((Get-Date -Format G) + "`tCluster $clusterName uses VUM baseline mode, not vLCM image mode")
                    }
                }
                catch {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get vLCM info for cluster $clusterName`: $_")
                    $managementMode = "Error"
                }
            }

            # Get currently installed image profile
            try {
                $esxcli = Get-EsxCli -VMHost $esxiHost -V2
                $installedProfile = $esxcli.software.profile.get.Invoke()
                $imageProfile = $installedProfile.Name
            }
            catch {
                Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get installed image profile: $_")
            }

            $output = [PSCustomObject]@{
                'Hostname'             = $esxiHost.Name
                'Cluster'              = $clusterName
                'Product'              = $vmhostView.Config.Product.Name
                'Version'              = $esxiVersion
                'Build'                = $esxiHost.Build
                'Management Mode'      = $managementMode
                'Installed Image'      = $imageProfile
                'Desired Base Image'   = $baseImage
                'Vendor Add-On'        = $vendorAddon
                'Firmware Add-On'      = $firmwareAddon
                'Driver Add-On'        = $driverAddon
                'Compliance Status'    = $complianceStatus
            }
            [void]$vlcmCollection.Add($output)
        }

        $stopWatch.Stop()
        Write-Verbose -Message ((Get-Date -Format G) + "`tMain code execution completed")
        Write-Verbose -Message ((Get-Date -Format G) + "`tScript Duration: " + $stopWatch.Elapsed.Duration())

        if ($skipCollection) {
            Write-Warning -Message "`tCheck Connection State or Host name"
            Write-Warning -Message "`tSkipped hosts:"
            $skipCollection | Format-Table -AutoSize
        }

        if ($vlcmCollection) {
            $result = Export-CollectionData -Collection $vlcmCollection -OutputFile $outputFile -DisplayLabel "vSphere Lifecycle Manager Compliance" -WorksheetName "vLCM_Compliance" -CsvSuffix "vLCMCompliance" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
            if ($result) { $returnCollection += $result }
        }
        else {
            Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
        }

        if ($returnCollection) { $returnCollection }
        return
    }

    <#
      VUM Baseline mode (default)
      Validate if baseline parameter was specified (-baseline).
      By default 'Critical Host Patches*', 'Non-Critical Host Patches*'
      VUM baselines are used.
    #>
    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate baseline parameter")
    if ([string]::IsNullOrWhiteSpace($baseline)) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tA Baseline parameter (-baseline) was not specified. Will default to 'Critical Host Patches*', 'Non-Critical Host Patches*'")
        $baseline = 'Critical Host Patches*', 'Non-Critical Host Patches*'
    }

    $patchBaseline = Get-PatchBaseline -Name $baseline.Trim() -ErrorAction SilentlyContinue
    if ($patchBaseline) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tUsing VUM Baseline: " + (@($patchBaseline.Name) -join ','))
    }
    else {
        throw ("Could not find any baseline(s) named " + (@($baseline) -join ',') + " on server " + $Global:DefaultViServers + ". Please check Baseline name and try again.")
    }

    <#
      Gather host list based on Parameter set used
      NOTE: This function cannot use Get-VMHostList helper because
      it needs to attach baselines and start compliance scans
      during the host gathering phase.
    #>
    $vHostList = @()
    Write-Verbose -Message ((Get-Date -Format G) + "`tGather host list")
    if ($VMhost) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tExecuting Cmdlet using VMhost parameter set")
        Write-Output "`tGathering host list..."
        foreach ($individualHost in $VMhost) {
            $tempList = Get-VMHost -Name $individualHost.Trim() -ErrorAction SilentlyContinue
            if ($tempList) {
                $vHostList += $tempList
                Write-Verbose -Message ((Get-Date -Format G) + "`tStarting Scan for Updates ...")
                $scanEntity = $tempList
                $scanEntity | Attach-Baseline -Baseline $patchBaseline -ErrorAction SilentlyContinue
                $testComplianceTask = Test-Compliance -Entity $scanEntity -UpdateType HostPatch -RunAsync -ErrorAction SilentlyContinue
            }
            else {
                Write-Warning -Message "`tESXi host $individualHost was not found in $Global:DefaultViServers"
            }
        }
    }
    if ($Cluster) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tExecuting Cmdlet using Cluster parameter set")
        Write-Output ("`tGathering host list from the following Cluster(s): " + (@($Cluster) -join ','))
        foreach ($vClusterName in $Cluster) {
            $tempList = Get-Cluster -Name $vClusterName.Trim() -ErrorAction SilentlyContinue | Get-VMHost
            if ($tempList) {
                $vHostList += $tempList
                Write-Verbose -Message ((Get-Date -Format G) + "`tStarting Scan for Updates ...")
                $scanEntity = Get-Cluster -Name $vClusterName.Trim() -ErrorAction SilentlyContinue
                $scanEntity | Attach-Baseline -Baseline $patchBaseline -ErrorAction SilentlyContinue
                $testComplianceTask = $scanEntity | Test-Compliance -UpdateType HostPatch -RunAsync -ErrorAction SilentlyContinue
            }
            else {
                Write-Warning -Message "`tCluster with name $vClusterName was not found in $Global:DefaultViServers"
            }
        }
    }
    if ($DataCenter) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tExecuting Cmdlet using Datacenter parameter set")
        Write-Output ("`tGathering host list from the following DataCenter(s): " + (@($DataCenter) -join ','))
        foreach ($vDCname in $DataCenter) {
            $tempList = Get-Datacenter -Name $vDCname.Trim() -ErrorAction SilentlyContinue | Get-VMHost
            if ($tempList) {
                $vHostList += $tempList
                Write-Verbose -Message ((Get-Date -Format G) + "`tStarting Scan for Updates ...")
                $scanEntity = Get-Datacenter -Name $vDCname.Trim() -ErrorAction SilentlyContinue
                $scanEntity | Attach-Baseline -Baseline $patchBaseline -ErrorAction SilentlyContinue
                $testComplianceTask = $scanEntity | Test-Compliance -UpdateType HostPatch -RunAsync -ErrorAction SilentlyContinue
            }
            else {
                Write-Warning -Message "`tDatacenter with name $vDCname was not found in $Global:DefaultViServers"
            }
        }
    }

    $outputFile = Resolve-OutputFilePath -BaseName "ESXiPatching" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

    <#
      Main code execution
      Get patch compliance details
    #>
    if ($testComplianceTask) {
        $testComplianceTask = Get-Task -Id $testComplianceTask.Id -ErrorAction SilentlyContinue
    }
    $vHostList = $vHostList | Sort-Object -Property Name
    foreach ($esxiHost in $vHostList) {

        if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) {
            continue
        }

        <#
          Get ESXi version details
        #>
        $esxcli = Get-EsxCli -VMHost $esxiHost -V2
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
          Get ESXi Patch Compliance
          and details of sample/$vmhostPatch
        #>
        Write-Output "`tGathering patch compliance from $esxiHost ..."
        $vmhostPatch = $esxcli.software.vib.list.Invoke() | Where-Object {$_.ID -match $esxiHost.Build} | Select-Object -First 1
        $installedPatches = $esxcli.software.vib.list.Invoke() | Where-Object {$_.InstallDate -ge $vmhostPatch.InstallDate -and $_.Vendor -like "VMware*"}
        while ($testComplianceTask.PercentComplete -ne 100) {
            Write-Output ("`tWaiting on scan for updates to complete... " + $testComplianceTask.PercentComplete + "%")
            Start-Sleep -Seconds 5
            $testComplianceTask = Get-Task -Id $testComplianceTask.Id
        }

        $vmPatchCompliance = $esxiHost | Get-Compliance -Baseline $patchBaseline -Detailed
        foreach ($vmbaseline in $vmPatchCompliance) {
            $samplePatch = $vmbaseline.CompliantPatches | Where-Object {($_.Name.Replace(',', '')).Split() -contains $vmhostPatch.Name}
            if ($samplePatch) {
                $patchProduct = $samplePatch.Product.Name
                $patchReleaseDate = $samplePatch.ReleaseDate
            }

            <#
              Get accurate last patched date if ESXi 6.5
              based on Date and time (UTC), which is
              converted to local time
            #>
            if ($esxiHost.Version -notmatch '6.5') {
                $lastPatched = Get-Date $vmhostPatch.InstallDate -Format d
            }
            else {
                Write-Verbose -Message ((Get-Date -Format G) + "`tESXi version " + $esxiHost.Version + ". Gathering VIB " + $vmhostPatch.Name + " install date through ImageConfigManager")
                $configManagerView = Get-View $vmhostView.ConfigManager.ImageConfigManager
                $softwarePackages = $configManagerView.fetchSoftwarePackages() | Where-Object {$_.CreationDate -ge $vmhostPatch.InstallDate}
                $dateInstalledUTC = ($softwarePackages | Where-Object {$_.Name -eq $vmhostPatch.Name -and $_.Version -eq $vmhostPatch.Version}).CreationDate
                $lastPatched = Get-Date ($dateInstalledUTC.ToLocalTime()) -Format d
            }

            $output = [PSCustomObject]@{
                'Hostname'     = $esxiHost.Name
                'Product'      = $vmhostView.Config.Product.Name
                'Version'      = $esxiVersion
                'Build'        = $esxiHost.Build
                'Baseline'     = $vmbaseline.Baseline.Name
                'Compliance'   = $vmbaseline.Status
                'Last Patched' = $lastPatched
            }
            [void]$patchingCollection.Add($output)
        }

        <#
          Get last installed patches
        #>
        foreach ($vmbaseline in $vmPatchCompliance) {
            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering last installed patches...")
            $baselinePatches = Get-Patch -Baseline $vmbaseline.Baseline -Product $patchProduct -After $patchReleaseDate
            foreach ($vmPatch in $installedPatches) {
                $lastInstalledPatches = $baselinePatches | Where-Object {($_.Name.Replace(',', '')).Split() -contains $vmPatch.Name -and $_.ReleaseDate -eq $patchReleaseDate}
                foreach ($lastInstalledPatch in $lastInstalledPatches) {
                    <#
                      Determine if patch contains multiple VIBs
                      and update custom object so that
                      patch reports are accurate by Vendor ID
                    #>
                    $duplicateVendorID = $lastPatchingCollection | Where-Object {$_.Hostname -eq $esxiHost -and $_.'Vendor ID' -eq $lastInstalledPatch.IdByVendor}
                    if ($duplicateVendorID) {
                        if ($duplicateVendorID.'Patch Name' -eq $lastInstalledPatch.Name) {
                            Write-Verbose -Message ((Get-Date -Format G) + "`t" + $duplicateVendorID.'Vendor ID' + " already present in custom object. Updating VIB Name property with " + $vmPatch.Name)
                            $index = $lastPatchingCollection.IndexOf($duplicateVendorID)
                            $lastPatchingCollection[$index].'VIB Name(s)' += ", " + $vmPatch.Name
                            continue
                        }
                    }

                    <#
                      Get accurate patch install date if ESXi 6.5
                    #>
                    if ($esxiHost.Version -notmatch '6.5') {
                        $dateInstalled = Get-Date $vmPatch.InstallDate -Format d
                    }
                    else {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tESXi version " + $esxiHost.Version + ". Gathering VIB " + $vmPatch.Name + " install date through ImageConfigManager")
                        $configManagerView = Get-View $vmhostView.ConfigManager.ImageConfigManager
                        $softwarePackages = $configManagerView.fetchSoftwarePackages() | Where-Object {$_.CreationDate -ge $vmPatch.InstallDate}
                        $dateInstalledUTC = ($softwarePackages | Where-Object {$_.Name -eq $vmPatch.Name -and $_.Version -eq $vmPatch.Version}).CreationDate
                        $dateInstalled = Get-Date ($dateInstalledUTC.ToLocalTime()) -Format d
                    }

                    $dateReleased = Get-Date $lastInstalledPatch.ReleaseDate -Format d
                    $patchTimespan = (New-TimeSpan -Start $dateReleased -End $dateInstalled).Days
                    if ($lastInstalledPatch.Description -match 'http://' -or $lastInstalledPatch.Description -match 'https://') {
                        $referenceURL = ($lastInstalledPatch.Description | Select-String -Pattern "(?<url>https?://[\w|\.|/]*\w{1})").Matches[0].Groups['url'].Value
                    }
                    else {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get reference URL for patch: " + $lastInstalledPatch.Name)
                        Write-Verbose -Message ((Get-Date -Format G) + "`t" + $lastInstalledPatch.Description)
                        $referenceURL = $null
                    }

                    $output = [PSCustomObject]@{
                        'Hostname'       = $esxiHost.Name
                        'Product'        = $vmhostView.Config.Product.Name
                        'Version'        = $esxiVersion
                        'Build'          = $esxiHost.Build
                        'Baseline'       = $vmbaseline.Baseline.Name
                        'VIB Name(s)'    = $vmPatch.Name
                        'Patch Name'     = $lastInstalledPatch.Name
                        'Release Date'   = $dateReleased
                        'Installed Date' = $dateInstalled
                        'Patch Timespan' = "$patchTimespan Day(s)"
                        'Vendor ID'      = $lastInstalledPatch.IdByVendor
                        'URL'            = $referenceURL
                    }
                    [void]$lastPatchingCollection.Add($output)
                }
            }

            <#
              Get not compliant patches
            #>
            Write-Verbose -Message ((Get-Date -Format G) + "`tGathering not compliant patches...")
            $notCompliantPatches = $vmbaseline.NotCompliantPatches
            foreach ($notCompliantPatch in $notCompliantPatches) {
                if ($notCompliantPatch.Description -match 'http://' -or $notCompliantPatch.Description -match 'https://') {
                    $referenceURL = ($notCompliantPatch.Description | Select-String -Pattern "(?<url>https?://[\w|\.|/]*\w{1})").Matches[0].Groups['url'].Value
                }
                else {
                    Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get reference URL for patch: " + $notCompliantPatch.Name)
                    Write-Verbose -Message ((Get-Date -Format G) + "`t" + $notCompliantPatch.Description)
                    $referenceURL = $null
                }

                $output = [PSCustomObject]@{
                    'Hostname'     = $esxiHost.Name
                    'Product'      = $vmhostView.Config.Product.Name
                    'Version'      = $esxiVersion
                    'Build'        = $esxiHost.Build
                    'Baseline'     = $vmbaseline.Baseline.Name
                    'Patch Name'   = $notCompliantPatch.Name
                    'Release Date' = Get-Date $notCompliantPatch.ReleaseDate -Format d
                    'Vendor ID'    = $notCompliantPatch.IdByVendor
                    'URL'          = $referenceURL
                }
                [void]$notCompliantPatchCollection.Add($output)
            }
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

    if ($patchingCollection -or $lastPatchingCollection -or $notCompliantPatchCollection) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInformation gathered")
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
    }

    if ($patchingCollection) {
        $result = Export-CollectionData -Collection $patchingCollection -OutputFile $outputFile -DisplayLabel "ESXi Patch Compliance" -WorksheetName "Patch_Compliance" -CsvSuffix "PatchCompliance" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($lastPatchingCollection) {
        $result = Export-CollectionData -Collection $lastPatchingCollection -OutputFile $outputFile -DisplayLabel "ESXi Last Installed Patches" -WorksheetName "Last_Installed_Patches" -CsvSuffix "LastInstalledPatches" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($notCompliantPatchCollection) {
        $result = Export-CollectionData -Collection $notCompliantPatchCollection -OutputFile $outputFile -DisplayLabel "ESXi Missing Patches" -WorksheetName "Missing_Patches" -CsvSuffix "MissingPatches" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }

    if ($returnCollection) { $returnCollection }
}
