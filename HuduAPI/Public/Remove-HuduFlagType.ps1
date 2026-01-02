function Remove-HuduFlagType {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FlagTypeId')]
        [int]$Id
    )

    process {
        if ($PSCmdlet.ShouldProcess("Flag Type Id=$Id", "Delete")) {
            Invoke-HuduRequest -Method DELETE -Resource "/api/v1/flag_types/$Id" | Out-Null
            return $true
        }
    }
}
