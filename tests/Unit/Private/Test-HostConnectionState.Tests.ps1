BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' '..' 'powershell' 'vDocumentation' 'Private' 'Test-HostConnectionState.ps1')
}

Describe 'Test-HostConnectionState' {
    It 'Returns true for Connected host' {
        $mockHost = [PSCustomObject]@{
            Name            = 'esxi01.lab.local'
            ConnectionState = 'Connected'
        }
        $skipCollection = @()
        $result = Test-HostConnectionState -VMHost $mockHost -SkipCollection ([ref]$skipCollection)
        $result | Should -BeTrue
        $skipCollection.Count | Should -Be 0
    }

    It 'Returns true for Maintenance host' {
        $mockHost = [PSCustomObject]@{
            Name            = 'esxi02.lab.local'
            ConnectionState = 'Maintenance'
        }
        $skipCollection = @()
        $result = Test-HostConnectionState -VMHost $mockHost -SkipCollection ([ref]$skipCollection)
        $result | Should -BeTrue
        $skipCollection.Count | Should -Be 0
    }

    It 'Returns false for Disconnected host and adds to skip collection' {
        $mockHost = [PSCustomObject]@{
            Name            = 'esxi03.lab.local'
            ConnectionState = 'Disconnected'
        }
        $skipCollection = @()
        $result = Test-HostConnectionState -VMHost $mockHost -SkipCollection ([ref]$skipCollection)
        $result | Should -BeFalse
        $skipCollection.Count | Should -Be 1
        $skipCollection[0].Hostname | Should -Be 'esxi03.lab.local'
        $skipCollection[0].'Connection State' | Should -Be 'Disconnected'
    }

    It 'Returns false for NotResponding host' {
        $mockHost = [PSCustomObject]@{
            Name            = 'esxi04.lab.local'
            ConnectionState = 'NotResponding'
        }
        $skipCollection = @()
        $result = Test-HostConnectionState -VMHost $mockHost -SkipCollection ([ref]$skipCollection)
        $result | Should -BeFalse
        $skipCollection.Count | Should -Be 1
    }
}
