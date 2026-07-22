# Tests/Publishing.Tests.ps1
#
# Verifies the module meets the PowerShell Gallery publishing requirements described at
# https://learn.microsoft.com/powershell/gallery/how-to/publishing-packages/publishing-a-package
#
#   - PSScriptAnalyzer reports NO errors on the shipped files (a hard blocker for the Gallery,
#     which runs PSScriptAnalyzer on every publish) and NO warnings (which should be addressed).
#   - Test-ModuleManifest succeeds.
#   - Required metadata is present: Author, Description, ModuleVersion.
#   - Recommended metadata is present: Tags, ProjectUri, LicenseUri.
#
# Only the files that actually get published are analyzed (manifest, root module, Public/,
# Private/) - the O365EndpointFunctions module folder that release.yml publishes.

BeforeAll {
    $script:RepoRoot     = Split-Path -Parent $PSScriptRoot
    $script:ModuleRoot   = Join-Path $RepoRoot 'O365EndpointFunctions'
    $script:ManifestPath = Join-Path $ModuleRoot 'O365EndpointFunctions.psd1'
    $script:SettingsPath = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'

    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Install-Module PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module PSScriptAnalyzer

    $shipped = @(
        $ManifestPath
        (Join-Path $ModuleRoot 'O365EndpointFunctions.psm1')
        (Join-Path $ModuleRoot 'Public')
        (Join-Path $ModuleRoot 'Private')
    )
    $script:Analysis = $shipped | ForEach-Object {
        Invoke-ScriptAnalyzer -Path $_ -Recurse -Settings $SettingsPath
    }

    $script:Manifest = Import-PowerShellDataFile -Path $ManifestPath
    $script:PSData   = $Manifest.PrivateData.PSData
}

Describe 'PowerShell Gallery publishing requirements' {

    Context 'PSScriptAnalyzer' {
        It 'reports no errors on the shipped module files' {
            $errors = @($Analysis | Where-Object Severity -eq 'Error')
            $detail = ($errors | ForEach-Object { '{0}:{1} {2}' -f $_.ScriptName, $_.Line, $_.RuleName }) -join "`n"
            $errors | Should -HaveCount 0 -Because "PSScriptAnalyzer errors block Gallery publishing:`n$detail"
        }

        It 'reports no warnings on the shipped module files' {
            $warnings = @($Analysis | Where-Object Severity -eq 'Warning')
            $detail = ($warnings | ForEach-Object { '{0}:{1} {2}' -f $_.ScriptName, $_.Line, $_.RuleName }) -join "`n"
            $warnings | Should -HaveCount 0 -Because "PSScriptAnalyzer warnings should be addressed before publishing:`n$detail"
        }
    }

    Context 'Module manifest' {
        It 'passes Test-ModuleManifest' {
            { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'declares a non-empty Author (required)' {
            $Manifest.Author | Should -Not -BeNullOrEmpty
        }

        It 'declares a non-empty Description (required)' {
            $Manifest.Description | Should -Not -BeNullOrEmpty
        }

        It 'declares a valid ModuleVersion (required)' {
            $Manifest.ModuleVersion | Should -Not -BeNullOrEmpty
            { [version]$Manifest.ModuleVersion } | Should -Not -Throw
        }
    }

    Context 'Manifest validated with Test-ModuleManifest' {
        # The docs require Test-ModuleManifest to be run for every module before publishing:
        # it fails if the manifest cannot be processed (which would block publishing), and its
        # output exposes the resolved metadata the Gallery reads.
        BeforeAll {
            $script:moduleInfo = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        }

        It 'returns a PSModuleInfo object' {
            $moduleInfo | Should -BeOfType [System.Management.Automation.PSModuleInfo]
        }

        It 'resolves the module name' {
            $moduleInfo.Name | Should -Be 'O365EndpointFunctions'
        }

        It 'resolves a valid Version' {
            $moduleInfo.Version | Should -BeOfType [version]
        }

        It 'resolves the RootModule to O365EndpointFunctions.psm1' {
            $moduleInfo.RootModule | Should -Be 'O365EndpointFunctions.psm1'
        }

        It 'has a non-empty Author (required by the Gallery)' {
            $moduleInfo.Author | Should -Not -BeNullOrEmpty
        }

        It 'has a non-empty Description (required by the Gallery)' {
            $moduleInfo.Description | Should -Not -BeNullOrEmpty
        }

        It 'requires PowerShell 7.0 or higher' {
            $moduleInfo.PowerShellVersion | Should -BeGreaterOrEqual ([version]'7.0')
        }

        It 'surfaces Tags, ProjectUri and LicenseUri' {
            $moduleInfo.Tags       | Should -Not -BeNullOrEmpty
            $moduleInfo.ProjectUri | Should -Not -BeNullOrEmpty
            $moduleInfo.LicenseUri | Should -Not -BeNullOrEmpty
        }

        It 'exports the expected public functions' {
            $exported = $moduleInfo.ExportedFunctions.Keys
            $exported | Should -Contain 'Invoke-O365EndpointService'
            $exported | Should -Contain 'Export-O365ProxyPacFile'
            $exported | Should -Contain 'Export-O365Ghostery'
            $exported | Should -Contain 'Merge-O365EndpointService'
        }
    }

    Context 'Recommended Gallery metadata' {
        It 'declares Tags' {
            $PSData.Tags | Should -Not -BeNullOrEmpty
        }

        It 'declares a ProjectUri' {
            $PSData.ProjectUri | Should -Not -BeNullOrEmpty
        }

        It 'declares a LicenseUri' {
            $PSData.LicenseUri | Should -Not -BeNullOrEmpty
        }
    }
}
