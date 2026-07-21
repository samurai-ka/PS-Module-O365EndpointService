#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates Merge-O365EndpointService by combining the live Office 365 endpoints with the
    custom endpoints from ExampleEndpoints1.json and ExampleEndpoints2.json.

.DESCRIPTION
    Merge-O365EndpointService takes EndpointSet objects from the pipeline (here: the output of
    Invoke-O365EndpointService) and merges them with endpoints stored in one or more JSON files
    passed via -Path. The result is a single collection you can filter, export or save.

    This script:
      1. Imports the module from the repository root (one level up from this Examples folder).
      2. Fetches the current Office 365 "Worldwide" endpoints.
      3. Merges them with the two example JSON files that live next to this script.
      4. Shows the injected demo endpoints and the combined total.

.PARAMETER TenantName
    Your Office 365 tenant name (used to fill in tenant placeholders in the returned URLs).
    Any value works for this demo; it defaults to 'contoso'.

.EXAMPLE
    .\Merge-Example.ps1

.EXAMPLE
    .\Merge-Example.ps1 -TenantName 'contoso'
#>
[CmdletBinding()]
param(
    [string]$TenantName = 'contoso'
)

# Import the module from the repository root (this script lives in .\Examples).
$repoRoot       = Split-Path -Parent $PSScriptRoot
$moduleManifest = Join-Path -Path $repoRoot -ChildPath 'O365EndpointFunctions.psd1'
Import-Module $moduleManifest -Force

# The two example endpoint files sit next to this script.
$exampleFiles = @(
    Join-Path -Path $PSScriptRoot -ChildPath 'ExampleEndpoints1.json'
    Join-Path -Path $PSScriptRoot -ChildPath 'ExampleEndpoints2.json'
)

Write-Host "Fetching Office 365 endpoints and merging with example files..." -ForegroundColor Cyan

# Fetch the live endpoints and pipe them into Merge-O365EndpointService together with the
# custom endpoints from the JSON files. -ForceLatest makes sure we always get data for the demo.
$merged = Invoke-O365EndpointService -TenantName $TenantName -ForceLatest |
    Merge-O365EndpointService -Path $exampleFiles

# Show what came from the example files (the demo entries use these service areas).
Write-Host "`nInjected demo endpoints (from the JSON files):" -ForegroundColor Green
$merged |
    Where-Object serviceArea -in 'DemoServiceUrl', 'DemoServiceIp' |
    Format-Table id, serviceArea, protocol, uri, tcpPort, udpPort, category -AutoSize

Write-Host "Totals:" -ForegroundColor Green
"  Office 365 + custom endpoints : {0}" -f $merged.Count
"  From ExampleEndpoints*.json   : {0}" -f (@($merged | Where-Object serviceArea -in 'DemoServiceUrl', 'DemoServiceIp').Count)

# The merged collection is just EndpointSet objects - from here you could, for example:
#   $merged | Where-Object protocol -eq 'url' | Export-O365ProxyPacFile | Out-File .\o365.pac
#   $merged | ConvertTo-Json | Out-File .\merged-endpoints.json
