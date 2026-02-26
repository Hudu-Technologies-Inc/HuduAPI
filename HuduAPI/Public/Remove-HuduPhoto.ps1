function Remove-HuduPhoto {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PhotoId')]
        [int]$Id
    )
    process {

        if ($PSCmdlet.ShouldProcess("Photo $Id", "Delete permanently")) {
            try {
                Invoke-HuduRequest -Method DELETE -Resource "/api/v1/photos/$Id"
                return $true
            } catch {
                Write-Warning "Failed to delete photo ID $Id"
                return $false
            }
        }
    }
}