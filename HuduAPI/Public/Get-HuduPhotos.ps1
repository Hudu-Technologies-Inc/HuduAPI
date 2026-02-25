function Get-HuduPhotos {
    <#
    .SYNOPSIS
    Get a list of photos or a single photo, optionally downloading files.

    .DESCRIPTION
    Calls Hudu API to retrieve photos. Supports filtering
    If -Download is specified with -Id (single) or without (list), downloads photo files using /photos/{id}?download=true.

    .PARAMETER Id
    ID of the Photo to retrieve (or download if -Download is specified).

    .PARAMETER CompanyId
    Filter by company ID.

    .PARAMETER Photoable_Type
    Filter by photoable type (Company, Asset, Article, etc).

    .PARAMETER Photoable_Id
    Filter by photoable record ID.

    .PARAMETER FolderId
    Filter by folder ID.

    .PARAMETER Archived
    $true = only archived, $false = only non-archived, $null = omit param (API defaults to non-archived only).

    .PARAMETER CreatedAt
    Filter by creation date. Accepts "YYYY-MM-DD" or "start,end" (YYYY-MM-DD,YYYY-MM-DD).

    .PARAMETER UpdatedAt
    Filter by update date. Accepts "YYYY-MM-DD" or "start,end" (YYYY-MM-DD,YYYY-MM-DD).

    .PARAMETER Download
    If specified, downloads photo file(s) to OutDir.

    .PARAMETER OutDir
    Directory to download photos into. Default current directory.

    .EXAMPLE
    Get-HuduPhotos -CompanyId 123

    .EXAMPLE
    Get-HuduPhotos -Photoable_Type Asset -Photoable_Id 456 -Download -OutDir "$env:TEMP\photos"

    .EXAMPLE
    Get-HuduPhotos -Id 999 -Download
    #>
    [CmdletBinding()]
    param(
        [int]$Id,

        [int]$CompanyId,
        [ValidateSet("Article", "AssetPassword", "Asset", "IpAddress", "Network", "RackStorage", "VlanZone", "Vlan", "Website",IgnoreCase = $true)]
        [Alias('uploadabletype','recordtype','Photoable_Type','uploadable_type','record_type')]
        [string]$Photoable_Type,
        
        [Alias('record_id','uploadable_id','recordid','Photoable_Id','uploadableid')]
        [int]$Photoable_Id,
        [int]$FolderId,

        [Nullable[bool]]$Archived,

        [datetime]$createdBefore,
        [datetime]$createdAfter,
        [datetime]$UpdatedBefore,
        [datetime]$UpdatedAfter,

        [switch]$Download,
        [string]$OutDir = '.'
    )

    [version]$script:Version = $script:Version ?? (Get-HuduAppInfo).version

    if ($script:Version -lt [version]'2.39.0') {
        write-warning "Get-HuduPhotos: Hudu version $($script:Version) is below 2.39.0; Skipping."
        if ($id){ return $null } else { return @() }
    }
    if (($Photoable_Type -and -not $Photoable_Id) -or ($Photoable_Id -and -not $Photoable_Type)) {
        throw "PhotoableType and PhotoableId must be provided together."
    }

    $params = @{}
    if ($PSBoundParameters.ContainsKey('CompanyId')) { $params.company_id = $CompanyId }
    if ($PSBoundParameters.ContainsKey('Caption'))   { $params.caption = $Caption }
    if ($PSBoundParameters.ContainsKey('Pinned'))      { $params.pinned = [bool]$Pinned }
    if ($PSBoundParameters.ContainsKey('FolderId'))  { $params.folder_id = $FolderId }
    if ($PSBoundParameters.ContainsKey('archived'))  { $params.archived = [bool]$Archived }

    if ($PSBoundParameters.ContainsKey('Photoable_Type')) { $params.photoable_type = $Photoable_Type }
    if ($PSBoundParameters.ContainsKey('Photoable_Id')) { $params.photoable_id = $Photoable_Id }

    $updatedRange = Convert-ToHuduDateRange -Start $UpdatedAfter -End $UpdatedBefore
    if ($updatedRange -ne ',' -and -$null -ne $updatedRange) {
        $Params.updated_at = $updatedRange
    }
    $createdRange = Convert-ToHuduDateRange -Start $createdAfter -End $createdBefore
    if ($createdRange -ne ',' -and -$null -ne $createdRange) {
        $Params.created_at = $createdRange
    }    
    if ($Id) {
        $result = Invoke-HuduRequest -Method Get -Resource "/api/v1/photos/$Id"
        $Photos = @($result.photo ?? $result)
    } else {
        $Photos = Invoke-HuduRequestPaginated -hudurequest @{
            Method   = 'GET'
            Resource = '/api/v1/photos'
            property = 'photos'
            params    = $params
        }
    }

    if ($Download) {
        $OutDir = if ([string]::IsNullOrWhiteSpace($OutDir)) { (Get-Location).Path } else { $OutDir }
        $OutDir = (New-Item -ItemType Directory -Path $OutDir -Force).FullName

        $Headers = @{ 'x-api-key' = (New-Object PSCredential 'user', $(Get-HuduApiKey)).GetNetworkCredential().Password }

        foreach ($p in @($Photos)) {
            $label = $p.caption
            if ([string]::IsNullOrWhiteSpace($label)) { $label = "photo-$($p.id)" }
            $safe = ($label -replace '[<>:"/\\|?*\x00-\x1F]', '_').Trim()
            if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "photo-$($p.id)" }

            $destinationPath = Join-Path -Path $OutDir -ChildPath "$safe-$($p.id).bin"

            $fileUrl = "$($script:HuduBaseUrl)/api/v1/photos/$($p.id)?download=true"

            try {
                Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -Headers $Headers -MaximumRedirection 5 -ErrorAction Stop | Out-Null
                Write-Verbose "Downloaded '$($p.id)' to '$destinationPath'"

                if (Test-Path -LiteralPath $destinationPath) {
                    $p | Add-Member -MemberType NoteProperty -Name localPath -Value $destinationPath -Force
                }
            } catch {
                Write-Warning "Failed to download photo '$($p.id)' from '$fileUrl': $($_.Exception.Message)"
            }
        }
    }

    return ($Id ? ($Photos[0]) : $Photos)
}