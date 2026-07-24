<#
    Invoke-O365EndpointService - usage examples (copy & paste)

    This file is NOT meant to be run as a script. It is a collection of individual
    PowerShell command-line snippets. Copy a block into your console and run it.

    Run the "Setup" block first - it imports the module and fetches the endpoints once
    into $endpoints, which the later examples reuse.

    EndpointSet properties you can filter/select on:
        id, serviceArea, serviceAreaDisplayName, protocol (url|ip), uri,
        tcpPort, udpPort, category (Optimize|Allow|Default), expressRoute, required, notes
#>


# ============================================================================
# Setup - run this first
# ============================================================================

# Import the module (adjust the path; run from the repository root, or use the installed module)
Import-Module .\O365EndpointFunctions

# Get the current Office 365 "Worldwide" endpoints once and keep them in $endpoints.
# -ForceLatest ignores the local version cache so you always get data.
$endpoints = Invoke-O365EndpointService -tenantName 'contoso' -ForceLatest

# How many did we get?
$endpoints.Count


# ============================================================================
# Basic views
# ============================================================================

# Everything as a table
$endpoints | Format-Table -AutoSize

# Only the columns that usually matter
$endpoints | Format-Table serviceArea, protocol, uri, tcpPort, udpPort, category -AutoSize

# Only URL endpoints
$endpoints | Where-Object { $_.protocol -eq 'url' } | Format-Table -AutoSize

# Only IP endpoints
$endpoints | Where-Object { $_.protocol -eq 'ip' } | Format-Table -AutoSize


# ============================================================================
# Filtering
# ============================================================================

# Only the "Optimize" category (the highest-priority traffic)
$endpoints | Where-Object { $_.category -eq 'Optimize' } | Format-Table -AutoSize

# "Optimize" or "Allow" - the categories you typically send direct / bypass the proxy
$endpoints | Where-Object { $_.category -in 'Optimize', 'Allow' } | Format-Table -AutoSize

# Everything for a single workload (service area)
$endpoints | Where-Object { $_.serviceArea -eq 'Exchange' } | Format-Table -AutoSize

# Only endpoints that are required for Office 365 to work
$endpoints | Where-Object { $_.required } | Format-Table serviceArea, uri, tcpPort -AutoSize

# Only endpoints routed over ExpressRoute
$endpoints | Where-Object { $_.expressRoute } | Format-Table serviceArea, uri, category -AutoSize

# Only endpoints that use TCP 443
$endpoints | Where-Object { $_.tcpPort -eq 443 } | Format-Table uri, protocol, category -AutoSize

# Endpoints that use a UDP port (e.g. Teams media)
$endpoints | Where-Object { $_.udpPort } | Format-Table serviceArea, uri, udpPort -AutoSize


# ============================================================================
# Selecting, sorting, grouping, counting
# ============================================================================

# Unique URLs only, sorted
$endpoints | Where-Object { $_.protocol -eq 'url' } |
    Select-Object -ExpandProperty uri -Unique | Sort-Object

# Unique IP ranges only
$endpoints | Where-Object { $_.protocol -eq 'ip' } |
    Select-Object -ExpandProperty uri -Unique | Sort-Object

# How many endpoints per service area?
$endpoints | Group-Object serviceArea | Select-Object Count, Name | Sort-Object Count -Descending

# How many per category?
$endpoints | Group-Object category | Select-Object Count, Name

# Which distinct TCP ports appear?
$endpoints | Where-Object { $_.tcpPort } |
    Select-Object -ExpandProperty tcpPort -Unique | Sort-Object


# ============================================================================
# Export: Ghostery enterprise policy
# ============================================================================

# URL endpoints as a Ghostery trustedDomains policy (protection paused for these domains)
$endpoints | Where-Object { $_.protocol -eq 'url' } |
    Export-O365Ghostery -TrustedDomains

# URL endpoints as Ghostery customFilters allowlist rules (@@||domain^)
$endpoints | Where-Object { $_.protocol -eq 'url' } |
    Export-O365Ghostery -Whitelist

# Save a trustedDomains policy to a file
$endpoints | Where-Object { $_.protocol -eq 'url' } |
    Export-O365Ghostery -TrustedDomains | Out-File .\ghostery-policy.json -Encoding utf8


# ============================================================================
# Export: proxy PAC file
# ============================================================================

# Build a PAC "direct" block for the Optimize/Allow URLs (filter to unique URLs first)
$endpoints |
    Where-Object { $_.protocol -eq 'url' -and $_.category -in 'Optimize', 'Allow' } |
    Select-Object uri -Unique |
    Export-O365ProxyPacFile

# Same, but add inline comments and write it to a .pac file
$endpoints |
    Where-Object { $_.protocol -eq 'url' -and $_.category -in 'Optimize', 'Allow' } |
    Export-O365ProxyPacFile -Comments | Out-File .\o365.pac -Encoding ascii


# ============================================================================
# Export: JSON / CSV
# ============================================================================

# Save the whole set as JSON (re-loadable later via Merge-O365EndpointService)
$endpoints | ConvertTo-Json | Out-File .\o365-endpoints.json -Encoding utf8

# Export to CSV with Export-Csv
$endpoints | Export-Csv .\o365-endpoints.csv -NoTypeInformation -Encoding utf8


# ============================================================================
# Other instances and server-side filtering
# ============================================================================

# US Government GCC High cloud
Invoke-O365EndpointService -tenantName 'contoso' -Instance USGovGCCHigh -ForceLatest |
    Format-Table serviceArea, uri, category -AutoSize

# China (21Vianet) cloud
Invoke-O365EndpointService -tenantName 'contoso' -Instance China -ForceLatest |
    Format-Table serviceArea, uri, category -AutoSize

# Only fetch Exchange + SharePoint from the service (Common is always included).
# Use -ForceLatest when changing the filter, because the cache only tracks the version.
Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas Exchange, SharePoint -ForceLatest |
    Format-Table serviceArea, uri -AutoSize

# Include IPv6 ranges (excluded by default)
Invoke-O365EndpointService -tenantName 'contoso' -IPv6 -ForceLatest |
    Where-Object { $_.uri -like '*:*' } | Format-Table uri, serviceArea -AutoSize


# ============================================================================
# Merge with your own custom endpoints
# ============================================================================

# Merge the live endpoints with the two example JSON files in this folder
$endpoints |
    Merge-O365EndpointService -Path .\Examples\ExampleEndpoints1.json, .\Examples\ExampleEndpoints2.json |
    Format-Table serviceArea, protocol, uri, tcpPort -AutoSize

# Merge, then hand the combined set straight to a PAC file
$endpoints |
    Merge-O365EndpointService -Path .\Examples\ExampleEndpoints1.json |
    Where-Object { $_.protocol -eq 'url' } |
    Export-O365ProxyPacFile | Out-File .\o365-with-custom.pac -Encoding ascii
