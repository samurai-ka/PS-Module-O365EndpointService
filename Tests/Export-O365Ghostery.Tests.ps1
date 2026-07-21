# Tests/Export-O365Ghostery.Tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot\..\O365EndpointFunctions.psd1" -Force

    # helper: run the cmdlet over a list of uris and return the parsed policy object
    function Get-Policy {
        param([string[]]$Uris, [switch]$TrustedDomains, [switch]$Whitelist)
        $input = $Uris | ForEach-Object { [pscustomobject]@{ uri = $_ } }
        $json  = $input | Export-O365Ghostery -TrustedDomains:$TrustedDomains -Whitelist:$Whitelist
        return ($json | ConvertFrom-Json)
    }
}

Describe 'Export-O365Ghostery' {

    It 'produces valid JSON' {
        $json = [pscustomobject]@{ uri = 'office.com' } | Export-O365Ghostery
        { $json | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'defaults to trustedDomains when no switch is given' {
        $policy = Get-Policy -Uris 'office.com'
        $policy.trustedDomains | Should -Contain 'office.com'
        $policy.PSObject.Properties.Name | Should -Not -Contain 'customFilters'
    }

    It '-TrustedDomains emits the trustedDomains array' {
        $policy = Get-Policy -Uris 'office.com' -TrustedDomains
        $policy.trustedDomains | Should -Contain 'office.com'
    }

    It '-Whitelist emits customFilters exception rules (@@||domain^)' {
        $policy = Get-Policy -Uris 'office.com' -Whitelist
        $policy.customFilters | Should -Contain '@@||office.com^'
        $policy.PSObject.Properties.Name | Should -Not -Contain 'trustedDomains'
    }

    It 'writes both keys when both switches are supplied' {
        $policy = Get-Policy -Uris 'office.com' -TrustedDomains -Whitelist
        $policy.trustedDomains | Should -Contain 'office.com'
        $policy.customFilters  | Should -Contain '@@||office.com^'
    }

    It 'normalises wildcard, scheme and path from the uri' {
        $policy = Get-Policy -Uris '*.office.com','https://outlook.office365.com/owa'
        $policy.trustedDomains | Should -Contain 'office.com'
        $policy.trustedDomains | Should -Contain 'outlook.office365.com'
    }

    It 'de-duplicates domains case-insensitively' {
        $policy = Get-Policy -Uris '*.office.com','office.com','OFFICE.com'
        @($policy.trustedDomains).Count | Should -Be 1
        $policy.trustedDomains | Should -Contain 'office.com'
    }
}
