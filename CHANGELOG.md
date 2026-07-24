# Changelog

Using the changelog schema https://keepachangelog.com/en/0.3.0/

## [1.2.1] - 2026-07-24
### Module
#### Changed
* Adopted Semantic Versioning ([semver.org](https://semver.org)). The version format is now `Major.Minor.Patch`; the CI version bump advances the patch only. Bump major/minor manually in the manifest.

## [1.1.2607.2] - 2026-07-20
### Module
#### Fixed
* RootModule was not set in the manifest, so importing the .psd1 exported no commands

### Cmdlet: Invoke-O365EndpointService
#### Added
* Comment-based help (Get-Help support)
* Robust REST handling: request timeout, retry of transient failures (skipping non-retryable 4xx) and clear, contextual error messages for the version and endpoints calls

#### Changed
* Tenant name is now URL-encoded before it is passed to the endpoints web service
* Corrupt or truncated cache files are tolerated (client ID / version are regenerated)

#### Fixed
* Version cache was written before the endpoints were fetched, so a failed download left the cache marked up-to-date (cache poisoning)

### Cmdlet: Export-O365ProxyPacFile
#### Added
* Comment-based help (Get-Help support)

#### Fixed
* Output now goes to the pipeline instead of the host, so the result can be redirected to a .pac file
* Generated a valid PAC if-block (the last match now closes the if() instead of leaving a trailing ||)

### Cmdlet: Merge-O365EndpointService
#### Added
* Comment-based help (Get-Help support)

### Cmdlet: Export-O365Ghostery
#### Added
* New cmdlet that exports endpoint URLs as a Ghostery enterprise policy (JSON)
* -TrustedDomains switch exports the URLs as the Ghostery trustedDomains array
* -Whitelist switch exports the URLs as customFilters allowlist exception rules (@@||domain^)

## [1.1.2607.1] - 2026-07-16
### Cmdlet: Invoke-O365EndpointService
#### Changed
* Cross-platform path handling using Join-Path and [Environment]::GetFolderPath

#### Fixed
* Typo in the data directory path (Invoke-O365EnpointService)
* [cmdletbinding()] was declared inside the param() block

### Cmdlet: Test-UrlEndpoint
#### Changed
* Replaced Test-NetConnection with a System.Net.Sockets.TcpClient connection test

#### Fixed
* Default value for the [int32] tcpPort parameter was a string ("80")

## [1.0.1905.3] - 2019-05-15
### Cmdlet: Merge-O365EndpointService
#### Added
* Added the new cmdlet to the module

## [1.0.1905.2] - 2019-05-03
### Cmdlet: Invoke-O365EndpointService
#### Fixed
* Typographical error in the function name fixed

## [1.0.1905.1] - 2019-05-03
#### Added
* New Changelog file (this)

### Cmdlet: Export-O365ProxyPacFile
#### Added
* New Comments switch

#### Changed
* Reworked Functions Parameter