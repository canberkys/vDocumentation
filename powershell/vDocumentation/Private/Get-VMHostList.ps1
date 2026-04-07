function Get-VMHostList {
    <#
     .SYNOPSIS
       Gathers a list of ESXi hosts based on VMhost, Cluster, or DataCenter parameters
     .DESCRIPTION
       Returns a sorted list of VMHost objects gathered from the specified scope.
       Handles parameter set dispatch and warns about missing targets.
    #>
    [CmdletBinding()]
    param (
        [String[]]$VMhost,
        [String[]]$Cluster,
        [String[]]$DataCenter
    )

    $vHostList = @()

    Write-Verbose -Message ((Get-Date -Format G) + "`tGather host list")
    if ($VMhost) {
        Write-Verbose -Message ((Get-Date -Format G) + "`tExecuting Cmdlet using VMhost parameter set")
        Write-Output "`tGathering host list..."
        foreach ($individualHost in $VMhost) {
            $tempList = Get-VMHost -Name $individualHost.Trim() -ErrorAction SilentlyContinue
            if ($tempList) {
                $vHostList += $tempList
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
            }
            else {
                Write-Warning -Message "`tDatacenter with name $vDCname was not found in $Global:DefaultViServers"
            }
        }
    }

    $vHostList | Sort-Object -Property Name
}
