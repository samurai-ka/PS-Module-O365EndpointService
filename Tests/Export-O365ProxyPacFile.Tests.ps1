# Tests/Export-O365ProxyPacFile.Tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot\..\O365EndpointFunctions\O365EndpointFunctions.psd1" -Force
}

Describe 'Export-O365ProxyPacFile' {

    It 'emits the fixed header and DIRECT footer to the pipeline' {
        $out = [pscustomobject]@{ Uri = '*.a.com' } | Export-O365ProxyPacFile

        $out[0]  | Should -Be '// Office 365 entries'
        $out[1]  | Should -Be '// If the hostname matches, send direct.'
        $out[-1] | Should -Be 'return "DIRECT";'
    }

    It 'writes strings (pipeline output, not host)' {
        $out = [pscustomobject]@{ Uri = '*.a.com' } | Export-O365ProxyPacFile
        $out | Should -BeOfType [string]
    }

    It 'produces a valid if-block: only the last match closes the if() and earlier ones chain with ||' {
        $out = @(
            [pscustomobject]@{ Uri = '*.a.com' }
            [pscustomobject]@{ Uri = '*.b.com' }
            [pscustomobject]@{ Uri = '*.c.com' }
        ) | Export-O365ProxyPacFile

        $out | Should -Contain 'if (isPlainHostName(host) ||'
        $out | Should -Contain 'shExpMatch(host, "*.a.com") ||'
        $out | Should -Contain 'shExpMatch(host, "*.b.com") ||'
        # last entry terminates the if() with a closing paren, no trailing ||
        $out | Should -Contain 'shExpMatch(host, "*.c.com"))'
    }

    It 'degrades to a bare isPlainHostName check when no entries are piped' {
        $out = @() | Export-O365ProxyPacFile
        $out | Should -Contain 'if (isPlainHostName(host))'
        $out | Should -Not -Contain 'if (isPlainHostName(host) ||'
    }

    It 'appends an inline comment when -Comments is set' {
        $out = [pscustomobject]@{
            Uri                    = '*.a.com'
            ServiceAreaDisplayName = 'Exchange'
            Category               = 'Optimize'
            Notes                  = 'core'
        } | Export-O365ProxyPacFile -Comments

        ($out -join "`n") | Should -Match 'Exchange - Optimize - core'
    }

    It 'does not add comments by default' {
        $out = [pscustomobject]@{
            Uri                    = '*.a.com'
            ServiceAreaDisplayName = 'Exchange'
        } | Export-O365ProxyPacFile

        ($out -join "`n") | Should -Not -Match '//\s+Exchange'
    }
}
