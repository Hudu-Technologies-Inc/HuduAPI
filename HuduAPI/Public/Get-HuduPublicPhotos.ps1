function Get-HuduPublicPhotos {
    <#
    .SYNOPSIS
    Get a list of public photos or a single public photo, optionally downloading files.

    .DESCRIPTION
    Calls Hudu API to retrieve public photos.

    If -Download is specified with -Id (single) or without (list), downloads public photo files using /public_photos/{id}?download=true.

    .PARAMETER Id
    Numeric ID of the public photo to retrieve or download.

    .PARAMETER Download
    If specified, downloads public photo file(s) to OutDir.

    .PARAMETER OutDir
    Directory to download public photos into. Default current directory.

    .EXAMPLE
    Get-HuduPublicPhotos

    .EXAMPLE
    Get-HuduPublicPhotos -Id 4

    .EXAMPLE
    Get-HuduPublicPhotos -Id 4 -Download

    .EXAMPLE
    Get-HuduPublicPhotos -Download -OutDir "$env:TEMP\public-photos"

    #>
    [CmdletBinding()]
    param(
        [long]$Id,
        [switch]$Download,
        [string]$OutDir = '.'
    )

    if ($Id) {
        $result = Invoke-HuduRequest -Method Get -Resource "/api/v1/public_photos/$Id"
        $PublicPhotos = @($result.public_photo ?? $result)
    } else {
        $HuduRequest = @{
            Method   = 'GET'
            Resource = '/api/v1/public_photos'
            Params   = @{}
        }
        $PublicPhotos = Invoke-HuduRequestPaginated -HuduRequest $HuduRequest -Property 'public_photos'
    }

    if ($Download) {
        $OutDir = if ([string]::IsNullOrWhiteSpace($OutDir)) { (Get-Location).Path } else { $OutDir }
        $OutDir = (New-Item -ItemType Directory -Path $OutDir -Force).FullName

        $Headers = @{ 'x-api-key' = (New-Object PSCredential 'user', $(Get-HuduApiKey)).GetNetworkCredential().Password }
        foreach ($p in @($PublicPhotos.public_photos ?? $PublicPhotos.public_photo ?? $PublicPhotos)) {
            $publicPhotoId = $p.numeric_id ?? $p.id
            if (-not $publicPhotoId) { continue }

            $safeName = ($p.file_name -replace '[<>:"/\\|?*\x00-\x1F]', '_')
            if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "public-photo-$publicPhotoId" }

            $destinationPath = Join-Path -Path $OutDir -ChildPath $safeName
            $fileUrl = "$((Get-HuduBaseURL))/api/v1/public_photos/$($publicPhotoId)?download=true"

            try {
                Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -Headers $Headers -MaximumRedirection 5 -ErrorAction Stop | Out-Null
                Write-Verbose "Downloaded '$publicPhotoId' to '$destinationPath'"
                if (Test-Path -LiteralPath $destinationPath) {
                    $p | Add-Member -MemberType NoteProperty -Name localPath -Value $destinationPath -Force
                }
            } catch {
                Write-Warning "Failed to download public photo '$publicPhotoId' from '$fileUrl': $($_.Exception.Message)"
            }
        }
    }

    $publicPhotosOut = $(($Id ? ($PublicPhotos[0]) : $PublicPhotos))

    return $publicPhotosOut.public_photos ?? $publicPhotosOut.public_photo ?? $publicPhotosOut
}
