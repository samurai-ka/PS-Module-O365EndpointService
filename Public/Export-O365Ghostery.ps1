function Export-O365Ghostery {
    <#
    .SYNOPSIS
        Exports endpoint URLs as a Ghostery enterprise policy (JSON).

    .DESCRIPTION
        Takes endpoint objects (typically produced by Invoke-O365EndpointService) and emits a
        Ghostery enterprise policy document to the pipeline as JSON, so it can be redirected to
        a policy file. The URLs are mapped onto the policy keys documented in the Ghostery
        enterprise policy reference:

          - -TrustedDomains  -> "trustedDomains": an array of bare domains where Ghostery
                                protection is paused by default (subdomains are automatically
                                included, so "office.com" also covers "outlook.office.com").
          - -Whitelist       -> "customFilters": an array of allowlist ("exception") filter
                                rules of the form "@@||domain^". Ghostery has no dedicated
                                "exceptions"/"whitelist" key; allowlisting is expressed through
                                customFilters exception rules.

        If both switches are supplied, both keys are written to a single policy object. If
        neither switch is supplied, -TrustedDomains is assumed.

        Each URI is normalised before export: any scheme (http://, https://) and path is
        stripped, and a leading wildcard ("*.") is removed because Ghostery matches subdomains
        automatically. Duplicate domains are removed (case-insensitive) while preserving order.

    .PARAMETER Uri
        The host/URL to export, for example "*.office.com" or "outlook.office365.com".
        Accepted from the pipeline by property name; the EndpointSet.uri property binds to it.

    .PARAMETER TrustedDomains
        Export the URLs as the "trustedDomains" array (protection paused for these domains).
        This is the default when neither switch is specified.

    .PARAMETER Whitelist
        Export the URLs as "customFilters" allowlist exception rules ("@@||domain^").

    .OUTPUTS
        System.String. The Ghostery policy document rendered as JSON.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Export-O365Ghostery -TrustedDomains | Out-File .\ghostery-policy.json -Encoding utf8

        Exports the current Office 365 endpoints as a trustedDomains policy.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Where-Object protocol -eq 'url' |
            Export-O365Ghostery -Whitelist

        Exports URL endpoints as customFilters allowlist exception rules.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Export-O365Ghostery -TrustedDomains -Whitelist

        Produces a single policy containing both trustedDomains and customFilters.

    .LINK
        Invoke-O365EndpointService

    .LINK
        https://www.ghostery.com/enterprise-privacy-solutions/documentation/policy-reference
    #>
    [cmdletbinding()]
    param (
        # The host/URL to export as a Ghostery domain.
        [parameter( Position = 0,
                    Mandatory = $true,
                    ValueFromPipelineByPropertyName)]
        [Alias('Url','Endpoint')]
        [string]$Uri,

        # Export the URLs as the trustedDomains array (default).
        [parameter(Mandatory = $false)]
        [switch]$TrustedDomains,

        # Export the URLs as customFilters allowlist exception rules.
        [parameter(Mandatory = $false)]
        [switch]$Whitelist
    )

    begin {
        # case-insensitive de-duplication while preserving insertion order
        $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $domains = [System.Collections.Generic.List[string]]::new()
    }

    process {
        $domain = $Uri.Trim()
        $domain = $domain -replace '^[a-zA-Z][a-zA-Z0-9+.-]*://', ''   # strip scheme
        $domain = $domain.Split('/')[0]                                # strip any path
        $domain = $domain -replace '^\*\.', ''                         # strip leading wildcard

        if ($domain -and $seen.Add($domain)) {
            $domains.Add($domain)
        }
    }

    end {
        # default to trustedDomains when neither switch is given
        $includeTrusted   = $TrustedDomains.IsPresent -or (-not $Whitelist.IsPresent)
        $includeWhitelist = $Whitelist.IsPresent

        $policy = [ordered]@{}

        if ($includeTrusted) {
            $policy.trustedDomains = @($domains)
        }
        if ($includeWhitelist) {
            $policy.customFilters = @($domains | ForEach-Object { '@@||{0}^' -f $_ })
        }

        $policy | ConvertTo-Json -Depth 3
    }
}
