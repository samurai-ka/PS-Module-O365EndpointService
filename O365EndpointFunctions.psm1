#Requires -Version 5
# #Requires -PSSnapin <PSSnapin-Name> [-Version <N>[.<n>]]
# #Requires -Modules { <Module-Name> | <Hashtable> }
# #Requires -ShellId <ShellId>
# #Requires -RunAsAdministrator

#region Class definitions
# Class EndpointSet definies a dataset returned by the webservice
class EndpointSet {
    # The service area that this is part of: Common, Exchange, SharePoint, or Skype.
    [string]$serviceArea

    # The service area that this is part of: Common, Exchange, SharePoint, or Skype.
    [string]$serviceAreaDisplayName
    [string]$protocol
    [string]$uri

    # TCP ports for the endpoint set. All ports elements are formatted as a comma-separated list of ports or
    # port ranges separated by a dash character (-). Ports apply to all IP addresses and all URLs in that endpoint set for that category. Omitted if blank.
    [string]$tcpPort

    # UDP ports for the IP address ranges in this endpoint set. Omitted if blank.
    [string]$udpPort

    # The connectivity category for the endpoint set. Valid values are Optimize, Allow, and Default. Required.
    [string]$category

    # True or False if this endpoint set is routed over ExpressRoute.
    [bool]$expressRoute

    # True if this endpoint set is required to have connectivity for Office 365 to be supported. Omitted if false.
    [bool]$required

    # For optional endpoints, this text describes Office 365 functionality that will be missing if IP addresses or URLs
    # in this endpoint set cannot be accessed at the network layer. Omitted if blank.
    [string]$notes
}
#endregion Class definitions

