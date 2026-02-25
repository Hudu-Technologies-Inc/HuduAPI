function Get-HuduUploads {
    <#
    .SYNOPSIS
    Get a list of uploads

    .DESCRIPTION
    Calls Hudu API to retrieve uploads


    .PARAMETER Id
    ID of the Upload to retrieve or Download (hudu version 2.41.0 and above)

    .PARAMETER outFilePath
    Optional path to download uploads to, defaults to current directory. Only used if -Download is specified and Hudu version is 2.41.0 or above.

    .EXAMPLE
    Get-HuduUploads

    #>
    [CmdletBinding()]
    Param(
        [Int]$Id,
        [bool]$download = $false,
        [string]$outFilePath = '.'
    )

    if ($Id) {
        $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads/$Id"
    } else {
        [version]$script:Version = $script:Version ?? (Get-HuduAppInfo).version
        if ($script:Version -lt [version]("2.41.0")) {
            $Upload = Invoke-HuduRequest -Method Get -Resource "/api/v1/uploads"
        } else {
            $Upload = Invoke-HuduRequestPaginated -hudurequest @{Method = "Get"; Resource = "/api/v1/uploads"; property = "uploads"}
        }
    }
    if ($true -eq $download){
        if ($script:Version -lt [version]("2.41.0")) {
            Write-Warning "Download of uploads is only supported in Hudu v2.41.0 and above, skipping download"
        } else {
            $outFilePath = [string]::IsNullOrWhiteSpace($outFilePath) ? (Get-Location).Path : $outFilePath
            $outFilePath = (New-Item -ItemType Directory -Path $outFilePath -Force).FullName
            $Headers = @{'x-api-key' = (New-Object PSCredential 'user', $HuduAPIKey).GetNetworkCredential().Password;}

            foreach ($upload in $Upload) {
                $destinationPath = Join-Path -Path $outFilePath -ChildPath $upload.name
                try {
                    Invoke-WebRequest -Uri "/api/v1/uploads/$($upload.id)?download=true" -OutFile $destinationPath -force -headers $Headers -MaximumRedirection 3 | Out-Null
                    Write-Verbose "Downloaded '$fileName' to '$destinationPath'"
                } catch {
                    Write-Warning "Failed to download '$fileName' from '$fileUrl': $_"
                }
                if (Test-Path -Path $destinationPath) {
                    $upload | Add-Member -MemberType NoteProperty -Name "localPath" -Value "$destinationPath" -Force
                }
            }
        }
    }

    return $Upload
}
 