function Resolve-OutputFilePath {
    <#
     .SYNOPSIS
       Validates export switches, folder path, and resolves the output file path
     .DESCRIPTION
       Checks folder path validity, builds a cross-platform output file path,
       and validates ImportExcel module availability when Excel export is requested.
       Returns the resolved output file path.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BaseName,
        [string]$FolderPath,
        [ref]$ExportCSV,
        [ref]$ExportExcel
    )

    $date = Get-Date -Format s
    $date = $date -replace ":", "-"
    $outputFile = $BaseName + $date

    Write-Verbose -Message ((Get-Date -Format G) + "`tValidate export switches and folder path")
    if ($ExportCSV.Value -or $ExportExcel.Value) {
        $currentLocation = (Get-Location).Path
        if ([string]::IsNullOrWhiteSpace($FolderPath)) {
            Write-Verbose -Message ((Get-Date -Format G) + "`t-folderPath parameter is Null or Empty")
            Write-Warning -Message "`tFolder Path (-folderPath) was not specified for saving exported data. The current location: '$currentLocation' will be used"
            $outputFile = Join-Path $currentLocation $outputFile
        }
        else {
            if (Test-Path $FolderPath) {
                Write-Verbose -Message ((Get-Date -Format G) + "`t'$FolderPath' path found")
                $outputFile = Join-Path $FolderPath $outputFile
                Write-Verbose -Message ((Get-Date -Format G) + "`t$outputFile")
            }
            else {
                Write-Warning -Message "`t'$FolderPath' path not found. The current location: '$currentLocation' will be used instead"
                $outputFile = Join-Path $currentLocation $outputFile
            }
        }
    }

    if ($ExportExcel.Value) {
        if (Get-Module -ListAvailable -Name ImportExcel) {
            Write-Verbose -Message ((Get-Date -Format G) + "`tImportExcel Module available")
        }
        else {
            Write-Warning -Message "`tImportExcel Module missing. Will export data to CSV file instead"
            Write-Warning -Message "`tImportExcel Module can be installed directly from the PowerShell Gallery"
            Write-Warning -Message "`tSee https://github.com/dfinke/ImportExcel for more information"
            $ExportExcel.Value = $false
            $ExportCSV.Value = $true
        }
    }

    $outputFile
}
