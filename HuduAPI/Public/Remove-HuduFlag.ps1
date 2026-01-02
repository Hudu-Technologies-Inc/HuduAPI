function Remove-HuduFlag {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
        [Alias('FlagId','id')]
        [int]$Id
    )

    process {
        if ($PSCmdlet.ShouldProcess("Flag Id=$Id", "Delete")) {
            Invoke-HuduRequest -Method DELETE -Resource "/api/v1/flags/$Id" | Out-Null
        }
    }
}