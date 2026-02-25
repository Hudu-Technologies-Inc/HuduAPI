function New-HuduPhoto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('File','FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Caption,

        [int]$CompanyId,
        [int]$FolderId,

        [ValidateSet("Article", "AssetPassword", "Asset", "IpAddress", "Network", "RackStorage", "VlanZone", "Vlan", "Website",IgnoreCase = $true)]
        [Alias('uploadabletype','recordtype','photoabletype','uploadable_type','record_type')]
        [string]$Photoable_Type,

        [Alias('record_id','uploadable_id','recordid','photoableid','uploadableid')]
        [int]$Photoable_Id,
        [Nullable[bool]]$Pinned
    )

    $File = Get-Item -LiteralPath $Path
    if (-not $File) { throw "File not found!" }

    if (($Photoable_Type -and -not $Photoable_Id) -or ($Photoable_Id -and -not $Photoable_Type)) {
        throw "PhotoableType and PhotoableId must be provided together."
    }
    if ([string]::IsNullOrWhiteSpace($Caption)) {
        throw "Caption is required."
    }

    $params = @{file = $File; "upload[photoable_id]" = $PhotoableId; "upload[photoable_type]" = $Photoable_Type; }
    if ($PSBoundParameters.ContainsKey('CompanyId')) { $params.company_id = $CompanyId }
    if ($PSBoundParameters.ContainsKey('Caption'))   { $params.caption = $Caption }
    if ($PSBoundParameters.ContainsKey('Pinned'))      { $params.pinned = [bool]$Pinned }
    if ($PSBoundParameters.ContainsKey('FolderId'))  { $params.folder_id = $FolderId }
    if ($PSBoundParameters.ContainsKey('archived'))  { $params.archived = [bool]$Archived }


    Invoke-HuduRequest -Method POST -Resource '/api/v1/photos' -Form $params

}