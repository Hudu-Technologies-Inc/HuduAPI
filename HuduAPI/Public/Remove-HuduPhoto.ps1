function Remove-HuduPhoto {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PhotoId')]
        [int]$Id
    )
    process {
        [version]$script:Version = $script:Version ?? [version]((Get-HuduAppInfo).version)

        if ($script:Version -lt [version]'2.39.6') {
            write-warning "Remove-HuduPhoto: Hudu version $($script:Version) is below 2.39.6; Skipping."
            return $false
        }
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