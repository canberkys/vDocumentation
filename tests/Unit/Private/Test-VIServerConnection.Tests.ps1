BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' '..' 'powershell' 'vDocumentation' 'Private' 'Test-VIServerConnection.ps1')
}

Describe 'Test-VIServerConnection' {
    It 'Throws when no VI server connection exists' {
        $Global:DefaultViServers = @()
        { Test-VIServerConnection } | Should -Throw "*must be connected*"
    }

    It 'Does not throw when connected to a VI server' {
        $Global:DefaultViServers = @([PSCustomObject]@{ Name = 'vcenter.lab.local' })
        { Test-VIServerConnection } | Should -Not -Throw
    }

    AfterAll {
        Remove-Variable -Name DefaultViServers -Scope Global -ErrorAction SilentlyContinue
    }
}
