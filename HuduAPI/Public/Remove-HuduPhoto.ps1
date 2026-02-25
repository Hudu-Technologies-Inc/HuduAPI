function Remove-HuduPhoto {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PhotoId')]
        [int]$Id,
    )

    if ($PSCmdlet.ShouldProcess("Photo $Id", "Delete permanently")) {

    }
}