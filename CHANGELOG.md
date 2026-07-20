# Changelog

Using the changelog schema https://keepachangelog.com/en/0.3.0/

## [1.1.2607.2] - 2026-07-20
### Module
#### Fixed
* RootModule was not set in the manifest, so importing the .psd1 exported no commands

### Cmdlet: Invoke-O365EndpointService
#### Added
* Comment-based help (Get-Help support)

#### Fixed
* Version cache was written before the endpoints were fetched, so a failed download left the cache marked up-to-date (cache poisoning)

### Cmdlet: Export-O365ProxyPacFile
#### Fixed
* Output now goes to the pipeline instead of the host, so the result can be redirected to a .pac file
* Generated a valid PAC if-block (the last match now closes the if() instead of leaving a trailing ||)

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