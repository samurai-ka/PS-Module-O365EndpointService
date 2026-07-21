@{
    # PSScriptAnalyzer configuration used by the publishing test (Tests/Publishing.Tests.ps1)
    # and suitable for local runs: Invoke-ScriptAnalyzer -Settings PSScriptAnalyzerSettings.psd1

    # Run the built-in rule set...
    IncludeDefaultRules = $true

    # ...except for rules that are intentional in this module:
    ExcludeRules = @(
        # Export-O365ProxyPacFile / Merge-O365EndpointService declare the full set of endpoint
        # properties as parameters so complete EndpointSet objects bind from the pipeline
        # (ValueFromPipelineByPropertyName), even though only a subset is used in the body.
        'PSReviewUnusedParameter'
    )
}
