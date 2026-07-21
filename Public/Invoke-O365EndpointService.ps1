function Invoke-O365EndpointService {
    <#
    .SYNOPSIS
        Retrieves the current Office 365 worldwide endpoints from the Microsoft web service.

    .DESCRIPTION
        Queries the Office 365 IP Address and URL web service (https://endpoints.office.com)
        for the selected service instance (Worldwide by default) and returns one EndpointSet
        object per URL/IP and port combination.

        A client request ID and the last seen version number are cached per instance in
        %LOCALAPPDATA%\pwsh\O365EndpointFunctions\endpoints_clientid_latestversion_<Instance>.txt.
        On each run the cached version is compared against the latest published version:

          - If a newer version is available (or -ForceLatest is used), the endpoints are
            downloaded, flattened into EndpointSet objects and returned. The cache is only
            updated after the endpoints have been fetched successfully.
          - If the cached version is already current, nothing is downloaded and $null is
            returned.

    .PARAMETER tenantName
        The Office 365 tenant name used to replace the placeholders in the URLs returned
        by the web service (for example "contoso" for contoso.onmicrosoft.com).

    .PARAMETER Instance
        The Microsoft 365 service instance to query. One of Worldwide (default), China,
        USGovDoD, or USGovGCCHigh. Each instance is version-cached independently.

    .PARAMETER ServiceAreas
        One or more service areas to return: Common, Exchange, SharePoint, and/or Skype.
        The web service always includes Common (it is a prerequisite for the others). If
        omitted, all service areas are returned. Because the local cache tracks only the
        version number - not the filter - use -ForceLatest when changing this filter between
        runs, otherwise an unchanged version returns nothing.

    .PARAMETER IPv6
        Include IPv6 address ranges in the results. By default only IPv4 ranges are
        requested (the service is called with NoIPv6=true).

    .PARAMETER ForceLatest
        Download and return the endpoints even when the cached version number indicates
        the local data is already up to date.

    .OUTPUTS
        EndpointSet. One object per URL/IP and port combination, or $null when the cached
        version is already current.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso'

        Returns the current endpoints for the 'contoso' tenant, or $null if the local
        cache is already up to date.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' -ForceLatest -IPv6

        Forces a fresh download including IPv6 ranges, regardless of the cached version.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' -Instance USGovGCCHigh

        Returns the endpoints for the US Government GCC High cloud instance.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' -ServiceAreas Exchange, SharePoint -ForceLatest

        Returns only the Exchange and SharePoint endpoints (Common is always included by the
        service). -ForceLatest ensures a download because the cache does not track the filter.

    .EXAMPLE
        Invoke-O365EndpointService -tenantName 'contoso' |
            Where-Object category -eq 'Optimize'

        Retrieves the endpoints and filters them to the 'Optimize' connectivity category.

    .LINK
        https://learn.microsoft.com/microsoft-365/enterprise/microsoft-365-ip-web-service
    #>
    [cmdletbinding()]
    [OutputType('EndpointSet')]
    param(

        # The tenant name will be used to replace placeholders in the url returned from the service
        [Parameter(Mandatory=$true)]
        [string]$tenantName,

        # The Microsoft 365 service instance to query
        [Parameter(Mandatory=$false)]
        [ValidateSet('Worldwide','China','USGovDoD','USGovGCCHigh')]
        [string]$Instance = 'Worldwide',

        # One or more service areas to return (Common is always included by the service)
        [Parameter(Mandatory=$false)]
        [ValidateSet('Common','Exchange','SharePoint','Skype')]
        [string[]]$ServiceAreas,

        # Parameter help description
        [Parameter(Mandatory=$false)]
        [switch]$IPv6,

        # Parameter help description
        [Parameter(Mandatory=$false)]
        [switch]$ForceLatest
    )

    # webservice root URL
    $webserviceEndpointUrl = "https://endpoints.office.com"

    # path where client ID and latest version number will be stored
    #$datapath = $Env:TEMP + "\endpoints_clientid_latestversion.txt"
    # $datafile = "endpoints_clientid_latestversion.txt"
    # $dataDir = $Env:LOCALAPPDATA + "\pwsh\O365EndpointFunctions\Invoke-O365EndpointService\"
    # $datapath = $dataDir + $datafile
    $dataDir  = Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'pwsh/O365EndpointFunctions'
    # cache the version per instance so a different instance's version is never compared against
    $datapath = Join-Path -Path $dataDir -ChildPath ('endpoints_clientid_latestversion_{0}.txt' -f $Instance)

    # fetch client ID and version if data file exists; otherwise create new file
    if (Test-Path -Path $datapath) {
        $clientRequestContent = Get-Content $datapath
        $clientRequestId = $clientRequestContent[0]
        $lastVersion = $clientRequestContent[1]
    }
    else {
        if (!(Test-Path -Path $dataDir)) {
            New-Item -ItemType directory -Path $dataDir | Out-Null
        }

        $clientRequestId = [GUID]::NewGuid().Guid
        $lastVersion = "0000000000"
        @($clientRequestId, $lastVersion) | Out-File $datapath
    }

    # guard against a corrupt or truncated cache file so a valid request can still be built
    if ([string]::IsNullOrWhiteSpace($clientRequestId)) {
        $clientRequestId = [GUID]::NewGuid().Guid
    }
    if ([string]::IsNullOrWhiteSpace($lastVersion)) {
        $lastVersion = "0000000000"
    }

    # call version method to check the latest version, and pull new data if version number is different
    try {
        $webserviceEndpointVersion = [EndpointSet]::InvokeRestRequest(("{0}/version/{1}?clientRequestId={2}" -f $webserviceEndpointUrl, $Instance, $clientRequestId))
    }
    catch {
        throw ("Unable to determine the latest Office 365 endpoint version. {0}" -f $_.Exception.Message)
    }

    # make sure the service actually returned a version to compare against
    if (($null -eq $webserviceEndpointVersion) -or [string]::IsNullOrWhiteSpace($webserviceEndpointVersion.latest)) {
        throw "The Office 365 version web service returned no 'latest' version number."
    }

    if (($webserviceEndpointVersion.latest -gt $lastVersion) -or ($ForceLatest.IsPresent)) {
    #    Write-EventLog -LogName "Application" -Source $eventSource -EventId $eventNewEndpoints -EntryType Information -Message "New version of Office 365 worldwide commercial service instance endpoints detected" -Category 1

        # Use the NoIPv6 switch to create a string for the rest call
        if($IPv6.IsPresent){
            $NoIPv6 = "false"
        }
        else{
            $NoIPv6 = "true"
        }

        # invoke endpoints method to get the new data (URL-encode the tenant name so special characters are safe)
        $encodedTenantName = [uri]::EscapeDataString($tenantName)
        $endpointsUri = "{0}/endpoints/{1}?format=JSON&clientRequestId={2}&TenantName={3}&NoIPv6={4}" -f $webserviceEndpointUrl, $Instance, $clientRequestId, $encodedTenantName, $NoIPv6

        # optionally restrict the result to specific service areas (Common is always returned)
        if ($ServiceAreas) {
            $endpointsUri += "&ServiceAreas={0}" -f ($ServiceAreas -join ',')
        }

        try {
            $endpointSets = [EndpointSet]::InvokeRestRequest($endpointsUri)
        }
        catch {
            throw ("Unable to download the Office 365 endpoints. {0}" -f $_.Exception.Message)
        }

        # Use List[object] rather than List[EndpointSet]: after a module re-import the class
        # gets a new type identity, and a list bound to the previous EndpointSet type rejects
        # the freshly constructed instances with "Cannot find an overload for Add". Collecting
        # as [object] sidesteps that while still returning EndpointSet objects.
        $endpoints = [System.Collections.Generic.List[object]]::new()
        foreach($endpointSet in $endpointSets){

            if ($null -ne $endpointSet.urls) {
                foreach ($endpointUrl in $endpointSet.urls) {

                    if ($null -ne $endpointSet.tcpPorts) {
                        foreach ($endpointTcpPort in $endpointSet.tcpPorts.Split(",")) {

                            $endpoint = [EndpointSet]::new(
                                $endpointSet.id,
                                $endpointSet.serviceArea,
                                $endpointSet.serviceAreaDisplayName,
                                "url",
                                $endpointUrl,
                                $endpointTcpPort,
                                "",
                                $endpointSet.category,
                                $endpointSet.expressRoute,
                                $endpointSet.required,
                                $endpointSet.notes
                            )

                            $endpoints.Add($endpoint)

                        }
                    }
                    if ($null -ne $endpointSet.udpPorts) {
                        foreach ($endpointUdpPort in $endpointSet.udpPorts.Split(",")) {

                            $endpoint = [EndpointSet]::new(
                                $endpointSet.id,
                                $endpointSet.serviceArea,
                                $endpointSet.serviceAreaDisplayName,
                                "url",
                                $endpointUrl,
                                "",
                                $endpointUdpPort,
                                $endpointSet.category,
                                $endpointSet.expressRoute,
                                $endpointSet.required,
                                $endpointSet.notes
                            )

                            $endpoints.Add($endpoint)

                        }
                    }

                }
            }
            foreach ($endpointIP in $endpointSet.ips) {
                if ($null -ne $endpointSet.tcpPorts) {
                    foreach ($endpointTcpPort in $endpointSet.tcpPorts.Split(",")) {

                        $endpoint = [EndpointSet]::new(
                            $endpointSet.id,
                            $endpointSet.serviceArea,
                            $endpointSet.serviceAreaDisplayName,
                            "ip",
                            $endpointIP,
                            $endpointTcpPort,
                            "",
                            $endpointSet.category,
                            $endpointSet.expressRoute,
                            $endpointSet.required,
                            $endpointSet.notes
                        )

                        $endpoints.Add($endpoint)

                    }
                }
                if ($null -ne $endpointSet.udpPorts) {
                    foreach ($endpointUdpPort in $endpointSet.udpPorts.Split(",")) {

                        $endpoint = [EndpointSet]::new(
                            $endpointSet.id,
                            $endpointSet.serviceArea,
                            $endpointSet.serviceAreaDisplayName,
                            "ip",
                            $endpointIP,
                            "",
                            $endpointUdpPort,
                            $endpointSet.category,
                            $endpointSet.expressRoute,
                            $endpointSet.required,
                            $endpointSet.notes
                        )

                        $endpoints.Add($endpoint)

                    }
                }
            }
        }

        # only cache the new version number after the endpoints were fetched successfully,
        # otherwise a failed endpoints call would leave the cache marked "up-to-date"
        @($clientRequestId, $webserviceEndpointVersion.latest) | Out-File $datapath

        return $endpoints
    }
    else {
    #    Write-EventLog -LogName "Application" -Source $eventSource -EventId $eventNoNewEndpoints -EntryType Information -Message "Office 365 worldwide commercial service instance endpoints are up-to-date" -Category 1
        return $null
    }
}
