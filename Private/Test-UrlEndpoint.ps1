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
        [int32]$tcpPort = 80

)

    Process  {
        if ($uri.StartsWith("*.")) {
            Write-Output "Url is a wildcard and will be skipped"
        }
        else {
            # Test-NetConnection -ComputerName $uri -Port $tcpPort -InformationLevel Detailed

            $client = [System.Net.Sockets.TcpClient]::new()
            $success = $client.ConnectAsync($Uri, $TcpPort).Wait(2000)
            $client.Close()
            Write-Output $success

        }
    }
}
