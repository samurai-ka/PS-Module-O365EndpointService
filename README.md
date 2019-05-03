# Office 365 Endpoint Functions Module
Microsoft is hosting a REST Service to get the newest and latest Uri for the Office 365 services. Working with this service in PowerShell however isn't as strait forward as you would expect. To be able to use the uri as a collection and be able to iterate thru them with foreach loops, I'm using this module to create a few helper cmdlets.
## No PowerShell gallery support
This is a very early release. I haven't added this module to the PowerShell Gallery, so you cannot import this module with Import-Module. This is however on my roadmap for the future.

## Calling the REST service
To use this module simply copy it somewhere on your disk and import it directly:

        Import-Module O365EndpointFunctions.psm1

After you have imported the module you can then call the REST service. This will return to you as a collection of uri you can process in powershell directly. You must enter the name of your Office 365 tenant

        Invoke-O365EndpointService -tenantName [Name of your tenant]

### Parameter

* tenantName
  
  The name of your Office 365 tenant. This paramter is mandatory.

* ForceLatest

  This switch will force the REST API to allways return the entire list of the latest uri.

* IPv6

  This switch will return the IPv6 addresses as well. As default only IPv4 will be returned.

## Samples

Return the complete list of all Uri including the IPv6 addresses
        
        Invoke-O365EndpointService -tenantName [Name of your tenant] -ForceLatest -IPv6 | Format-Table -AutoSize

Return only the IP addresses for Exchange

        Invoke-O365EndpointService -tenantName [Name of your tenant] -ForceLatest | where{($_.serviceArea -eq "Exchange") -and ($_.protocol -eq "ip")}| Format-Table -AutoSize

# Exporting a Proxy Pacfile

You can use this module to create an Proxy Pacfile, even it isn't advised to use a proxy with the Office 365 Endpoints at all.

Use the following cmdlet to export a proxy pacfile. In this example you first get the endpoints and filter the result to select the Urls and the category Optimize or Allow only. These urls are piped to and select only unique entries which is then exported. The result is piped to the shell or you could pipe it into a Out-File cmdlet to save the result.

        Invoke-O365EndpointService -tenantName YourTenantName -ForceLatest | where{($_.Protocol -eq "Url") -and (($_.Category -eq "Optimize") -or ($_.category -eq "Allow"))} | select uri -Unique | Export-O365ProxyPacFile

The cmdlet does not filter double entries. If you do not want the uri repeated you must filter them with

        select uri -Unique

You can add the notes returned by the Invoke-O365EndpointService cmdlet with switch Comments. Just add the switch at the end of the cmdlet like this:

        Export-O365ProxyPacFile -Comments
