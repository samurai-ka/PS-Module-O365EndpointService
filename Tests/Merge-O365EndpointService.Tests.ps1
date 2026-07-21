# Tests/Merge-O365EndpointService.Tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot\..\O365EndpointFunctions.psd1" -Force
}

Describe 'Merge-O365EndpointService' {

    It 'combines pipeline endpoints with endpoints from a JSON file' {
        $jsonPath = Join-Path $TestDrive 'endpoints.json'
        '[{"serviceArea":"FromFile","uri":"file.example.com","protocol":"url","tcpPort":8443,"udpPort":""}]' |
            Out-File $jsonPath -Encoding utf8

        $piped = [pscustomobject]@{ serviceArea = 'Piped'; uri = 'piped.example.com'; protocol = 'url'; tcpPort = '443' }
        $result = $piped | Merge-O365EndpointService -Path $jsonPath

        @($result).Count | Should -Be 2
        ($result.uri)    | Should -Contain 'piped.example.com'
        ($result.uri)    | Should -Contain 'file.example.com'
    }

    It 'parses ports from JSON numbers into uint16' {
        $jsonPath = Join-Path $TestDrive 'ports.json'
        '[{"serviceArea":"X","uri":"file.example.com","protocol":"url","tcpPort":8443,"udpPort":""}]' |
            Out-File $jsonPath -Encoding utf8

        $piped = [pscustomobject]@{ serviceArea = 'Y'; uri = 'piped.example.com'; protocol = 'url'; tcpPort = '443' }
        $result = $piped | Merge-O365EndpointService -Path $jsonPath

        $fromFile  = $result | Where-Object uri -eq 'file.example.com'
        $fromPiped = $result | Where-Object uri -eq 'piped.example.com'

        $fromFile.tcpPort            | Should -Be 8443
        $fromFile.tcpPort.GetType().Name | Should -Be 'UInt16'
        $fromPiped.tcpPort           | Should -Be 443
        # empty udpPort stays $null
        $fromFile.udpPort            | Should -BeNullOrEmpty
    }

    It 'preserves the endpoint set id from both the pipeline and JSON' {
        $jsonPath = Join-Path $TestDrive 'withid.json'
        '[{"id":42,"uri":"file.example.com","protocol":"url"}]' | Out-File $jsonPath -Encoding utf8

        $piped  = [pscustomobject]@{ id = 7; uri = 'piped.example.com'; protocol = 'url' }
        $result = $piped | Merge-O365EndpointService -Path $jsonPath

        ($result | Where-Object uri -eq 'piped.example.com').id | Should -Be 7
        ($result | Where-Object uri -eq 'file.example.com').id  | Should -Be 42
    }

    It 'ignores paths that are not .json' {
        $txtPath = Join-Path $TestDrive 'notjson.txt'
        'this is not json' | Out-File $txtPath -Encoding utf8

        $piped  = [pscustomobject]@{ serviceArea = 'Piped'; uri = 'piped.example.com'; protocol = 'url' }
        $result = $piped | Merge-O365EndpointService -Path $txtPath

        @($result).Count | Should -Be 1
        $result[0].uri   | Should -Be 'piped.example.com'
    }

    It 'reads endpoints from multiple JSON files' {
        $p1 = Join-Path $TestDrive 'one.json'
        $p2 = Join-Path $TestDrive 'two.json'
        '[{"uri":"one.example.com","protocol":"url"}]' | Out-File $p1 -Encoding utf8
        '[{"uri":"two.example.com","protocol":"url"}]' | Out-File $p2 -Encoding utf8

        $piped  = [pscustomobject]@{ uri = 'piped.example.com'; protocol = 'url' }
        $result = $piped | Merge-O365EndpointService -Path $p1, $p2

        @($result).Count | Should -Be 3
    }

    It 'requires the Path parameter' {
        (Get-Command Merge-O365EndpointService).Parameters['Path'].Attributes.Mandatory |
            Should -Contain $true
    }
}
