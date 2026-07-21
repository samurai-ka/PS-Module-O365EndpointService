function Export-O365ProxyPacFile {
    <#
    .SYNOPSIS
        Generates a proxy auto-config (PAC) "if" block that sends Office 365 hosts DIRECT.

    .DESCRIPTION
        Takes endpoint objects (typically produced by Invoke-O365EndpointService) and emits
        a PAC snippet to the pipeline. Each URI becomes a shExpMatch(host, "...") test; when
        the host matches, the block returns "DIRECT" so Office 365 traffic bypasses the proxy.

        The output is written to the pipeline (not the host), so it can be redirected to a
        file. The snippet is a bare if-block: wrap it in your own FindProxyForURL function
        and add the proxy fallback for the non-matching case.

    .PARAMETER ServiceArea
        The service area the endpoint belongs to (Common, Exchange, SharePoint, or Skype).
        Accepted from the pipeline for convenience; not written to the PAC output.

    .PARAMETER ServiceAreaDisplayName
        The friendly service area name. Used in the inline comment when -Comments is set.

    .PARAMETER Protocol
        The endpoint protocol (for example "url" or "ip"). Accepted for pipeline binding;
        not written to the PAC output.

    .PARAMETER Uri
        The host/URL to match, for example "*.office.com". Mandatory. This is the value
        emitted as shExpMatch(host, "<Uri>").

    .PARAMETER TcpPort
        TCP port(s) for the endpoint set. Accepted for pipeline binding; not written to
        the PAC output.

    .PARAMETER UdpPort
        UDP port(s) for the endpoint set. Accepted for pipeline binding; not written to
        the PAC output.

    .PARAMETER Category
        The connectivity category (Optimize, Allow, or Default). Used in the inline
        comment when -Comments is set.

    .PARAMETER ExpressRoute
        Whether the endpoint set is routed over ExpressRoute. Accepted for pipeline
        binding; not written to the PAC output.

    .PARAMETER Required
        Whether connectivity to the endpoint set is required. Accepted for pipeline
        binding; not written to the PAC output.

    .PARAMETER Notes
        Free-text notes about the endpoint set. Used in the inline comment when
        -Comments is set.

    .PARAMETER Comments
        Append an inline "// ServiceAreaDisplayName - Category - Notes" comment to each
        shExpMatch line. Uses the "Comments" parameter set.

    .OUTPUTS
        System.String. The lines of the generated PAC if-block.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Export-O365ProxyPacFile | Out-File .\o365.pac -Encoding ascii

        Generates the PAC snippet for the current endpoints and writes it to o365.pac.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Where-Object protocol -eq 'url' |
            Export-O365ProxyPacFile -Comments

        Produces the PAC block for URL endpoints only, with an inline comment on each line.

    .EXAMPLE
        Export-O365ProxyPacFile -Uri '*.office.com'

        Generates a minimal block for a single host.

    .LINK
        Invoke-O365EndpointService

    .LINK
        https://learn.microsoft.com/microsoft-365/enterprise/managing-office-365-endpoints
    #>
    [cmdletbinding()]
    [OutputType([string])]
    param (
        # Parameter help description
        [parameter( Position = 0,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [Alias('Service','Area')]
        [string]$ServiceArea,

        # The service area that this is part of: Common, Exchange, SharePoint, or Skype.
        [parameter( Position = 1,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName,
                    ParameterSetName = "Comments")]
        [Alias('ServiceName','Name','DisplayName','AreaName')]
        [string]$ServiceAreaDisplayName,

        [parameter( Position = 2,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [string]$Protocol,

        [parameter( Position = 3,
                    Mandatory = $true,
                    ValueFromPipelineByPropertyName)]
        [Alias('Url','Endpoint')]
        [string]$Uri,

        # TCP ports for the endpoint set. All ports elements are formatted as a comma-separated list of ports or
        # port ranges separated by a dash character (-). Ports apply to all IP addresses and all URLs in that endpoint set for that category. Omitted if blank.
        [parameter( Position = 4,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [Alias('Tcp')]
        [string]$TcpPort,

        # UDP ports for the IP address ranges in this endpoint set. Omitted if blank.
        [parameter( Position = 5,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [Alias('Udp')]
        [string]$UdpPort,

        # The connectivity category for the endpoint set. Valid values are Optimize, Allow, and Default. Required.
        [parameter( Position = 6,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName,
                    ParameterSetName = "Comments")]
        [ValidateSet('Default','Allow','Optimize')]
        [string]$Category,

        # True or False if this endpoint set is routed over ExpressRoute.
        [parameter( Position = 7,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [bool]$ExpressRoute,

        # True if this endpoint set is required to have connectivity for Office 365 to be supported. Omitted if false.
        [parameter( Position = 8,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [bool]$Required,

        # For optional endpoints, this text describes Office 365 functionality that will be missing if IP addresses or URLs
        # in this endpoint set cannot be accessed at the network layer. Omitted if blank.
        [parameter( Position = 9,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName,
                    ParameterSetName = "Comments")]
        [string]$Notes,

        # Enable to add comments
        [Parameter( Position = 10,
                    Mandatory = $false,
                    ValueFromPipelineByPropertyName = $false,
                    ParameterSetName = "Comments")]
                    [Alias('Comment')]
        [Switch]$Comments
    )
    Begin {
        # collect the entries so the last match line can be terminated correctly
        $entries = [System.Collections.Generic.List[object]]::new()
    }
    Process {
        if ($Comments -eq $true) {
            $CommentString = "`t// {0} - {1} - {2}" -f $ServiceAreaDisplayName,$Category,$Notes
        } else {
            $CommentString = ""
        }

        $entries.Add([pscustomobject]@{ Uri = $Uri; Comment = $CommentString })
    }
    End {
        # emit to the pipeline (not Out-Default) so the result can be redirected to a .pac file
        '// Office 365 entries'
        '// If the hostname matches, send direct.'

        if ($entries.Count -eq 0) {
            'if (isPlainHostName(host))'
        }
        else {
            'if (isPlainHostName(host) ||'
            for ($i = 0; $i -lt $entries.Count; $i++) {
                # the last match closes the if() with ')'; all others chain with '||'
                if ($i -eq ($entries.Count - 1)) { $terminator = ')' } else { $terminator = ' ||' }
                'shExpMatch(host, "{0}"){1}{2}' -f $entries[$i].Uri, $terminator, $entries[$i].Comment
            }
        }

        'return "DIRECT";'
    }
}
