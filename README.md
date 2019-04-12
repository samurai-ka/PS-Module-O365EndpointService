# Office 365 Endpoint Functions Module
Microsoft is hosting a REST Service to get the newest and latest Uri for the Office 365 services. Working with this service in PowerShell however isn't as strait forward as you would expect. To be able to use the uri as a collection and be able to iterate thru them with foreach loops, I'm using this module to create a few helper cmdlets.
## No PowerShell gallery support
This is a very early release. I haven't added this module to the PowerShell Gallery, so you cannot import this module with Import-Module. This is however on my roadmap for the future.

## Calling the REST service
To use this module simply copy it somewhere on your disk and import it directly:

> Import-Module O365EndpointFunctions.psm1

After you have imported the module you can then call the REST service. This will return to you as a collection of uri you can process in powershell directly. You must enter the name of your Office 365 tenant

> Invoke-O365EnpointService -tenantName [Name of your tenant]

### Parameter

* tenantName
  
  The name of your Office 365 tenant. This paramter is mandatory.

* ForceLatest

  This switch will force the REST API to allways return the entire list of the latest uri.

* IPv6

  This switch will return the IPv6 addresses as well. As default only IPv4 will be returned.
  