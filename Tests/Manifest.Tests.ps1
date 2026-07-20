# Tests/Manifest.Tests.ps1

Describe 'Module manifest' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path "$PSScriptRoot\..\O365EndpointFunctions.psd1"
        $manifest.Name | Should -Be 'O365EndpointFunctions'
    }

    It 'exports expected functions' {
        Import-Module "$PSScriptRoot\..\O365EndpointFunctions.psd1" -Force
        $commands = Get-Command -Module O365EndpointFunctions | Select-Object -ExpandProperty Name

        $commands | Should -Contain 'Invoke-O365EndpointService'
        $commands | Should -Contain 'Export-O365ProxyPacFile'
        $commands | Should -Contain 'Export-O365Ghostery'
        $commands | Should -Contain 'Merge-O365EndpointService'
    }
}
