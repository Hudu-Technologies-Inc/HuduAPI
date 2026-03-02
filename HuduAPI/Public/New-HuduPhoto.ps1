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

        [Alias('company_id')]
        [int]$CompanyId,
        
        [Alias('folder_id')]
        [int]$FolderId,

        [ValidateSet("Article", "Asset", "Website","Company",IgnoreCase = $true)]
        [Alias('uploadabletype','recordtype','photoabletype','uploadable_type','record_type')]
        [string]$Photoable_Type,

        [Alias('record_id','uploadable_id','recordid','PhotoableId','uploadableid')]
        [int]$Photoable_Id,

        [Nullable[bool]]$Pinned
    )

    [version]$script:Version = $script:Version ?? [version]((Get-HuduAppInfo).version)
    if ($script:Version -lt [version]'2.39.6') {
        write-warning "Set-HuduPhoto: Hudu version $($script:Version) is below 2.39.6; Skipping."
        return $null
    }

    $File = Get-Item -LiteralPath $Path
    if (-not $File) { throw "File not found!" }
    if (-not $($File.Extension.ToLowerInvariant() -in '.jpeg','.jpg','.png','.gif','.webp','.heic')){
        write-error "file extension '$($File.Extension)' is not a supported photo format."
        throw "Unsupported file format."
    }

    if (($Photoable_Type -and -not ($Photoable_Id ?? $companyId)) -or ($($Photoable_Id ?? $companyId) -and -not $Photoable_Type)) {
        throw "PhotoableType and PhotoableId must be provided together."
    }
    if ([string]::IsNullOrWhiteSpace($Caption)) {
        throw "Caption is required."
    }
    $params = @{file = $File; caption = $Caption;}
    if ($PSBoundParameters.ContainsKey('Photoable_Type') -and $PSBoundParameters.ContainsKey('Photoable_Id')) { 
        $params.photoable_type  = $Photoable_Type
        $params.photoable_id    = $Photoable_Id
    } elseif ($PSBoundParameters.ContainsKey('CompanyId')) { 
        $params.photoable_type = "Company"
        $params.photoable_id = $CompanyId
    }

    if ($PSBoundParameters.ContainsKey('CompanyId')) { $params.company_id = $CompanyId }
    if ($PSBoundParameters.ContainsKey('FolderId'))  { $params.folder_id = $FolderId }    

    if ($PSBoundParameters.ContainsKey('Pinned'))      { $params.pinned = [bool]$Pinned }
    if ($PSBoundParameters.ContainsKey('archived'))  { $params.archived = [bool]$Archived }

    Invoke-HuduRequest -Method POST -Resource '/api/v1/photos' -Form $params
}