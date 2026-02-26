function Get-HuduUploads {
    <#
    .SYNOPSIS
    Get a list of uploads

    .DESCRIPTION
    Calls Hudu API to retrieve uploads

    .PARAMETER Id
    ID of the Upload to retrieve or Download (Hudu 2.39.0+)

    .PARAMETER OutDir
    Directory to download uploads to. Used only with -Download (Hudu 2.39.0+). Defaults to current directory.

    .EXAMPLE
    Get-HuduUploads

    #>
    [CmdletBinding()]
    param(
        [int]$Id,
        [switch]$Download,
        [string]$OutDir = '.'
    )

    [version]$script:Version = $script:Version ?? (Get-HuduAppInfo).version
    $Upload = @()
    if ($Id) {
        $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads/$Id"
    } else {
        if ($script:Version -lt [version]'2.39.0') {
            $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads"
        } else {
            $Upload = Invoke-HuduRequestPaginated -hudurequest @{ Method = 'Get'; Resource = '/api/v1/uploads'}
        }
    }

    if ($Download) {
        if ($script:Version -lt [version]'2.39.0') {
            Write-Warning "Download of uploads is only supported in Hudu v2.39.0 and above; skipping download."
        } else {
            $OutDir = if ([string]::IsNullOrWhiteSpace($OutDir)) { (Get-Location).Path } else { $OutDir }
            $OutDir = (New-Item -ItemType Directory -Path $OutDir -Force).FullName

            $Headers = @{ 'x-api-key' = (New-Object PSCredential 'user', $(Get-HuduApiKey)).GetNetworkCredential().Password }

            foreach ($u in @($Upload.uploads ?? $Upload.upload ?? $Upload)) {
                if (-not $u.id -or $u.id -lt 1){continue}
                $safeName = ($u.name -replace '[<>:"/\\|?*\x00-\x1F]', '_')
                if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "upload-$($u.id)" }

                $destinationPath = Join-Path -Path $OutDir -ChildPath $safeName

                $fileUrl = "$($script:Int_HuduBaseURL)/api/v1/uploads/$($u.id)?download=true"

                try {
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -Headers $Headers -MaximumRedirection 3 -ErrorAction Stop | Out-Null
                    Write-Verbose "Downloaded '$($u.name)' to '$destinationPath'"
                    if (Test-Path -LiteralPath $destinationPath) {
                        $u | Add-Member -MemberType NoteProperty -Name localPath -Value $destinationPath -Force
                    }
                } catch {
                    Write-Warning "Failed to download '$($u.name)' from '$fileUrl': $($_.Exception.Message)"
                }
            }
        }
    }

    return $Upload
}