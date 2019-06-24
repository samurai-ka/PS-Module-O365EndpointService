using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Net;

namespace O365ServiceEndpoint
{
    [Cmdlet(VerbsCommon.Get, "O365EndpointServiceList")]
    [OutputType(typeof(O365EndpointServiceListElement))]
    public class GetO365EndpointServiceList : PSCmdlet
    {
        [Parameter(
            Mandatory = true,
            Position = 0,
            ValueFromPipeline = true,
            ValueFromPipelineByPropertyName = true
        )]
        public string TenantName { get; set; }

        [Parameter(
            Position = 1,
            ValueFromPipelineByPropertyName = true
        )]
        //[ValidateSet("Cat", "Dog", "Horse")]
        public bool IPv6 { get; set; }

        [Parameter(
            Position = 2,
            ValueFromPipelineByPropertyName = true
        )]
        public bool ForceLatest { get; set; }

        // This method gets called once for each cmdlet in the pipeline when the pipeline starts executing
        protected override void BeginProcessing()
        {
            WriteVerbose("Begin cmdlet!");
        }

        // This method will be called for each input received from the pipeline to this cmdlet; if no input is received, this method is not called
        protected override void ProcessRecord()
        {
            WriteObject(new O365EndpointServiceListElement { 
                Required = IPv6,
                ExpressRoute = ForceLatest,
                ServiceAreas = TenantName
                
            });
        }

        // This method will be called once at the end of pipeline execution; if no input is received, this method is not called
        protected override void EndProcessing()
        {
            WriteVerbose("End cmdlet!");
        }
    }
    
    public class O365EndpointServiceListElement
    {
        // The connectivity category for the endpoint set. Valid values are Optimize, Allow, and Default. Required.
        enum O365ServiceEndpointCategories { Default,Allow,Optimize};

        public string ServiceAreas { get; set; }
        public string ServiceAreaDisplayName { get; set; }
        public string Protocol { get; set; }
        public ServicePoint Uri { get; set; }
        public TransportType TransportType { get; set; }
        public O365ServiceEndpointCategories Category { get; set; }
        public bool ExpressRoute { get; set; }
        public bool Required { get; set; }
        public string Notes { get; set; }
    }
}
