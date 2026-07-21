# Tests/Invoke-O365EndpointService.Tests.ps1
#
# These tests never touch the network or the real cache file: the REST calls (made through
# [EndpointSet]::InvokeRestRequest -> Invoke-RestMethod) and the file-system cmdlets are
# mocked inside the module scope.

BeforeAll {
    Import-Module "$PSScriptRoot\..\O365EndpointFunctions.psd1" -Force
    $script:ModuleName = 'O365EndpointFunctions'
}

Describe 'Invoke-O365EndpointService' {

    Context 'successful download' {

        BeforeAll {
            # isolate the cache file: pretend it exists and holds a valid client id + old version
            Mock -ModuleName $ModuleName Test-Path  { $true }
            Mock -ModuleName $ModuleName Get-Content { @('11111111-1111-1111-1111-111111111111', '0000000000') }
            Mock -ModuleName $ModuleName Out-File   { }

            Mock -ModuleName $ModuleName Invoke-RestMethod {
                if ($Uri -like '*/version/*') {
                    [pscustomobject]@{ latest = '2099010100' }
                }
                else {
                    @(
                        [pscustomobject]@{
                            serviceArea = 'Exchange'; serviceAreaDisplayName = 'Exchange Online'
                            category = 'Optimize'; expressRoute = $true; required = $true; notes = ''
                            urls = @('outlook.office.com'); ips = $null
                            tcpPorts = '80,443'; udpPorts = $null
                        }
                        [pscustomobject]@{
                            serviceArea = 'Exchange'; serviceAreaDisplayName = 'Exchange Online'
                            category = 'Allow'; expressRoute = $false; required = $false; notes = 'mail'
                            urls = $null; ips = @('13.107.6.152/31')
                            tcpPorts = '143, 587'; udpPorts = $null      # spaced list -> exercises Trim
                        }
                        [pscustomobject]@{
                            serviceArea = 'Skype'; serviceAreaDisplayName = 'Skype'
                            category = 'Default'; expressRoute = $false; required = $false; notes = ''
                            urls = $null; ips = @('52.112.0.0/14')
                            tcpPorts = $null; udpPorts = '3478,3479'
                        }
                    )
                }
            }
        }

        It 'flattens endpoint sets into one object per uri/ip and port' {
            $result = Invoke-O365EndpointService -tenantName 'contoso'
            # set1: 1 url x 2 tcp = 2 ; set2: 1 ip x 2 tcp = 2 ; set3: 1 ip x 2 udp = 2
            @($result).Count | Should -Be 6
        }

        It 'sets protocol and parses ports as uint16, leaving the unused port $null' {
            $result = Invoke-O365EndpointService -tenantName 'contoso'

            $urlEp = $result | Where-Object { $_.uri -eq 'outlook.office.com' -and $_.tcpPort -eq 80 }
            $urlEp.protocol          | Should -Be 'url'
            $urlEp.tcpPort.GetType().Name | Should -Be 'UInt16'
            $urlEp.udpPort           | Should -BeNullOrEmpty

            $udpEp = $result | Where-Object { $_.udpPort -eq 3478 }
            $udpEp.protocol          | Should -Be 'ip'
            $udpEp.tcpPort           | Should -BeNullOrEmpty
        }

        It 'trims whitespace from comma-separated port lists' {
            $result = Invoke-O365EndpointService -tenantName 'contoso'
            ($result.tcpPort) | Should -Contain 587   # from "143, 587"
        }

        It 'url-encodes the tenant name in the endpoints request' {
            Invoke-O365EndpointService -tenantName 'con to' | Out-Null
            # Invoke-RestMethod binds -Uri as [System.Uri]; the wire form is AbsoluteUri
            # (ToString() would decode %20 back to a space)
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                ([uri]$Uri).AbsoluteUri -match 'TenantName=con%20to'
            }
        }

        It 'requests IPv4 only by default (NoIPv6=true)' {
            Invoke-O365EndpointService -tenantName 'contoso' | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                $Uri -match 'NoIPv6=true'
            }
        }

        It 'includes IPv6 when -IPv6 is set (NoIPv6=false)' {
            Invoke-O365EndpointService -tenantName 'contoso' -IPv6 | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                $Uri -match 'NoIPv6=false'
            }
        }

        It 'defaults to the Worldwide instance' {
            Invoke-O365EndpointService -tenantName 'contoso' | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                $Uri -match '/endpoints/Worldwide\b'
            }
        }

        It 'targets the requested instance in both the version and endpoints calls' {
            Invoke-O365EndpointService -tenantName 'contoso' -Instance China | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter { $Uri -match '/version/China\b' }
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter { $Uri -match '/endpoints/China\b' }
        }

        It 'passes ServiceAreas to the endpoints request when specified' {
            Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas Exchange, SharePoint | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                $Uri -match 'ServiceAreas=Exchange,SharePoint'
            }
        }

        It 'omits ServiceAreas from the endpoints request by default' {
            Invoke-O365EndpointService -tenantName 'contoso' | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                ($Uri -match '/endpoints/') -and ($Uri -notmatch 'ServiceAreas=')
            }
        }

        It 'never sends ServiceAreas to the version request' {
            Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas Exchange | Out-Null
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -ParameterFilter {
                ($Uri -match '/version/') -and ($Uri -notmatch 'ServiceAreas=')
            }
        }

        It 'returns $null when the cached version is already current and -ForceLatest is not used' {
            # cache already at the latest version -> no download
            Mock -ModuleName $ModuleName Get-Content { @('11111111-1111-1111-1111-111111111111', '2099010100') }
            $result = Invoke-O365EndpointService -tenantName 'contoso'
            $result | Should -BeNullOrEmpty
        }

        It 'downloads anyway with -ForceLatest even if the cache is current' {
            Mock -ModuleName $ModuleName Get-Content { @('11111111-1111-1111-1111-111111111111', '2099010100') }
            $result = Invoke-O365EndpointService -tenantName 'contoso' -ForceLatest
            @($result).Count | Should -Be 6
        }
    }

    Context 'error handling' {

        BeforeAll {
            Mock -ModuleName $ModuleName Test-Path   { $true }
            Mock -ModuleName $ModuleName Get-Content  { @('11111111-1111-1111-1111-111111111111', '0000000000') }
            Mock -ModuleName $ModuleName Out-File     { }
            Mock -ModuleName $ModuleName Start-Sleep  { }   # skip retry back-off delays
        }

        It 'throws a clear error when the version service is unreachable' {
            Mock -ModuleName $ModuleName Invoke-RestMethod { throw 'network down' }
            { Invoke-O365EndpointService -tenantName 'contoso' } |
                Should -Throw '*Unable to determine the latest Office 365 endpoint version*'
        }

        It "throws when the service returns no 'latest' version" {
            Mock -ModuleName $ModuleName Invoke-RestMethod { [pscustomobject]@{ latest = '' } }
            { Invoke-O365EndpointService -tenantName 'contoso' } |
                Should -Throw "*no 'latest' version*"
        }

        It 'throws a clear error when the endpoints download fails' {
            Mock -ModuleName $ModuleName Invoke-RestMethod {
                if ($Uri -like '*/version/*') { [pscustomobject]@{ latest = '2099010100' } }
                else { throw 'boom' }
            }
            { Invoke-O365EndpointService -tenantName 'contoso' -ForceLatest } |
                Should -Throw '*Unable to download the Office 365 endpoints*'
        }

        It 'fails fast on HTTP 429 without retrying and surfaces the Retry-After hint' {
            Mock -ModuleName $ModuleName Invoke-RestMethod {
                $resp = [pscustomobject]@{ StatusCode = 429; Headers = @{ 'Retry-After' = '3600' } }
                $ex = [System.Exception]::new('Too Many Requests')
                Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $resp
                throw $ex
            }
            { Invoke-O365EndpointService -tenantName 'contoso' } |
                Should -Throw '*rate limited (HTTP 429)*Retry after 3600*'

            # the version call is where the 429 is raised; it must NOT be retried
            Should -Invoke -ModuleName $ModuleName Invoke-RestMethod -Times 1 -Exactly
            Should -Invoke -ModuleName $ModuleName Start-Sleep -Times 0 -Exactly
        }

        It 'gives generic guidance on HTTP 429 when no Retry-After header is present' {
            Mock -ModuleName $ModuleName Invoke-RestMethod {
                $resp = [pscustomobject]@{ StatusCode = 429; Headers = @{} }
                $ex = [System.Exception]::new('Too Many Requests')
                Add-Member -InputObject $ex -NotePropertyName Response -NotePropertyValue $resp
                throw $ex
            }
            { Invoke-O365EndpointService -tenantName 'contoso' } |
                Should -Throw '*rate limited (HTTP 429)*Wait about an hour*'
        }
    }

    Context 'parameters' {
        It 'requires tenantName' {
            (Get-Command Invoke-O365EndpointService).Parameters['tenantName'].Attributes.Mandatory |
                Should -Contain $true
        }

        It 'restricts Instance to the documented service instances' {
            $valid = (Get-Command Invoke-O365EndpointService).Parameters['Instance'].Attributes.ValidValues
            $valid | Should -Contain 'Worldwide'
            $valid | Should -Contain 'China'
            $valid | Should -Contain 'USGovDoD'
            $valid | Should -Contain 'USGovGCCHigh'
        }

        It 'rejects an unknown instance' {
            { Invoke-O365EndpointService -tenantName 'contoso' -Instance 'Mars' } | Should -Throw
        }

        It 'restricts ServiceAreas to the documented service areas' {
            $valid = (Get-Command Invoke-O365EndpointService).Parameters['ServiceAreas'].Attributes.ValidValues
            $valid | Should -Contain 'Common'
            $valid | Should -Contain 'Exchange'
            $valid | Should -Contain 'SharePoint'
            $valid | Should -Contain 'Skype'
        }

        It 'rejects an unknown service area' {
            { Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas 'Teams' } | Should -Throw
        }
    }
}
