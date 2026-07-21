#Requires -Version 5
# #Requires -PSSnapin <PSSnapin-Name> [-Version <N>[.<n>]]
# #Requires -Modules { <Module-Name> | <Hashtable> }
# #Requires -ShellId <ShellId>
# #Requires -RunAsAdministrator

#region Class definitions
# Class EndpointSet definies a dataset returned by the webservice.
# The class stays in this root module so it is parsed directly at import time. That avoids the
# well-known dot-sourcing pitfalls for PowerShell classes (parse order, type resolution). The
# plain functions below are dot-sourced from Private/ and Public/, which is safe because their
# bodies only reference [EndpointSet] at run time, by which point this class is already loaded.
class EndpointSet {
    # The service area that this is part of: Common, Exchange, SharePoint, or Skype.
    [string]$serviceArea

    # The service area that this is part of: Common, Exchange, SharePoint, or Skype.
    [string]$serviceAreaDisplayName
    [string]$protocol
    [string]$uri

    # TCP port for the endpoint set (a single port; the comma-separated list returned by the
    # web service is split into one EndpointSet per port). $null when not set.
    [Nullable[uint16]]$tcpPort

    # UDP port for the endpoint set (a single port). $null when not set.
    [Nullable[uint16]]$udpPort

    # The connectivity category for the endpoint set. Valid values are Optimize, Allow, and Default. Required.
    [string]$category

    # True or False if this endpoint set is routed over ExpressRoute.
    [bool]$expressRoute

    # True if this endpoint set is required to have connectivity for Office 365 to be supported. Omitted if false.
    [bool]$required

    # For optional endpoints, this text describes Office 365 functionality that will be missing if IP addresses or URLs
    # in this endpoint set cannot be accessed at the network layer. Omitted if blank.
    [string]$notes

    # Default (parameterless) constructor.
    EndpointSet() { }

    # Full constructor - populates every property in declaration order.
    EndpointSet(
        [string]$serviceArea,
        [string]$serviceAreaDisplayName,
        [string]$protocol,
        [string]$uri,
        [string]$tcpPort,
        [string]$udpPort,
        [string]$category,
        [bool]$expressRoute,
        [bool]$required,
        [string]$notes
    ) {
        $this.serviceArea            = $serviceArea
        $this.serviceAreaDisplayName = $serviceAreaDisplayName
        $this.protocol               = $protocol
        $this.uri                    = $uri
        # ports arrive as strings from the REST API, sometimes with surrounding whitespace
        # (e.g. "143, 587" -> " 587"); trim and convert to uint16. Empty values are left
        # unset so the [Nullable[uint16]] property stays $null.
        if (-not [string]::IsNullOrWhiteSpace($tcpPort)) { $this.tcpPort = [uint16]($tcpPort.Trim()) }
        if (-not [string]::IsNullOrWhiteSpace($udpPort)) { $this.udpPort = [uint16]($udpPort.Trim()) }
        $this.category               = $category
        $this.expressRoute           = $expressRoute
        $this.required               = $required
        $this.notes                  = $notes
    }

    # Returns the properties one per line, in declaration order.
    [string] ToString() {
        return @(
            $($this.serviceArea)
            $($this.serviceAreaDisplayName)
            $($this.protocol)
            $($this.uri)
            $($this.tcpPort)
            $($this.udpPort)
            $($this.category)
            $($this.expressRoute)
            $($this.required)
            $($this.notes)
        ) -join [Environment]::NewLine
    }

    # Returns all properties as a single CSV line, in declaration order. Every value is
    # wrapped in double quotes; embedded double quotes are doubled ("" per RFC 4180).
    [string] ToCSV() {
        $values = @(
            $this.serviceArea
            $this.serviceAreaDisplayName
            $this.protocol
            $this.uri
            $this.tcpPort
            $this.udpPort
            $this.category
            $this.expressRoute
            $this.required
            $this.notes
        )

        $quoted = foreach ($value in $values) {
            '"{0}"' -f ([string]$value).Replace('"', '""')
        }

        return $quoted -join ','
    }

