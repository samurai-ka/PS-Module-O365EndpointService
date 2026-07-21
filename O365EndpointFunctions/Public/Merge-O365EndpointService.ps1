function Merge-O365EndpointService {
    <#
    .SYNOPSIS
        Merges endpoint objects from the pipeline with endpoints stored in JSON file(s).

    .DESCRIPTION
        Combines two sources of EndpointSet objects into a single collection:

          - Endpoints piped in (typically from Invoke-O365EndpointService), and
          - Endpoints previously saved to one or more JSON files, given via -Path.

        Each piped object is converted to an EndpointSet in the process block; after the
        pipeline is drained, every .json file in -Path is read (Get-Content | ConvertFrom-Json),
        its entries are converted to EndpointSet objects, and the full combined collection is
        returned. Files whose extension is not .json are ignored.

        No de-duplication is performed - if the same endpoint exists both in the pipeline and
        in a file, it appears twice in the result.

    .PARAMETER ServiceArea
        The service area the endpoint belongs to (Common, Exchange, SharePoint, or Skype).

    .PARAMETER ServiceAreaDisplayName
        The friendly service area name.

    .PARAMETER Protocol
        The endpoint protocol (for example "url" or "ip").

    .PARAMETER Uri
        The host/URL or IP range for the endpoint. Mandatory for pipeline input.

    .PARAMETER TcpPort
        TCP port(s) for the endpoint set.

    .PARAMETER UdpPort
        UDP port(s) for the endpoint set.

    .PARAMETER Category
        The connectivity category (Optimize, Allow, or Default).

    .PARAMETER ExpressRoute
        Whether the endpoint set is routed over ExpressRoute.

    .PARAMETER Required
        Whether connectivity to the endpoint set is required for Office 365.

    .PARAMETER Notes
        Free-text notes describing functionality lost if the endpoint is unreachable.

    .PARAMETER Path
        One or more paths to JSON files containing previously exported endpoints. Only files
        with a .json extension are read; other paths are ignored. Mandatory.

    .OUTPUTS
        EndpointSet. The combined collection of endpoints from the pipeline and the file(s).

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Merge-O365EndpointService -Path .\custom-endpoints.json

        Merges the current Office 365 endpoints with a custom set stored in a JSON file.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Merge-O365EndpointService -Path .\extra1.json, .\extra2.json |
            ConvertTo-Json | Out-File .\merged-endpoints.json

        Merges live endpoints with two JSON files and saves the combined result.

    .LINK
        Invoke-O365EndpointService
    #>
    [CmdletBinding()]
    [OutputType('EndpointSet')]
    param (
        # The immutable endpoint set ID; bound from the pipeline (e.g. Invoke-O365EndpointService
        # output) or from JSON when present, so it survives a merge round-trip.
        [parameter( Mandatory = $false,
                    ValueFromPipelineByPropertyName)]
        [Nullable[int]]$id,

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

        # Specifies a path to one or more locations.
        [Parameter(Mandatory=$true,
                   Position=10,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path
    )

    begin {
        # List[object] (not List[EndpointSet]) so a module re-import - which gives the class a
        # new type identity - cannot cause "Cannot find an overload for Add" on the new instances.
        $endpoints = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $endpoint = [EndpointSet]::new(
            $id,
            $ServiceArea,
            $ServiceAreaDisplayName,
            $Protocol,
            $Uri,
            $TcpPort,
            $UdpPort,
            $Category,
            $ExpressRoute,
            $Required,
            $Notes
        )

        $endpoints.Add($endpoint)
    }

    end {
        foreach ($PathElement in $Path) {
            if ([IO.Path]::GetExtension($PathElement) -eq '.json') {
                $endpointsJSON = Get-Content $PathElement | ConvertFrom-Json

                foreach ($endpointJSON in $endpointsJSON) {
                    $endpoint = [EndpointSet]::new(
                        $endpointJSON.id,
                        $endpointJSON.serviceArea,
                        $endpointJSON.serviceAreaDisplayName,
                        $endpointJSON.protocol,
                        $endpointJSON.uri,
                        $endpointJSON.tcpPort,
                        $endpointJSON.udpPort,
                        $endpointJSON.category,
                        $endpointJSON.expressRoute,
                        $endpointJSON.required,
                        $endpointJSON.notes
                    )

                    $endpoints.Add($endpoint)
                }
            }
        }

        return $endpoints
    }
}
