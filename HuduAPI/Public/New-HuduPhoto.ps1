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
    $form = @{file = $File; "upload[photoable_id]" = $PhotoableId; "upload[photoable_type]" = $Photoable_Type; }
    if ($CompanyId)     { $form.company_id = $CompanyId }
    if ($Photoable_Type) { $form.photoable_type = $Photoable_Type }
    if ($PhotoableId)   { $form.photoable_id = $PhotoableId }
    if ($FolderId)      { $form.folder_id = $FolderId }
    if ($Pinned)        { $form.pinned =  }

    Invoke-HuduRequest -Method POST -Resource '/api/v1/photos' -Form 

}