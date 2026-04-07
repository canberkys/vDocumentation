function Get-ESXDPUInventory {
    <#
     .SYNOPSIS
       Get ESXi DPU (Data Processing Unit) / SmartNIC inventory
     .DESCRIPTION
       Will get DPU/SmartNIC inventory information for a vSphere Cluster, Datacenter or individual ESXi host.
       Requires vSphere 8.0+ and PowerCLI 13.x+.
       The following is gathered:
       Hostname, DPU Vendor, DPU Model, DPU Firmware Version, DPU Status, Network Offload Status
     .NOTES
       File Name    : Get-ESXDPUInventory.ps1
       Author       : Canberk Kilicarslan - @canberkys
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
       Get-ESXDPUInventory -VMhost devvm001.lab.local
     .PARAMETER Cluster
       The name(s) of the vSphere Cluster(s)
     .EXAMPLE
       Get-ESXDPUInventory -Cluster production
     .PARAMETER Datacenter
       The name(s) of the vSphere Virtual Datacenter(s).
     .EXAMPLE
       Get-ESXDPUInventory -Datacenter vDC001
     .PARAMETER ExportCSV
       Switch to export all data to CSV file. File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXDPUInventory -Cluster production -ExportCSV
     .PARAMETER ExportExcel
       Switch to export all data to Excel file (No need to have Excel Installed). This relies on ImportExcel Module to be installed.
       ImportExcel Module can be installed directly from the PowerShell Gallery. See https://github.com/dfinke/ImportExcel for more information
       File is saved to the current user directory from where the script was executed. Use -folderPath parameter to specify a alternate location
     .EXAMPLE
       Get-ESXDPUInventory -Cluster production -ExportExcel
     .PARAMETER folderPath
       Specify an alternate folder path where the exported data should be saved.
     .EXAMPLE
       Get-ESXDPUInventory -Cluster production -ExportExcel -folderPath C:\temp
     .PARAMETER PassThru
       Switch to return object to command line
     .EXAMPLE
       Get-ESXDPUInventory -VMhost 192.168.1.100 -PassThru
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
        [switch]$PassThru,
        $folderPath
    )

    $dpuCollection = [System.Collections.ArrayList]@()
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

    $outputFile = Resolve-OutputFilePath -BaseName "DPUInventory" -FolderPath $folderPath -ExportCSV ([ref]$ExportCSV) -ExportExcel ([ref]$ExportExcel)

    <#
      Main code execution
    #>
    foreach ($esxiHost in $vHostList) {

        if (-not (Test-HostConnectionState -VMHost $esxiHost -SkipCollection ([ref]$skipCollection))) {
            continue
        }

        Write-Output "`tGathering DPU inventory from $esxiHost ..."
        $vmhostView = $esxiHost | Get-View
        $esxcli = Get-EsxCli -VMHost $esxiHost -V2

        <#
          Check ESXi version - DPU support requires 8.0+
        #>
        if ([version]$esxiHost.Version -lt [version]"8.0.0") {
            Write-Verbose -Message ((Get-Date -Format G) + "`t$esxiHost is running ESXi $($esxiHost.Version). DPU requires 8.0+. Skipping.")
            $output = [PSCustomObject]@{
                'Hostname'             = $esxiHost.Name
                'ESXi Version'         = $esxiHost.Version
                'DPU Supported'        = $false
                'DPU Vendor'           = 'N/A'
                'DPU Model'            = 'N/A'
                'DPU Firmware'         = 'N/A'
                'DPU ID'               = 'N/A'
                'DPU Status'           = 'ESXi 8.0+ required'
                'Network Offload'      = 'N/A'
            }
            [void]$dpuCollection.Add($output)
            continue
        }

        <#
          Get DPU information via host extension data
          DPUs are exposed through the DpuSystemInfo in vSphere 8.0+
        #>
        try {
            $dpuSystems = $vmhostView.Config.DpuSystemInfo
            if ($dpuSystems -and $dpuSystems.Count -gt 0) {
                foreach ($dpu in $dpuSystems) {
                    <#
                      Get DPU network offload status
                    #>
                    $networkOffload = "Unknown"
                    try {
                        $dpuNetworkInfo = $esxcli.network.dpu.list.Invoke() | Where-Object {$_.Id -eq $dpu.DpuId}
                        if ($dpuNetworkInfo) {
                            $networkOffload = $dpuNetworkInfo.Status
                        }
                    }
                    catch {
                        Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get DPU network info via esxcli: $_")
                    }

                    $output = [PSCustomObject]@{
                        'Hostname'             = $esxiHost.Name
                        'ESXi Version'         = $esxiHost.Version
                        'DPU Supported'        = $true
                        'DPU Vendor'           = $dpu.Vendor
                        'DPU Model'            = $dpu.SoftwareInfo.Product
                        'DPU Firmware'         = $dpu.SoftwareInfo.Version
                        'DPU ID'               = $dpu.DpuId
                        'DPU Status'           = $dpu.RuntimeInfo.Status
                        'Network Offload'      = $networkOffload
                    }
                    [void]$dpuCollection.Add($output)
                }
            }
            else {
                $output = [PSCustomObject]@{
                    'Hostname'             = $esxiHost.Name
                    'ESXi Version'         = $esxiHost.Version
                    'DPU Supported'        = $true
                    'DPU Vendor'           = 'N/A'
                    'DPU Model'            = 'N/A'
                    'DPU Firmware'         = 'N/A'
                    'DPU ID'               = 'N/A'
                    'DPU Status'           = 'No DPU detected'
                    'Network Offload'      = 'N/A'
                }
                [void]$dpuCollection.Add($output)
            }
        }
        catch {
            Write-Verbose -Message ((Get-Date -Format G) + "`tFailed to get DPU info from $esxiHost`: $_")
            $output = [PSCustomObject]@{
                'Hostname'             = $esxiHost.Name
                'ESXi Version'         = $esxiHost.Version
                'DPU Supported'        = 'Unknown'
                'DPU Vendor'           = 'N/A'
                'DPU Model'            = 'N/A'
                'DPU Firmware'         = 'N/A'
                'DPU ID'               = 'N/A'
                'DPU Status'           = "Error: $_"
                'Network Offload'      = 'N/A'
            }
            [void]$dpuCollection.Add($output)
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

    if ($dpuCollection) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tInformation gathered")
        $result = Export-CollectionData -Collection $dpuCollection -OutputFile $outputFile -DisplayLabel "ESXi DPU/SmartNIC Inventory" -WorksheetName "DPU_Inventory" -CsvSuffix "DPUInventory" -ExportCSV:$ExportCSV -ExportExcel:$ExportExcel -PassThru:$PassThru
        if ($result) { $returnCollection += $result }
    }
    else {
        Write-Verbose -Message ((Get-Date -Format G) + "`tNo information gathered")
    }

    if ($returnCollection) { $returnCollection }
}
