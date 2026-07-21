# Office 365 Endpoint Functions Module
Microsoft is hosting a REST Service to get the newest and latest Uri for the Office 365 services. Working with this service in PowerShell however isn't as strait forward as you would expect. To be able to use the uri as a collection and be able to iterate thru them with foreach loops, I'm using this module to create a few helper cmdlets.

## Installation
Install the module from the PowerShell Gallery:

        Install-Module O365EndpointFunctions

Alternatively, to run it from a local copy of this repository without installing, import the module folder directly:

        Import-Module .\O365EndpointFunctions

## Calling the REST service

All cmdlets in this module ship with comment based help, so you can get detailed usage information, parameters and examples at any time with

        Get-Help Invoke-O365EndpointService -Full

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
        
        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest -IPv6 | Format-Table -AutoSize

Return only the IP addresses for Exchange

        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest | where{($_.serviceArea -eq "Exchange") -and ($_.protocol -eq "ip")} | Format-Table -AutoSize

# Exporting a Proxy Pacfile

You can use this module to create an Proxy Pacfile, even it isn't advised to use a proxy with the Office 365 Endpoints at all.

Use the following cmdlet to export a proxy pacfile. In this example you first get the endpoints and filter the result to select the Urls and the category Optimize or Allow only. These urls are piped to and select only unique entries which is then exported. The result is piped to the shell or you could pipe it into a Out-File cmdlet to save the result.

        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest | where{($_.Protocol -eq "Url") -and (($_.Category -eq "Optimize") -or ($_.category -eq "Allow"))} | select uri -Unique | Export-O365ProxyPacFile

The cmdlet does not filter double entries. If you do not want the uri repeated you must filter them with

        select uri -Unique

You can add the notes returned by the Invoke-O365EndpointService cmdlet with switch Comments. Just add the switch at the end of the cmdlet like this:

        Export-O365ProxyPacFile -Comments

# Merging endpoints

There a plenty of other url and IP-addresses you might want to configure but are not returned from the Microsoft Rest API e.g. Azure Endpoints. An other use case are missing endpoints. In these cases you can merge your list of endpoints with the endpoints returned from the Rest API using the cmdlet

        Merge-O365EndpointService

You can define your endpoints as one or more JSON files. These files can than be merged into a single list.

        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest | Merge-O365EndpointService -Path @(".\ExampleEndpoints1.json",".\ExampleEndpoints2.json") | Format-Table -AutoSize

There is no JSON schema yet. So take care when creating your list.

# Exporting a Ghostery policy

If you use [Ghostery](https://www.ghostery.com/enterprise-privacy-solutions/documentation/policy-reference) in your enterprise you can export the endpoints as a Ghostery policy so that Office 365 traffic is not touched by the tracker protection. The cmdlet emits the policy as JSON to the pipeline, so you can pipe it directly into a Out-File cmdlet to save it as a policy file.

        Export-O365Ghostery

There are two ways to allow the domains, controlled by two switches. Supply both to write both keys into a single policy.

* TrustedDomains

  Exports the urls as the Ghostery `trustedDomains` array. Ghostery pauses its protection for these domains and automatically includes their subdomains. This is the default when neither switch is given.

* Whitelist

  Exports the urls as `customFilters` allowlist exception rules of the form `@@||domain^`. Ghostery has no dedicated exceptions key, so allowlisting is expressed through customFilters.

Each url is normalised before it is written: the scheme and path are removed and a leading wildcard (`*.`) is stripped, because Ghostery matches subdomains on its own. Duplicate domains are removed automatically.

Get the endpoints, filter them to the urls and export them as trusted domains into a policy file:

        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest | where{$_.Protocol -eq "Url"} | Export-O365Ghostery -TrustedDomains | Out-File .\ghostery-policy.json -Encoding utf8

Export the same urls as allowlist exception rules instead:

        Invoke-O365EndpointService -tenantName [YourTenantName] -ForceLatest | where{$_.Protocol -eq "Url"} | Export-O365Ghostery -Whitelist