    # Internal helper that calls Invoke-RestMethod with a timeout, retries transient failures
    # and reports a clear, contextual error when a request cannot be completed. Hidden so it
    # is not part of the public surface of the class.
    hidden static [object] InvokeRestRequest([string]$Uri, [int]$MaximumRetryCount, [int]$RetryIntervalSec, [int]$TimeoutSec) {
        $attempt = 0
        while ($true) {
            $attempt++
            try {
                return Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec $TimeoutSec -ErrorAction Stop
            }
            catch {
                # Determine the HTTP status code (if the failure carried an HTTP response) so we
                # can tell retryable problems from permanent ones.
                $statusCode = $null
                $response   = $_.Exception.Response
                if ($response) {
                    try { $statusCode = [int]$response.StatusCode } catch { $statusCode = $null }
                }

                # HTTP 429 (Too Many Requests): the endpoints/changes methods are rate limited.
                # A short retry will not help - the service guidance is to wait about an hour or
                # use a new client request ID - so fail fast with an actionable message instead
                # of burning the remaining attempts. (The version method is never rate limited.)
                if ($statusCode -eq 429) {
                    $retryAfter = [EndpointSet]::GetRetryAfter($response)
                    $waitHint = if ($retryAfter) {
                        "Retry after $retryAfter."
                    } else {
                        "Wait about an hour before retrying, or use a new client request ID."
                    }
                    throw ("Request to '{0}' was rate limited (HTTP 429). {1}" -f $Uri, $waitHint)
                }

                # 4xx client errors will not succeed on retry, except 408 (Request Timeout),
                # which is transient.
                $isNonRetryable = ($null -ne $statusCode) -and
                                  ($statusCode -ge 400) -and ($statusCode -lt 500) -and
                                  ($statusCode -ne 408)

                $statusText = if ($null -ne $statusCode) { " (HTTP $statusCode)" } else { "" }

                if ($isNonRetryable -or ($attempt -ge $MaximumRetryCount)) {
                    throw ("Request to '{0}' failed after {1} attempt(s){2}: {3}" -f $Uri, $attempt, $statusText, $_.Exception.Message)
                }

                Write-Warning ("Request to '{0}' failed (attempt {1}/{2}){3}: {4} - retrying in {5}s" -f `
                    $Uri, $attempt, $MaximumRetryCount, $statusText, $_.Exception.Message, $RetryIntervalSec)
                Start-Sleep -Seconds $RetryIntervalSec
            }
        }
        # unreachable: the loop either returns a result or throws
        throw "Request to '$Uri' failed."
    }

    # Overload using the default retry/timeout settings (3 attempts, 2s apart, 30s timeout).
    hidden static [object] InvokeRestRequest([string]$Uri) {
        return [EndpointSet]::InvokeRestRequest($Uri, 3, 2, 30)
    }

    # Best-effort extraction of the Retry-After header from a failed HTTP response. Works with
    # HttpResponseMessage (PowerShell 7) and HttpWebResponse (Windows PowerShell 5.1); returns
    # $null when the header is absent or cannot be read.
    hidden static [string] GetRetryAfter([object]$response) {
        if ($null -eq $response) { return $null }
        try {
            $headers = $response.Headers
            if ($null -eq $headers) { return $null }

            # PowerShell 7: HttpResponseHeaders exposes a typed RetryAfter property
            try {
                if ($headers.RetryAfter) { return $headers.RetryAfter.ToString() }
            } catch { }

            # Windows PowerShell 5.1 (WebHeaderCollection) or a plain collection: string indexer
            try {
                $raw = $headers['Retry-After']
                if ($raw) { return (@($raw) -join ',') }
            } catch { }
        } catch { }
        return $null
    }
}
#endregion Class definitions

#region Load functions
# Dot-source the private helper functions first, then the public cmdlets. Only functions live
# in these files - the class above is intentionally kept in this .psm1.
$privateFunctions = @( Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue )
$publicFunctions  = @( Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public')  -Filter '*.ps1' -ErrorAction SilentlyContinue )

foreach ($functionFile in ($privateFunctions + $publicFunctions)) {
    try {
        . $functionFile.FullName
    }
    catch {
        throw ("Failed to import function file '{0}': {1}" -f $functionFile.FullName, $_.Exception.Message)
    }
}

# Export only the public functions. The manifest's FunctionsToExport gates this as well.
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}
#endregion Load functions
