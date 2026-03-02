function Set-HuduPhoto {
    param(
        [Parameter(Mandatory)]
        [int]$Id,


        [int]$CompanyId,
        [Alias('uploadabletype','recordtype','PhotoableType','uploadable_type','record_type')]
        [ValidateSet('article','articles','kb','knowledgebase', 'artikel', 'article', 'articolo', 'artículo', 'asset','assets', 'anlage','objekt', 'actif', 'bene', 'activo','website', 'webseite', 'site', 'sito', 'sitio', 'company','companies', 'firma', 'entreprise', 'azienda', 'empresa', IgnoreCase = $true)]
        [string]$Photoable_Type,
        
        [Alias('record_id','uploadable_id','recordid','PhotoableId','uploadableid')]
        [int]$Photoable_Id,

        [Alias('folder_id')]
        [int]$FolderId,

        [Nullable[bool]]$Archived,
        [Nullable[bool]]$Pinned,
        [string]$Caption
    )
    [version]$script:Version = $script:Version ?? [version]((Get-HuduAppInfo).version)
    if ($script:Version -lt [version]'2.39.6') {
        write-warning "Set-HuduPhoto: Hudu version $($script:Version) is below 2.39.6; Skipping."
        return $null
    }
    $params = @{}
    # proper casing for hudu API 

    if ($PSBoundParameters.ContainsKey('CompanyId')) { $params.company_id = $CompanyId }
    if ($PSBoundParameters.ContainsKey('Caption'))   { $params.caption = $Caption }
    if ($PSBoundParameters.ContainsKey('Pinned'))      { $params.pinned = "$([bool]$Pinned)".ToString().ToLower() }
    if ($PSBoundParameters.ContainsKey('FolderId'))  { $params.folder_id = $(if ($null -eq $FolderId -or $folderID -lt 1){"null"} else {"$FolderId"} )}
    if ($PSBoundParameters.ContainsKey('archived'))  { $params.archived = "$([bool]$Archived)".ToString().ToLower() }

    if ($PSBoundParameters.ContainsKey('Photoable_Type') -and $PSBoundParameters.ContainsKey('Photoable_Id')) { 
        $params.photoable_type  = $(Get-ObjectTypeFromCononical -inputData $Photoable_Type)
        $params.photoable_id    = $Photoable_Id
    } elseif ($PSBoundParameters.ContainsKey('CompanyId')) { 
        $params.photoable_type = "Company"
        $params.photoable_id =$CompanyId
    }
    
    $result = invoke-hudurequest -Method PUT -Resource "/api/v1/photos/$Id" -Body $(@{photo = $params} | ConvertTo-Json -Depth 99)

    return $result.photo ?? $result
}