function Invoke-O365EnpointService {
    param(
        [cmdletbinding()]

        # The tenant name will be used to replace placeholders in the url returned from the service
        [Parameter(Mandatory=$true)]
        [string]$tenantName,
    
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
    $datafile = "endpoints_clientid_latestversion.txt"
    $dataDir = $Env:LOCALAPPDATA + "\pwsh\O365EndpointFunctions\Invoke-O365EnpointService\"
    $datapath = $dataDir + $datafile

    # fetch client ID and version if data file exists; otherwise create new file
    if (Test-Path -Path $datapath) {
        $clientRequestContent = Get-Content $datapath
        $clientRequestId = $clientRequestContent[0]
        $lastVersion = $clientRequestContent[1]
    }
    else {
        if (!(Test-Path -Path $dataDir)) {
            New-Item -ItemType directory -Path $dataDir
        }

        $clientRequestId = [GUID]::NewGuid().Guid
        $lastVersion = "0000000000"
        @($clientRequestId, $lastVersion) | Out-File $datapath
    }

    # call version method to check the latest version, and pull new data if version number is different
    $webserviceEndpointVersion = Invoke-RestMethod -Uri ("{0}/version/Worldwide?clientRequestId={1}" -f $webserviceEndpointUrl,$clientRequestId)

    if (($webserviceEndpointVersion.latest -gt $lastVersion) -or ($ForceLatest.IsPresent)) {
    #    Write-EventLog -LogName "Application" -Source $eventSource -EventId $eventNewEndpoints -EntryType Information -Message "New version of Office 365 worldwide commercial service instance endpoints detected" -Category 1

        # write the new version number to the data file
        @($clientRequestId, $webserviceEndpointVersion.latest) | Out-File $datapath

        # Use the NoIPv6 switch to create a string for the rest call
        if($IPv6.IsPresent){
            $NoIPv6 = "false"
        }
        else{
            $NoIPv6 = "true"
        }

        # invoke endpoints method to get the new data
        $endpointSets = Invoke-RestMethod -Uri ("{0}/endpoints/Worldwide?format=JSON&clientRequestId={1}&TenantName={2}&NoIPv6={3}" -f $webserviceEndpointUrl,$clientRequestId,$tenantName,$NoIPv6)

        [System.Collections.ArrayList]$endpoints = @()
        foreach($endpointSet in $endpointSets){

            if ($null -ne $endpointSet.urls) {
                foreach ($endpointUrl in $endpointSet.urls) {
                    
                    if ($null -ne $endpointSet.tcpPorts) {
                        foreach ($endpointTcpPort in $endpointSet.tcpPorts.Split(",")) {
                            
                            $endpoint = New-Object EndpointSet

                            $endpoint.serviceArea               = $endpointSet.serviceArea
                            $endpoint.serviceAreaDisplayName    = $endpointSet.serviceAreaDisplayName
                            $endpoint.expressRoute              = $endpointSet.expressRoute
                            $endpoint.category                  = $endpointSet.category
                            $endpoint.required                  = $endpointSet.required
                            $endpoint.notes                     = $endpointSet.notes
                            $endpoint.protocol                  = "url"
                            $endpoint.uri                       = $endpointUrl
                            $endpoint.tcpPort                   = $endpointTcpPort

                            $endpoints.Add($endpoint) > $null

                        }
                    }
                    if ($null -ne $endpointSet.udpPorts) {
                        foreach ($endpointUdpPort in $endpointSet.udpPorts.Split(",")) {
                            
                            $endpoint = New-Object EndpointSet

                            $endpoint.serviceArea               = $endpointSet.serviceArea
                            $endpoint.serviceAreaDisplayName    = $endpointSet.serviceAreaDisplayName
                            $endpoint.expressRoute              = $endpointSet.expressRoute
                            $endpoint.category                  = $endpointSet.category
                            $endpoint.required                  = $endpointSet.required
                            $endpoint.notes                     = $endpointSet.notes
                            $endpoint.protocol                  = "url"
                            $endpoint.uri                       = $endpointUrl
                            $endpoint.udpPort                   = $endpointUdpPort

                            $endpoints.Add($endpoint) > $null

                        }
                    }

                }
            }
            foreach ($endpointIP in $endpointSet.ips) {
                if ($null -ne $endpointSet.tcpPorts) {
                    foreach ($endpointTcpPort in $endpointSet.tcpPorts.Split(",")) {
                        
                        $endpoint = New-Object EndpointSet

                        $endpoint.serviceArea               = $endpointSet.serviceArea
                        $endpoint.serviceAreaDisplayName    = $endpointSet.serviceAreaDisplayName
                        $endpoint.expressRoute              = $endpointSet.expressRoute
                        $endpoint.category                  = $endpointSet.category
                        $endpoint.required                  = $endpointSet.required
                        $endpoint.notes                     = $endpointSet.notes
                        $endpoint.protocol                  = "ip"
                        $endpoint.uri                       = $endpointIP
                        $endpoint.tcpPort                   = $endpointTcpPort

                        $endpoints.Add($endpoint) > $null

                    }
                }
                if ($null -ne $endpointSet.udpPorts) {
                    foreach ($endpointUdpPort in $endpointSet.udpPorts.Split(",")) {
                        
                        $endpoint = New-Object EndpointSet

                        $endpoint.serviceArea               = $endpointSet.serviceArea
                        $endpoint.serviceAreaDisplayName    = $endpointSet.serviceAreaDisplayName
                        $endpoint.expressRoute              = $endpointSet.expressRoute
                        $endpoint.category                  = $endpointSet.category
                        $endpoint.required                  = $endpointSet.required
                        $endpoint.notes                     = $endpointSet.notes
                        $endpoint.protocol                  = "ip"
                        $endpoint.uri                       = $endpointIP
                        $endpoint.udpPort                   = $endpointUdpPort

                        $endpoints.Add($endpoint) > $null

                    }
                }
            }
        }
        return $endpoints
    }
    else {
    #    Write-EventLog -LogName "Application" -Source $eventSource -EventId $eventNoNewEndpoints -EntryType Information -Message "Office 365 worldwide commercial service instance endpoints are up-to-date" -Category 1
        return $null
    }
}

#region Test Function 
Function Test-UrlEndpoint  {
    [cmdletbinding()]
    Param (
        # Parameter help description
        [Parameter( Mandatory=$True,
                    ValueFromPipeline=$True,
                    ValueFromPipelinebyPropertyName=$True
                )
        ]
        [string]$uri,
        
        [Parameter( Mandatory=$false
                )
        ]
        [int32]$tcpPort = "80"

)
  
    Process  {
        if ($uri.StartsWith("*.")) {
            "Url is a wildcard and will be skipped" | Write-Host
        }
        else {
            Test-NetConnection -ComputerName $uri -Port $tcpPort -InformationLevel Detailed
        }
    }
}
#endregion Test Function 
