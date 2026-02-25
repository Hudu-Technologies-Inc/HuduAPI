function Set-HuduPhoto {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Id,

        [string]$Caption,
        [Nullable[bool]]$Pinned,
        [int]$FolderId
    )

    $body = @{}
    if ($PSBoundParameters.ContainsKey('Caption')) { $body.caption = $Caption }
    if ($PSBoundParameters.ContainsKey('Pinned'))  { $body.pinned  = $Pinned }
    if ($PSBoundParameters.ContainsKey('FolderId')){ $body.folder_id = $FolderId }

    if ($body.Count -eq 0) { return }

}