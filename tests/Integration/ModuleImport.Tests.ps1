Describe 'Module Import' {
    It 'Module manifest is valid and can be read' {
        $manifestPath = Join-Path $PSScriptRoot '..' '..' 'powershell' 'vDocumentation' 'vDocumentation.psd1'
        { Test-ModuleManifest -Path $manifestPath } | Should -Not -Throw
    }

    It 'Module loader file has no syntax errors' {
        $loaderPath = Join-Path $PSScriptRoot '..' '..' 'powershell' 'vDocumentation' 'vDocumentation.psm1'
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($loaderPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'All public function files have no syntax errors' {
        $publicPath = Join-Path $PSScriptRoot '..' '..' 'powershell' 'vDocumentation' 'Public'
        $files = Get-ChildItem -Path $publicPath -Filter '*.ps1'
        foreach ($file in $files) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "$($file.Name) should have no syntax errors"
        }
    }

    It 'All private function files have no syntax errors' {
        $privatePath = Join-Path $PSScriptRoot '..' '..' 'powershell' 'vDocumentation' 'Private'
        $files = Get-ChildItem -Path $privatePath -Filter '*.ps1'
        foreach ($file in $files) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "$($file.Name) should have no syntax errors"
        }
    }
}
