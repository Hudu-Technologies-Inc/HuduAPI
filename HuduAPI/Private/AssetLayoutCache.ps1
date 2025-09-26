
function Refresh-AssetLayoutsCache {
    # If your Get-HuduAssetLayouts already populates $script:AssetLayouts internally,
    # this is enough. Otherwise, capture and assign:
    # $res = Get-HuduAssetLayouts
    # $script:AssetLayouts = @($res.asset_layouts ?? $res)
    Get-HuduAssetLayouts | Out-Null
    $script:AssetLayoutsStamp = Get-Date
}

function Ensure-AssetLayoutsCache {
    param([switch]$Force)
    if ($Force -or -not $script:AssetLayouts -or $script:AssetLayouts.Count -eq 0 -or ((Get-Date) - $script:AssetLayoutsStamp) -gt $script:AssetLayoutsTtl) {
        Refresh-AssetLayoutsCache
    }
}

function Find-AssetLayoutNames {
    param([Parameter(Mandatory)][string]$Name)
    Ensure-AssetLayoutsCache

    # Treat input as plain text (not regex). Do a case-insensitive substring match.
    $needle = $Name -replace "'", ''   # keep your apostrophe trim if you need it
    ($script:AssetLayouts).name |
        Where-Object { $_ -and ($_.IndexOf($needle, [System.StringComparison]::CurrentCultureIgnoreCase) -ge 0) } |
        ForEach-Object { "'$_'" }
}
