function Write-VerboseModuleInfo {
    <#
     .SYNOPSIS
       Logs PowerCLI and vDocumentation module versions when running verbose
     .DESCRIPTION
       Outputs module version information to the Verbose stream for troubleshooting.
    #>
    [CmdletBinding()]
    param ()

    if ($VerbosePreference -eq "Continue") {
        Write-Verbose -Message ((Get-Date -Format G) + "`tPowerCLI Version:")
        Get-Module -Name VMware.* | Select-Object -Property Name, Version | Format-Table -AutoSize
        Write-Verbose -Message ((Get-Date -Format G) + "`tvDocumentation Version:")
        Get-Module -Name vDocumentation | Select-Object -Property Name, Version | Format-Table -AutoSize
    }
}
