# O365EndpointFunctions

[![Tests](https://img.shields.io/github/actions/workflow/status/samurai-ka/PS-Module-O365EndpointService/development.yml?branch=master&label=tests&logo=github)](https://github.com/samurai-ka/PS-Module-O365EndpointService/actions/workflows/development.yml)
[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)

Microsoft publishes the IP addresses and URLs that Office 365 / Microsoft 365 depends on through the [Microsoft 365 IP Address and URL web service](https://learn.microsoft.com/microsoft-365/enterprise/microsoft-365-ip-web-service). Consuming that service directly in PowerShell is awkward: the data comes back as nested *endpoint sets*, ports are comma-separated strings, and you have to track the service version yourself to know when anything changed.

**O365EndpointFunctions** turns that web service into flat, strongly-typed PowerShell objects that you can filter, sort and export like any other pipeline data. Every endpoint becomes a single object with properties such as `serviceArea`, `protocol`, `uri`, `tcpPort`, `category` and `required`. The module caches the published version, so it only downloads new data when Microsoft actually releases an update.

## What you can do with it

- Keep firewall allow-lists and proxy bypass-lists for Office 365 traffic up to date.
- Generate a proxy auto-config (PAC) file that routes Office 365 straight out (`DIRECT`).
- Produce a [Ghostery](https://www.ghostery.com/enterprise-privacy-solutions/documentation/policy-reference) enterprise policy so tracker protection leaves Office 365 alone.
- Merge the official endpoints with your own custom entries (for example Azure services) into one list.

It supports the **Worldwide**, **China** (21Vianet) and **US Government** (GCC High, DoD) cloud instances and requires **PowerShell 7 or later**.

## Installation

Install the module from the PowerShell Gallery:

```powershell
Install-Module O365EndpointFunctions -Repository PSGallery
```

## Using the Service

List every cmdlet the module provides:

```powershell
Get-Command -Module O365EndpointFunctions
```

All cmdlets ship with comment-based help, so you can look up detailed information, parameters and examples at any time:

```powershell
Get-Help Invoke-O365EndpointService -Full
```

### Quickstart

```powershell
# Fetch the current Office 365 "Worldwide" endpoints into a variable
$endpoints = Invoke-O365EndpointService -tenantName 'contoso' -ForceLatest

# Show them as a table
$endpoints | Format-Table serviceArea, protocol, uri, tcpPort, udpPort, category -AutoSize

# Filter to a single workload (service area) and only its URL endpoints
$endpoints | Where-Object { $_.serviceArea -eq 'Exchange' -and $_.protocol -eq 'url' } | Format-Table -AutoSize
```

Replace `contoso` with your own Office 365 tenant name — the service inserts it into the URLs that contain a tenant placeholder.

### Parameters

- **tenantName** *(mandatory)* — your Office 365 tenant name, inserted into URLs that contain a tenant placeholder.
- **Instance** — the cloud instance to query: `Worldwide` (default), `China`, `USGovDoD` or `USGovGCCHigh`.
- **ServiceAreas** — limit the result to one or more workloads: `Common`, `Exchange`, `SharePoint`, `Skype`. `Common` is always included.
- **IPv6** — also return IPv6 ranges. By default only IPv4 is returned.
- **ForceLatest** — download the endpoints even when the cached version indicates the local data is already current.

## Examples

Because every endpoint is a plain object, you shape the results with standard PowerShell. The snippets below assume the `$endpoints` variable from the [Quickstart](#quickstart). A larger, copy-and-paste collection lives in [Examples/Invoke-O365EndpointService.Examples.ps1](Examples/Invoke-O365EndpointService.Examples.ps1).

Only URL endpoints:

```powershell
$endpoints | Where-Object { $_.protocol -eq 'url' } | Format-Table -AutoSize
```

Only the `Optimize` and `Allow` categories — the traffic you typically send direct or bypass the proxy for:

```powershell
$endpoints | Where-Object { $_.category -in 'Optimize', 'Allow' } | Format-Table -AutoSize
```

Everything for a single workload:

```powershell
$endpoints | Where-Object { $_.serviceArea -eq 'Exchange' } | Format-Table -AutoSize
```

Unique URLs only, sorted:

```powershell
$endpoints | Where-Object { $_.protocol -eq 'url' } | Select-Object -ExpandProperty uri -Unique | Sort-Object
```

Count endpoints per service area:

```powershell
$endpoints | Group-Object serviceArea | Select-Object Count, Name | Sort-Object Count -Descending
```

Query a different cloud instance, or limit the download to specific workloads:

```powershell
Invoke-O365EndpointService -tenantName 'contoso' -Instance USGovGCCHigh -ForceLatest
Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas Exchange, SharePoint -ForceLatest
```

## Exporting a proxy PAC file

You can build a proxy auto-config (PAC) "direct" block for Office 365 URLs. Filter to the `Optimize`/`Allow` URLs, reduce them to unique entries and export:

```powershell
$endpoints |
    Where-Object { $_.protocol -eq 'url' -and $_.category -in 'Optimize', 'Allow' } |
    Select-Object uri -Unique |
    Export-O365ProxyPacFile
```

The result is written to the pipeline, so you can redirect it to a file. Add `-Comments` to annotate each line with the service area, category and notes:

```powershell
$endpoints |
    Where-Object { $_.protocol -eq 'url' -and $_.category -in 'Optimize', 'Allow' } |
    Export-O365ProxyPacFile -Comments | Out-File .\o365.pac -Encoding ascii
```

`Export-O365ProxyPacFile` does not remove duplicate URLs itself, so filter with `Select-Object uri -Unique` first if you want each host only once.

## Exporting a Ghostery policy

If you use [Ghostery](https://www.ghostery.com/enterprise-privacy-solutions/documentation/policy-reference) in your enterprise, you can export the endpoints as a Ghostery policy so that Office 365 traffic is not touched by the tracker protection. The policy is emitted as JSON to the pipeline, ready to be saved to a policy file.

Two switches control how the domains are allowed (supply both to write both keys into one policy):

- **-TrustedDomains** — writes the `trustedDomains` array. Ghostery pauses its protection for these domains and automatically includes their subdomains. This is the default when neither switch is given.
- **-Whitelist** — writes `customFilters` allowlist exception rules of the form `@@||domain^`. Ghostery has no dedicated exceptions key, so allowlisting is expressed through `customFilters`.

Each URL is normalised before it is written (the scheme, any path and a leading `*.` wildcard are stripped, because Ghostery matches subdomains on its own) and duplicate domains are removed automatically.

Export the URLs as trusted domains into a policy file:

```powershell
$endpoints | Where-Object { $_.protocol -eq 'url' } | Export-O365Ghostery -TrustedDomains | Out-File .\ghostery-policy.json -Encoding utf8
```

Export the same URLs as allowlist exception rules instead:

```powershell
$endpoints | Where-Object { $_.protocol -eq 'url' } | Export-O365Ghostery -Whitelist
```

## Merging endpoints

There are plenty of other URLs and IP ranges you may want to configure that the Microsoft web service does not return (for example Azure endpoints), or endpoints you feel are missing. `Merge-O365EndpointService` combines the live endpoints with your own entries stored in one or more JSON files:

```powershell
$endpoints |
    Merge-O365EndpointService -Path .\Examples\ExampleEndpoints1.json, .\Examples\ExampleEndpoints2.json |
    Format-Table serviceArea, protocol, uri, tcpPort -AutoSize
```

See the [Examples/](Examples/) folder for the JSON format. There is no formal JSON schema yet, so take care when creating your own files.
