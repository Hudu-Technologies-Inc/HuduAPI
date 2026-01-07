
function Save-HuduExports {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [long]$Id,
        [Parameter()]
        [string]$OutDir = '.',
        [Parameter()]
        [bool]$SkipIfExists=$true
    )

    $OutDir = [string]::IsNullOrWhiteSpace($OutDir) ? (Get-Location).Path : $OutDir
    $OutDir = (New-Item -ItemType Directory -Path $OutDir -Force).FullName
    $exports = $(if ($null -ne $Id) {@(Get-HuduExports -id $id)} else {@(Get-HuduExports)})

    if (-not $exports -or $exports.Count -eq 0) {Write-Warning "No exports available."; return;}
    $HuduAPIKey = Get-HuduApiKey
    $Headers = @{'x-api-key' = (New-Object PSCredential 'user', $HuduAPIKey).GetNetworkCredential().Password;}

    $files = @()

    foreach ($export in $exports) {
        $fileName = $export.file_name ?? "export-$($export.id)$(if ($export.is_pdf) { '.pdf' } else { '.csv' })"

        if (-not $export.download_url -or [string]::isnullorempty($export.download_url)) {
            Write-Warning "Export id $($export.id) has no download_url yet (status=$($export.status)). Skipping."
            write-host "$($($export | convertto-json -depth 99).ToSTring())"
            continue
        }

        $outPath = Join-Path $OutDir $fileName
        if ($true -eq $SkipIfExists -and (Test-Path -LiteralPath $outPath)) {
            Write-Verbose "Already exists, skipping: $outPath"
            continue
        }

        if ($PSCmdlet.ShouldProcess($outPath, "Download export id $exId")) {
            Invoke-WebRequest -Uri $export.download_url -headers $headers -OutFile $outPath -MaximumRedirection 10 | Out-Null
        }
        $files+=$(Get-Item -LiteralPath $outPath)
    }
    return $files
}
