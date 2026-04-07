function Test-HostConnectionState {
    <#
     .SYNOPSIS
       Tests if an ESXi host is in a Connected or Maintenance state
     .DESCRIPTION
       Returns $true if the host is reachable (Connected or Maintenance).
       If not, adds the host to the skip collection and returns $false.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $VMHost,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [ref]$SkipCollection
    )

    Write-Verbose -Message ((Get-Date -Format G) + "`t$($VMHost.Name) Connection State: $($VMHost.ConnectionState)")
    if ($VMHost.ConnectionState -eq "Connected" -or $VMHost.ConnectionState -eq "Maintenance") {
        return $true
    }
    else {
        $SkipCollection.Value += [pscustomobject]@{
            'Hostname'         = $VMHost.Name
            'Connection State' = $VMHost.ConnectionState
        }
        return $false
    }
}
