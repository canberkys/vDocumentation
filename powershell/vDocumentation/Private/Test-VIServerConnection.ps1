function Test-VIServerConnection {
    <#
     .SYNOPSIS
       Validates an active connection to a vSphere server
     .DESCRIPTION
       Checks $Global:DefaultViServers for active connections.
       Throws a terminating error if not connected.
    #>
    [CmdletBinding()]
    param ()

    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate connection to a vSphere server")
    if ($Global:DefaultViServers.Count -gt 0) {
        Write-Host "`tConnected to $Global:DefaultViServers" -ForegroundColor Green
    }
    else {
        throw "You must be connected to a vSphere server before running this Cmdlet."
    }
}
