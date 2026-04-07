function Export-CollectionData {
    <#
     .SYNOPSIS
       Exports a collection to CSV, Excel, PassThru, or Format-List
     .DESCRIPTION
       Unified export handler for all vDocumentation public functions.
       Supports CSV, Excel (with ImportExcel), PassThru (pipeline), and screen output.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$Collection,
        [Parameter(Mandatory)]
        [string]$OutputFile,
        [Parameter(Mandatory)]
        [string]$DisplayLabel,
        [string]$WorksheetName,
        [string]$CsvSuffix = '',
        [switch]$ExportCSV,
        [switch]$ExportExcel,
        [switch]$PassThru
    )

    if ($Collection.Count -eq 0) {
        return $null
    }

    Write-Host "`n" "$DisplayLabel`:" -ForegroundColor Green

    if ($ExportCSV) {
        $csvPath = $OutputFile + $CsvSuffix + ".csv"
        $Collection | Export-Csv $csvPath -NoTypeInformation
        Write-Host "`tData exported to $csvPath file" -ForegroundColor Green
    }
    elseif ($ExportExcel) {
        $xlsxPath = $OutputFile + ".xlsx"
        $sheetName = if ($WorksheetName) { $WorksheetName } else { $CsvSuffix }
        $Collection | Export-Excel $xlsxPath -WorkSheetname $sheetName -NoNumberConversion * -AutoSize -BoldTopRow -FreezeTopRow
        Write-Host "`tData exported to $xlsxPath file" -ForegroundColor Green
    }
    elseif ($PassThru) {
        return $Collection
    }
    else {
        $Collection | Format-List
    }

    return $null
}
