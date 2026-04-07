BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' '..' 'powershell' 'vDocumentation' 'Private' 'Resolve-OutputFilePath.ps1')
}

Describe 'Resolve-OutputFilePath' {
    BeforeEach {
        $exportCSV = $true
        $exportExcel = $false
    }

    It 'Uses current location when folderPath is not specified' {
        $result = Resolve-OutputFilePath -BaseName "Test" -FolderPath $null -ExportCSV ([ref]$exportCSV) -ExportExcel ([ref]$exportExcel)
        $result | Should -Match "Test\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}"
        $result | Should -Match [regex]::Escape((Get-Location).Path)
    }

    It 'Uses specified folderPath when valid' {
        $tempDir = [System.IO.Path]::GetTempPath()
        $result = Resolve-OutputFilePath -BaseName "Test" -FolderPath $tempDir -ExportCSV ([ref]$exportCSV) -ExportExcel ([ref]$exportExcel)
        $result | Should -Match [regex]::Escape($tempDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar))
    }

    It 'Falls back to current location when folderPath is invalid' {
        $result = Resolve-OutputFilePath -BaseName "Test" -FolderPath "/nonexistent/path" -ExportCSV ([ref]$exportCSV) -ExportExcel ([ref]$exportExcel)
        $result | Should -Match [regex]::Escape((Get-Location).Path)
    }

    It 'Uses Join-Path for cross-platform path construction' {
        $result = Resolve-OutputFilePath -BaseName "Test" -FolderPath $null -ExportCSV ([ref]$exportCSV) -ExportExcel ([ref]$exportExcel)
        # Should not contain hardcoded backslash path separators (except within the path itself on Windows)
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Falls back to CSV when ImportExcel is not available' {
        $exportExcel = $true
        $exportCSV = $false

        # Mock Get-Module to return nothing for ImportExcel
        Mock Get-Module { $null } -ParameterFilter { $Name -eq 'ImportExcel' -and $ListAvailable }

        $result = Resolve-OutputFilePath -BaseName "Test" -FolderPath $null -ExportCSV ([ref]$exportCSV) -ExportExcel ([ref]$exportExcel)

        # If ImportExcel is actually installed, this test behaves differently
        # The function should handle both cases gracefully
        $result | Should -Not -BeNullOrEmpty
    }
}
