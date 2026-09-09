function Set-HuduArticlePinned {
    <#
    .SYNOPSIS
    Pins a Knowledge Base Article to the top of the list
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    Param (
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Int]$Id
    )
    process {
        if ($PSCmdlet.ShouldProcess($Id)) {
            Invoke-HuduRequest -Method put -Resource "/api/v1/articles/$Id/pin"
        }
    }
}
