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

        [Alias('record_id','uploadable_id','recordid','PhotoableId','uploadableid')]
        [int]$Photoable_Id,

        [Nullable[bool]]$Pinned
    )

    $File = Get-Item -LiteralPath $Path
    if (-not $File) { throw "File not found!" }

    if (($Photoable_Type -and -not ($Photoable_Id ?? $companyId)) -or ($($Photoable_Id ?? $companyId) -and -not $Photoable_Type)) {
        throw "PhotoableType and PhotoableId must be provided together."
    }
    if ([string]::IsNullOrWhiteSpace($Caption)) {
        throw "Caption is required."
    }
    write-host "photoable type $photoable_type id $photoable_id company $companyId folder $folderId pinned $Pinned caption $Caption file $File"

    $params = @{file = $File }
    if ($PSBoundParameters.ContainsKey('CompanyId')) { 
        $params.photoable_type = "upload[photoable_type]=Company"
        $params.photoable_id = "upload[photoable_id]=$CompanyId"
    } elseif ($PSBoundParameters.ContainsKey('Photoable_Type') -and $PSBoundParameters.ContainsKey('Photoable_Id')) { 
        $params.photoable_type  = "upload[photoable_type]=$Photoable_Type" 
        $params.photoable_id    = "upload[photoable_id]=$Photoable_Id"
    }

    

    if ($PSBoundParameters.ContainsKey('CompanyId')) { $params.company_id = $CompanyId }
    if ($PSBoundParameters.ContainsKey('Caption'))   { $params.caption = $Caption }
    if ($PSBoundParameters.ContainsKey('Pinned'))      { $params.pinned = [bool]$Pinned }
    if ($PSBoundParameters.ContainsKey('FolderId'))  { $params.folder_id = $FolderId }
    if ($PSBoundParameters.ContainsKey('archived'))  { $params.archived = [bool]$Archived }


    Invoke-HuduRequest -Method POST -Resource '/api/v1/photos' -Form $params

}