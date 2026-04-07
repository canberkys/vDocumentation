BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'powershell' 'vDocumentation' 'vDocumentation.psd1'
}

Describe 'vDocumentation Module' {
    It 'Module manifest is valid' {
        $manifest = Test-ModuleManifest -Path $modulePath -ErrorAction Stop
        $manifest | Should -Not -BeNullOrEmpty
    }

    It 'Module version is 3.0.0' {
        $manifest = Test-ModuleManifest -Path $modulePath
        $manifest.Version.ToString() | Should -Be '3.0.0'
    }

    It 'Module requires PowerShell 7.0' {
        $manifest = Test-ModuleManifest -Path $modulePath
        $manifest.PowerShellVersion | Should -Be '7.0'
    }

    It 'Module exports expected functions' {
        $manifest = Test-ModuleManifest -Path $modulePath
        $expectedFunctions = @(
            'Get-ESXStorage',
            'Get-ESXNetworking',
            'Get-ESXIODevice',
            'Get-ESXInventory',
            'Get-ESXPatching',
            'Get-vSANInfo',
            'Get-ESXSpeculativeExecution',
            'Get-VMSpeculativeExecution',
            'Get-ESXDPUInventory'
        )
        foreach ($func in $expectedFunctions) {
            $manifest.ExportedFunctions.Keys | Should -Contain $func
        }
    }

    It 'All public function files exist' {
        $publicPath = Join-Path $PSScriptRoot '..' 'powershell' 'vDocumentation' 'Public'
        $expectedFiles = @(
            'Get-ESXStorage.ps1',
            'Get-ESXNetworking.ps1',
            'Get-ESXIODevice.ps1',
            'Get-ESXInventory.ps1',
            'Get-ESXPatching.ps1',
            'Get-vSANInfo.ps1',
            'Get-ESXSpeculativeExecution.ps1',
            'Get-VMSpeculativeExecution.ps1',
            'Get-ESXDPUInventory.ps1'
        )
        foreach ($file in $expectedFiles) {
            Join-Path $publicPath $file | Should -Exist
        }
    }

    It 'All private function files exist' {
        $privatePath = Join-Path $PSScriptRoot '..' 'powershell' 'vDocumentation' 'Private'
        $expectedFiles = @(
            'Test-VIServerConnection.ps1',
            'Get-VMHostList.ps1',
            'Resolve-OutputFilePath.ps1',
            'Export-CollectionData.ps1',
            'Test-HostConnectionState.ps1',
            'Write-VerboseModuleInfo.ps1'
        )
        foreach ($file in $expectedFiles) {
            Join-Path $privatePath $file | Should -Exist
        }
    }
}
