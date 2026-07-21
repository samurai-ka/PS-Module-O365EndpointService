# Tests/Manifest.Tests.ps1

Describe 'Module manifest' {
    BeforeAll {
        $script:manifest = Test-ModuleManifest -Path "$PSScriptRoot\..\O365EndpointFunctions\O365EndpointFunctions.psd1"
    }

    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path "$PSScriptRoot\..\O365EndpointFunctions\O365EndpointFunctions.psd1"
        $manifest.Name | Should -Be 'O365EndpointFunctions'
    }

    It 'exports expected functions' {
        Import-Module "$PSScriptRoot\..\O365EndpointFunctions\O365EndpointFunctions.psd1" -Force
        $commands = Get-Command -Module O365EndpointFunctions | Select-Object -ExpandProperty Name

        $commands | Should -Contain 'Invoke-O365EndpointService'
        $commands | Should -Contain 'Export-O365ProxyPacFile'
        $commands | Should -Contain 'Export-O365Ghostery'
        $commands | Should -Contain 'Merge-O365EndpointService'
    }

    It 'has the expected GUID' {
        $manifest.Guid.ToString() | Should -Be 'a9b59d0b-ea5f-4b05-a5bf-b888c0866074'
    }

    It 'references O365EndpointFunctions.psm1 as the RootModule' {
        $manifest.RootModule | Should -Be 'O365EndpointFunctions.psm1'
    }

    It 'requires PowerShell 7.0 or higher' {
        $manifest.PowerShellVersion | Should -Not -BeNullOrEmpty
        $manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.0')
    }
}
