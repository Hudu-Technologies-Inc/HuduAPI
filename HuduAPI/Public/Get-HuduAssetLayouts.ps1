function Get-HuduAssetLayouts {
    [CmdletBinding()]
    Param (
        [String]$Name,
        [Alias('id', 'layout_id')]
        [int]$LayoutId,
        [String]$Slug
    )

    $HuduRequest = @{
        Resource = '/api/v1/asset_layouts'
        Method   = 'GET'
    }

    if ($LayoutId) {
        $HuduRequest.Resource = '{0}/{1}' -f $HuduRequest.Resource, $LayoutId
        $resp   = Invoke-HuduRequest @HuduRequest
        $layout = $resp.asset_layout ?? $resp

        # lazily merge into cache (do NOT bump CachedAt so partial refreshes don't mark cache "fresh")
        if ($layout) {
            if ($script:AssetLayoutsCache -and $script:AssetLayoutsCache.Data) {
                $data = @($script:AssetLayoutsCache.Data | Where-Object { $_.id -ne $layout.id })
                $data += $layout
                $script:AssetLayoutsCache.Data = $data | Sort-Object -Property name
            } else {
                $script:AssetLayoutsCache = [pscustomobject]@{
                    Data     = @($layout)
                    CachedAt = $null   # not a full refresh
                }
            }
            # keep legacy var for completers in sync
            $script:AssetLayouts = $script:AssetLayoutsCache.Data
        }

        return $layout
    }
    else {
        $Params = @{}
        if ($Name) { $Params.name = $Name }
        if ($Slug) { $Params.slug = $Slug }
        if ($Params.Count -gt 0) { $HuduRequest.Params = $Params }

        $items = Invoke-HuduRequestPaginated -HuduRequest $HuduRequest -Property 'asset_layouts' -PageSize 25

        if ($Params.Count -eq 0) {
            $sorted = $items | Sort-Object -Property name
            $script:AssetLayoutsCache = [pscustomobject]@{
                Data     = $sorted
                CachedAt = Get-Date
            }
            $script:AssetLayouts = $sorted # for your completer
        } else {
            # FILTERED SET: merge, but don't bump timestamp
            if ($items) {
                if ($script:AssetLayoutsCache -and $script:AssetLayoutsCache.Data) {
                    # replace (or add) by id
                    $byId = @{}
                    foreach ($x in $script:AssetLayoutsCache.Data) { $byId[$x.id] = $x }
                    foreach ($x in $items)                         { $byId[$x.id] = $x }
                    $script:AssetLayoutsCache.Data = $byId.Values | Sort-Object -Property name
                } else {
                    $script:AssetLayoutsCache = [pscustomobject]@{
                        Data     = $items
                        CachedAt = $null
                    }
                }
                $script:AssetLayouts = $script:AssetLayoutsCache.Data
            }
        }

        return $items
    }
}
